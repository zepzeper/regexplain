--- Regex Under Cursor Extraction
--- Detects regex patterns under the cursor in source code.

local M = {}

--- Check if a character at position is escaped (preceded by odd number of backslashes)
local function is_escaped(str, pos)
  local escapes = 0
  local check = pos - 1
  while check >= 1 and str:sub(check, check) == "\\" do
    escapes = escapes + 1
    check = check - 1
  end
  return escapes % 2 == 1
end

--- Find the next unescaped occurrence of a character
local function find_unescaped(str, char, start_pos)
  local pos = start_pos
  while pos <= #str do
    local found = str:find(char, pos, true)
    if not found then
      return nil
    end
    if not is_escaped(str, found) then
      return found
    end
    pos = found + 1
  end
  return nil
end

--- Extract a delimited regex from a line
--- Returns { raw, pattern, flags, delimiters } or nil
local function extract_delimited(line, col)
  local delimiters = { "/", "#", "~", "!" }

  for _, delim in ipairs(delimiters) do
    local search_start = 1

    while search_start <= #line do
      local open_pos = find_unescaped(line, delim, search_start)
      if not open_pos then
        break
      end

      -- Find matching close delimiter
      local close_pos = nil
      local scan = open_pos + 1
      local in_class = false

      while scan <= #line do
        local char = line:sub(scan, scan)

        if char == "\\" and scan < #line then
          scan = scan + 2
        elseif char == "[" and not in_class then
          -- Check for POSIX class [[:alpha:]] - skip inner [
          if line:sub(scan + 1, scan + 1) == ":" then
            scan = scan + 1
          else
            in_class = true
          end
          scan = scan + 1
        elseif char == "]" and in_class then
          in_class = false
          scan = scan + 1
        elseif char == delim and not in_class then
          if not is_escaped(line, scan) then
            close_pos = scan
            break
          end
          scan = scan + 1
        else
          scan = scan + 1
        end
      end

      if close_pos then
        -- Check if cursor is inside (col is 0-indexed, positions are 1-indexed)
        if col + 1 >= open_pos and col + 1 <= close_pos then
          -- Extract flags after closing delimiter
          local after = close_pos + 1
          local flags = ""
          while after <= #line do
            local f = line:sub(after, after)
            if f:match("[gimsuvyADSXUJP]") then
              flags = flags .. f
              after = after + 1
            else
              break
            end
          end

          return {
            raw = line:sub(open_pos, close_pos) .. flags,
            pattern = line:sub(open_pos + 1, close_pos - 1),
            flags = flags,
            delimiter = delim,
          }
        end

        search_start = close_pos + 1
      else
        search_start = open_pos + 1
      end
    end
  end

  return nil
end

--- Extract content from inside quotes around cursor
--- Handles single and double quotes, respecting escapes
--- Returns { text, quote_char, start_pos, end_pos } or nil
local function extract_quoted(line, col)
  -- Find opening quote before cursor
  local open_pos = nil
  local quote_char = nil

  for pos = col, 1, -1 do
    local char = line:sub(pos, pos)
    if char == '"' or char == "'" then
      if not is_escaped(line, pos) then
        -- Check if there's a matching close quote after cursor
        local close_pos = nil
        for end_pos = pos + 1, #line do
          if line:sub(end_pos, end_pos) == char and not is_escaped(line, end_pos) then
            close_pos = end_pos
            break
          end
        end

        if close_pos and col + 1 >= pos and col + 1 <= close_pos then
          open_pos = pos
          quote_char = char
          break
        end
      end
    end
  end

  if not open_pos then
    return nil
  end

  -- Find closing quote after cursor
  local close_pos = nil
  for pos = open_pos + 1, #line do
    if line:sub(pos, pos) == quote_char and not is_escaped(line, pos) then
      close_pos = pos
      break
    end
  end

  if not close_pos then
    return nil
  end

  return {
    text = line:sub(open_pos + 1, close_pos - 1),
    quote_char = quote_char,
    start_pos = open_pos,
    end_pos = close_pos,
  }
end

--- Main extraction function
---@param line string the current line text
---@param col integer 0-indexed byte column position
---@return table|nil { raw, pattern, flags, source }
function M.extract(line, col)
  -- Try delimited regex first
  local delimited = extract_delimited(line, col)
  if delimited then
    delimited.source = "delimited"
    return delimited
  end

  -- Try quoted string
  local quoted = extract_quoted(line, col)
  if quoted then
    -- Check if the quoted content itself contains a delimited regex
    local inner = extract_delimited(quoted.text, 0)
    if inner then
      return {
        raw = quoted.quote_char .. inner.raw .. quoted.quote_char,
        pattern = inner.pattern,
        flags = inner.flags,
        delimiter = inner.delimiter,
        source = "quoted-delimited",
      }
    end

    -- Return the quoted content as a potential pattern
    return {
      raw = quoted.quote_char .. quoted.text .. quoted.quote_char,
      pattern = quoted.text,
      flags = "",
      source = "quoted",
    }
  end

  return nil
end

--- Extract from current cursor position in editor
function M.extract_from_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1] - 1
  local col = cursor[2]
  local line = vim.api.nvim_buf_get_lines(0, line_num, line_num + 1, false)[1] or ""

  return M.extract(line, col)
end

--- Extract from visual selection
function M.extract_visual()
  local mode = vim.fn.mode()
  if not (mode:match("v") or mode == "\22") then
    return nil
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local buf = vim.api.nvim_get_current_buf()

  local start_line = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_line = end_pos[2] - 1
  local end_col = end_pos[3]

  local lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line + 1, false)

  local text
  if #lines == 1 then
    text = lines[1]:sub(start_col + 1, end_col)
  else
    lines[1] = lines[1]:sub(start_col + 1)
    lines[#lines] = lines[#lines]:sub(1, end_col)
    text = table.concat(lines, "\n")
  end

  -- If selection looks like a delimited regex, strip delimiters
  local first = text:sub(1, 1)
  local last = text:sub(-1, -1)
  if first == last and vim.tbl_contains({"/", "#", "~", "!"}, first) and #text > 2 then
    return {
      raw = text,
      pattern = text:sub(2, -2),
      flags = "",
      delimiter = first,
      source = "visual-delimited",
    }
  end

  -- If selection is quoted, strip quotes
  if (first == '"' and last == '"') or (first == "'" and last == "'") and #text > 2 then
    local inner = text:sub(2, -2)
    -- Check if inner is delimited
    local inner_first = inner:sub(1, 1)
    local inner_last = inner:sub(-1, -1)
    if inner_first == inner_last and vim.tbl_contains({"/", "#", "~", "!"}, inner_first) and #inner > 2 then
      return {
        raw = text,
        pattern = inner:sub(2, -2),
        flags = "",
        delimiter = inner_first,
        source = "visual-quoted-delimited",
      }
    end
    return {
      raw = text,
      pattern = inner,
      flags = "",
      source = "visual-quoted",
    }
  end

  return {
    raw = text,
    pattern = text,
    flags = "",
    source = "visual",
  }
end

return M
