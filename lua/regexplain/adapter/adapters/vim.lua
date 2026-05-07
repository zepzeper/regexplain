--- Vim Regex Adapter
--- Parses Vim /search/ and :substitute regex patterns into explanation trees.
--- Handles magic modes: \v (very magic), \V (very nomagic), \m (magic), \M (nomagic)

local M = {
  name = "vim",
  display_name = "Vim Regex",
  flavors = { "magic", "nomagic", "very_magic", "very_nomagic" },
}

local EXPLANATIONS = {
  literal = function(text) return "Matches '" .. text .. "' literally" end,
  any_character = "Matches any single character",
  anchor_start = "Matches the start of a line",
  anchor_end = "Matches the end of a line",
  word_boundary_start = "Matches the start of a word",
  word_boundary_end = "Matches the end of a word",
  word_boundary = "Matches a word boundary",
  non_word_boundary = "Matches inside a word (non-boundary)",
  quantifier_zero_or_more = "Matches zero or more of the preceding",
  quantifier_one_or_more = "Matches one or more of the preceding",
  quantifier_zero_or_one = "Matches zero or one of the preceding (optional)",
  quantifier_lazy = "Lazy: matches as few as possible",
  capture_group = "Capture group",
  non_capturing_group = "Non-capturing group",
  alternation = "Alternation: match either side",
  backreference = function(n) return "Backreference to capture group #" .. n end,
  magic_mode = function(mode) return "Switch to " .. mode .. " mode" end,
}

local CHAR_CLASSES = {
  ["d"] = "digit (0-9)",
  ["D"] = "non-digit",
  ["s"] = "whitespace character",
  ["S"] = "non-whitespace character",
  ["w"] = "word character [a-zA-Z0-9_]",
  ["W"] = "non-word character",
  ["h"] = "head of word character [a-zA-Z_]",
  ["H"] = "non-head of word character",
  ["a"] = "alphabetic character",
  ["A"] = "non-alphabetic character",
  ["l"] = "lowercase letter",
  ["L"] = "non-lowercase character",
  ["u"] = "uppercase letter",
  ["U"] = "non-uppercase character",
  ["x"] = "hex digit",
  ["X"] = "non-hex digit",
  ["o"] = "octal digit",
  ["O"] = "non-octal digit",
  ["i"] = "identifier character",
  ["I"] = "non-identifier character",
  ["k"] = "keyword character",
  ["K"] = "non-keyword character",
  ["f"] = "file name character",
  ["F"] = "non-file name character",
  ["p"] = "printable character",
  ["P"] = "non-printable character",
  ["c"] = "control character",
  ["C"] = "non-control character",
  ["t"] = "tab character",
  ["r"] = "carriage return",
  ["n"] = "newline",
  ["b"] = "backspace",
  ["e"] = "escape character",
  ["_"] = "in collection: includes newline",
}

  local function tokenize_all_modes(pattern)
  local tokens = {}
  local i = 1
  local len = #pattern
  local mode = "magic" -- default

  -- Check first chars for mode switch
  if len >= 2 and pattern:sub(1, 1) == "\\" then
    local m = pattern:sub(2, 2)
    if m == "v" then mode = "very_magic"; i = 3
    elseif m == "V" then mode = "very_nomagic"; i = 3
    elseif m == "m" then mode = "magic"; i = 3
    elseif m == "M" then mode = "nomagic"; i = 3
    end
  end

  if i > 1 then
    table.insert(tokens, { type = "magic_mode", text = pattern:sub(1, i - 1), explanation = EXPLANATIONS.magic_mode(mode) })
  end

  while i <= len do
    local char = pattern:sub(i, i)

    -- Helper to check if a char is special in current mode
    local is_special = false
    if mode == "very_magic" then
      -- In \v: most PCRE-like. Literals need escaping.
      is_special = vim.tbl_contains(
        { "^", "$", ".", "*", "+", "?", "[", "]", "(", ")", "{", "}", "|", "\\", "%" },
        char
      )
    elseif mode == "very_nomagic" then
      -- In \V: only backslash is special
      is_special = (char == "\\")
    elseif mode == "magic" then
      -- Default: ^ $ . * [ ~ are special
      is_special = vim.tbl_contains({ "^", "$", ".", "*", "[", "]", "\\", "~", "&" }, char)
    else -- nomagic
      -- \M: only ^ $ are special
      is_special = vim.tbl_contains({ "^", "$", "\\" }, char)
    end

    if char == "\\" and i < len then
      local next_char = pattern:sub(i + 1, i + 1)

      if next_char:match("[1-9]") then
        table.insert(tokens, { type = "backreference", text = "\\" .. next_char, explanation = EXPLANATIONS.backreference(next_char) })
        i = i + 2
      elseif next_char == "<" then
        table.insert(tokens, { type = "word_boundary_start", text = "\\<", explanation = EXPLANATIONS.word_boundary_start })
        i = i + 2
      elseif next_char == ">" then
        table.insert(tokens, { type = "word_boundary_end", text = "\\>", explanation = EXPLANATIONS.word_boundary_end })
        i = i + 2
      elseif next_char == "_" and i + 2 <= len then
        local class_char = pattern:sub(i + 2, i + 2)
        if CHAR_CLASSES[class_char] then
          table.insert(tokens, {
            type = "char_class",
            text = "\\_" .. class_char,
            explanation = "Matches a " .. CHAR_CLASSES[class_char] .. " (including newline)",
          })
          i = i + 3
        else
          table.insert(tokens, { type = "escape", text = "\\_" .. class_char, explanation = EXPLANATIONS.literal("_" .. class_char) })
          i = i + 3
        end
      elseif CHAR_CLASSES[next_char] then
        table.insert(tokens, {
          type = "char_class",
          text = "\\" .. next_char,
          explanation = "Matches a " .. CHAR_CLASSES[next_char],
        })
        i = i + 2
      elseif next_char == "(" then
        table.insert(tokens, { type = "capture_group", text = "\\(", explanation = EXPLANATIONS.capture_group })
        i = i + 2
      elseif next_char == ")" then
        table.insert(tokens, { type = "capture_group_end", text = "\\)", explanation = "End of capture group" })
        i = i + 2
      elseif next_char == "|" then
        table.insert(tokens, { type = "alternation", text = "\\|", explanation = EXPLANATIONS.alternation })
        i = i + 2
      elseif next_char == "{" then
        -- Brace quantifier \{n,m\}
        local j = i + 2
        while j <= len and pattern:sub(j, j) ~= "}" do
          j = j + 1
        end
        local text = pattern:sub(i, j)
        table.insert(tokens, { type = "quantifier_count", text = text, explanation = "Quantifier: " .. pattern:sub(i + 2, j - 1) })
        i = j + 1
      elseif next_char == "+" then
        table.insert(tokens, { type = "quantifier_one_or_more", text = "\\+", explanation = EXPLANATIONS.quantifier_one_or_more })
        i = i + 2
      elseif next_char == "=" then
        table.insert(tokens, { type = "quantifier_zero_or_one", text = "\\=", explanation = EXPLANATIONS.quantifier_zero_or_one })
        i = i + 2
      elseif next_char == "?" then
        table.insert(tokens, { type = "quantifier_zero_or_one", text = "\\?", explanation = EXPLANATIONS.quantifier_zero_or_one })
        i = i + 2
      elseif next_char == "n" then
        table.insert(tokens, { type = "escape", text = "\\n", explanation = "Newline" })
        i = i + 2
      elseif next_char == "r" then
        table.insert(tokens, { type = "escape", text = "\\r", explanation = "Carriage return" })
        i = i + 2
      elseif next_char == "t" then
        table.insert(tokens, { type = "escape", text = "\\t", explanation = "Tab" })
        i = i + 2
      elseif next_char == "." then
        table.insert(tokens, { type = "literal", text = ".", explanation = EXPLANATIONS.literal(".") })
        i = i + 2
      elseif next_char == "%" then
        table.insert(tokens, { type = "literal", text = "%", explanation = EXPLANATIONS.literal("%") })
        i = i + 2
      else
        -- Escaped literal
        table.insert(tokens, { type = "literal", text = next_char, explanation = EXPLANATIONS.literal(next_char) })
        i = i + 2
      end
    elseif char == "^" then
      table.insert(tokens, { type = "anchor_start", text = "^", explanation = EXPLANATIONS.anchor_start })
      i = i + 1
    elseif char == "$" then
      table.insert(tokens, { type = "anchor_end", text = "$", explanation = EXPLANATIONS.anchor_end })
      i = i + 1
    elseif char == "." and (mode == "very_magic" or mode == "magic") then
      table.insert(tokens, { type = "any_character", text = ".", explanation = EXPLANATIONS.any_character })
      i = i + 1
    elseif char == "*" and (mode == "very_magic" or mode == "magic") then
      table.insert(tokens, { type = "quantifier_zero_or_more", text = "*", explanation = EXPLANATIONS.quantifier_zero_or_more })
      i = i + 1
    elseif char == "+" and mode == "very_magic" then
      table.insert(tokens, { type = "quantifier_one_or_more", text = "+", explanation = EXPLANATIONS.quantifier_one_or_more })
      i = i + 1
    elseif char == "?" and mode == "very_magic" then
      table.insert(tokens, { type = "quantifier_zero_or_one", text = "?", explanation = EXPLANATIONS.quantifier_zero_or_one })
      i = i + 1
    elseif char == "[" then
      local j = i + 1
      while j <= len and pattern:sub(j, j) ~= "]" do
        if pattern:sub(j, j) == "\\" and j < len then
          j = j + 2
        else
          j = j + 1
        end
      end
      local text = pattern:sub(i, j)
      if text:sub(2, 2) == "^" then
        table.insert(tokens, { type = "char_set_negated", text = text, explanation = "Negated character set" })
      else
        table.insert(tokens, { type = "char_set", text = text, explanation = "Character set" })
      end
      i = j + 1
    elseif char == "(" and mode == "very_magic" then
      table.insert(tokens, { type = "capture_group", text = "(", explanation = EXPLANATIONS.capture_group })
      i = i + 1
    elseif char == ")" and mode == "very_magic" then
      table.insert(tokens, { type = "capture_group_end", text = ")", explanation = "End of capture group" })
      i = i + 1
    elseif char == "|" and mode == "very_magic" then
      table.insert(tokens, { type = "alternation", text = "|", explanation = EXPLANATIONS.alternation })
      i = i + 1
    elseif char == "{" and mode == "very_magic" then
      -- In very magic, {n,m} is a quantifier
      local j = i + 1
      while j <= len and pattern:sub(j, j) ~= "}" do
        j = j + 1
      end
      local text = pattern:sub(i, j)
      table.insert(tokens, { type = "quantifier_count", text = text, explanation = "Quantifier: " .. pattern:sub(i + 1, j - 1) })
      i = j + 1
    else
      table.insert(tokens, { type = "literal", text = char, explanation = EXPLANATIONS.literal(char) })
      i = i + 1
    end
  end

  return tokens, mode
end

local function build_tree(tokens, pattern)
  local children = {}
  local i = 1

  while i <= #tokens do
    local tok = tokens[i]

    if tok.type:match("^quantifier") and #children > 0 then
      local prev = children[#children]
      prev.children = prev.children or {}
      table.insert(prev.children, {
        type = tok.type,
        text = tok.text,
        explanation = tok.explanation,
      })
      i = i + 1
    elseif tok.type == "capture_group" then
      local group_children = {}
      local depth = 1
      i = i + 1
      while i <= #tokens and depth > 0 do
        local inner = tokens[i]
        if inner.type == "capture_group" then
          depth = depth + 1
          table.insert(group_children, { type = inner.type, text = inner.text, explanation = inner.explanation })
        elseif inner.type == "capture_group_end" then
          depth = depth - 1
          if depth > 0 then
            table.insert(group_children, { type = inner.type, text = inner.text, explanation = inner.explanation })
          end
        else
          table.insert(group_children, { type = inner.type, text = inner.text, explanation = inner.explanation })
        end
        i = i + 1
      end

      table.insert(children, {
        type = "capture_group",
        text = tok.text .. "...",
        explanation = tok.explanation,
        children = group_children,
      })
    elseif tok.type == "capture_group_end" then
      i = i + 1
    else
      table.insert(children, {
        type = tok.type,
        text = tok.text,
        explanation = tok.explanation,
      })
      i = i + 1
    end
  end

  return {
    type = "root",
    text = pattern,
    explanation = "Vim Regular Expression" .. (tokens[1] and tokens[1].type == "magic_mode" and (" (" .. tokens[1].explanation:gsub("Switch to ", "") .. ")") or " (magic mode)"),
    children = children,
  }
end

M.parse = function(pattern, opts)
  opts = opts or {}
  if not pattern or pattern == "" then
    return nil, "Empty pattern"
  end

  local tokens, mode = tokenize_all_modes(pattern)
  local tree = build_tree(tokens, pattern)
  local TreeUtil = require("regexplain.adapter.tree")
  TreeUtil.collapse_literals(tree)
  TreeUtil.number_groups(tree)
  return tree
end

M.match = function(pattern, text, opts)
  opts = opts or {}
  if not pattern or pattern == "" then
    return nil, "Empty pattern"
  end
  if not text then
    return nil, "Empty text"
  end

  local ok, result = pcall(function()
    local regex = vim.regex(pattern)
    local matches = {}
    local start = 0

    while start <= #text do
      local s, e = regex:match_str(text:sub(start + 1))
      if not s then
        break
      end

      local match_start = start + s + 1
      local match_end = start + e
      table.insert(matches, {
        start = match_start,
        end_pos = match_end,
        text = text:sub(match_start, match_end),
        groups = {},
      })

      start = start + s + 1
      if start >= #text then
        break
      end
    end

    return { matches = matches }
  end)

  if not ok then
    return nil, tostring(result)
  end

  return result
end

return M
