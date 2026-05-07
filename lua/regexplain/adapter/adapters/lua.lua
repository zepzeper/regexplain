--- Lua Pattern Adapter
--- Parses Lua string.match / string.gsub patterns into explanation trees.

local M = {
  name = "lua",
  display_name = "Lua Patterns",
  flavors = { "lua" },
}

local EXPLANATIONS = {
  literal = function(text)
    return "Matches '" .. text .. "' literally"
  end,
  any_character = "Matches any single character",
  anchor_start = "Matches the start of the string",
  anchor_end = "Matches the end of the string",
  quantifier_zero_or_more = "Matches zero or more of the preceding element",
  quantifier_one_or_more = "Matches one or more of the preceding element",
  quantifier_zero_or_one = "Matches zero or one of the preceding element (optional)",
  quantifier_lazy = "Makes the preceding quantifier lazy (matches as few as possible)",
  char_class = function(text)
    local map = {
      ["%a"] = "letter (A-Z, a-z)",
      ["%c"] = "control character",
      ["%d"] = "digit (0-9)",
      ["%g"] = "printable character except space",
      ["%l"] = "lowercase letter (a-z)",
      ["%p"] = "punctuation character",
      ["%s"] = "whitespace character",
      ["%u"] = "uppercase letter (A-Z)",
      ["%w"] = "alphanumeric character (A-Z, a-z, 0-9)",
      ["%x"] = "hexadecimal digit (0-9, A-F, a-f)",
      ["%z"] = "null character (\\0)",
      ["%%"] = "a literal '%'",
    }
    local neg_map = {
      ["%A"] = "any character except letters",
      ["%C"] = "any character except control characters",
      ["%D"] = "any character except digits",
      ["%G"] = "space character",
      ["%L"] = "any character except lowercase letters",
      ["%P"] = "any character except punctuation",
      ["%S"] = "any character except whitespace",
      ["%U"] = "any character except uppercase letters",
      ["%W"] = "any character except alphanumeric",
      ["%X"] = "any character except hex digits",
    }
    return map[text] and ("Matches a " .. map[text]) or (neg_map[text] and ("Matches " .. neg_map[text])) or ("Matches '" .. text .. "'")
  end,
  capture_group = "Capture group: captures the matched text for backreferences",
  backreference = function(text)
    local n = text:match("^%%(%d)$")
    return "Backreference: matches the same text as capture group #" .. n
  end,
  char_set = function(text)
    if text:sub(1, 2) == "[^" then
      return "Negated character set: matches any character NOT in " .. text
    end
    return "Character set: matches any character in " .. text
  end,
  escape = function(text)
    return "Escaped character: matches '" .. text:sub(2) .. "' literally"
  end,
  balanced = function(text)
    local a, b = text:match("^%%b(.)(.)$")
    return "Balanced match: matches from '" .. a .. "' to '" .. b .. "'"
  end,
  frontier = function(text)
    return "Frontier pattern: matches a transition between word/non-word characters"
  end,
}

local function parse_pattern(pattern)
  local tokens = {}
  local i = 1
  local len = #pattern

  while i <= len do
    local char = pattern:sub(i, i)

    -- Balanced string %bxy
    if char == "%" and i + 3 <= len and pattern:sub(i + 1, i + 1) == "b" then
      local text = pattern:sub(i, i + 3)
      table.insert(tokens, {
        type = "balanced",
        text = text,
        explanation = EXPLANATIONS.balanced(text),
      })
      i = i + 4

    -- Frontier pattern %f[set]
    elseif char == "%" and i + 2 <= len and pattern:sub(i + 1, i + 1) == "f" and pattern:sub(i + 2, i + 2) == "[" then
      local j = i + 3
      while j <= len and pattern:sub(j, j) ~= "]" do
        if pattern:sub(j, j) == "%" and j < len then
          j = j + 2
        else
          j = j + 1
        end
      end
      local text = pattern:sub(i, j)
      table.insert(tokens, {
        type = "frontier",
        text = text,
        explanation = EXPLANATIONS.frontier(text),
      })
      i = j + 1

    -- Character class escapes %a, %d, %A, %D, etc.
    elseif char == "%" and i < len then
      local next_char = pattern:sub(i + 1, i + 1)
      local text = pattern:sub(i, i + 1)

      if next_char:match("[adlsupwxzADLSUPWXZ]") then
        table.insert(tokens, {
          type = "char_class",
          text = text,
          explanation = EXPLANATIONS.char_class(text),
        })
        i = i + 2
      elseif next_char:match("[1-9]") then
        table.insert(tokens, {
          type = "backreference",
          text = text,
          explanation = EXPLANATIONS.backreference(text),
        })
        i = i + 2
      else
        -- Escaped literal (e.g., %%, %., %(, %), %[, %], %+)
        table.insert(tokens, {
          type = "escape",
          text = text,
          explanation = EXPLANATIONS.escape(text),
        })
        i = i + 2
      end

    -- Character sets [abc], [^abc], [a-z]
    elseif char == "[" then
      local j = i + 1
      local negated = false
      if j <= len and pattern:sub(j, j) == "^" then
        negated = true
        j = j + 1
      end
      while j <= len and pattern:sub(j, j) ~= "]" do
        if pattern:sub(j, j) == "%" and j < len then
          j = j + 2
        else
          j = j + 1
        end
      end
      local text = pattern:sub(i, j)
      table.insert(tokens, {
        type = "char_set",
        text = text,
        explanation = EXPLANATIONS.char_set(text),
      })
      i = j + 1

    elseif char == "^" and (i == 1 or pattern:sub(i - 1, i - 1) == "[") then
      table.insert(tokens, {
        type = "anchor_start",
        text = "^",
        explanation = EXPLANATIONS.anchor_start,
      })
      i = i + 1
    elseif char == "$" and i == len then
      table.insert(tokens, {
        type = "anchor_end",
        text = "$",
        explanation = EXPLANATIONS.anchor_end,
      })
      i = i + 1

    elseif char == "*" then
      table.insert(tokens, {
        type = "quantifier_zero_or_more",
        text = "*",
        explanation = EXPLANATIONS.quantifier_zero_or_more,
      })
      i = i + 1
    elseif char == "+" then
      table.insert(tokens, {
        type = "quantifier_one_or_more",
        text = "+",
        explanation = EXPLANATIONS.quantifier_one_or_more,
      })
      i = i + 1
    elseif char == "-" then
      table.insert(tokens, {
        type = "quantifier_zero_or_more",
        text = "-",
        explanation = EXPLANATIONS.quantifier_zero_or_more .. " (lazy)",
      })
      i = i + 1
    elseif char == "?" then
      table.insert(tokens, {
        type = "quantifier_zero_or_one",
        text = "?",
        explanation = EXPLANATIONS.quantifier_zero_or_one,
      })
      i = i + 1

    elseif char == "(" then
      table.insert(tokens, {
        type = "capture_group",
        text = "(",
        explanation = EXPLANATIONS.capture_group,
      })
      i = i + 1
    elseif char == ")" then
      table.insert(tokens, {
        type = "capture_group_end",
        text = ")",
        explanation = "End of capture group",
      })
      i = i + 1

    elseif char == "." then
      table.insert(tokens, {
        type = "any_character",
        text = ".",
        explanation = EXPLANATIONS.any_character,
      })
      i = i + 1

    else
      table.insert(tokens, {
        type = "literal",
        text = char,
        explanation = EXPLANATIONS.literal(char),
      })
      i = i + 1
    end
  end

  return tokens
end

-- Build a tree from tokens, grouping related elements
local function build_tree(tokens, pattern)
  local children = {}
  local i = 1

  while i <= #tokens do
    local tok = tokens[i]

    -- Combine quantifiers with their preceding element
    if tok.type:match("^quantifier") and #children > 0 then
      local prev = children[#children]
      prev.children = prev.children or {}
      table.insert(prev.children, {
        type = tok.type,
        text = tok.text,
        explanation = tok.explanation,
      })
      i = i + 1

    -- Group capture groups with their contents
    elseif tok.type == "capture_group" then
      local group_children = {}
      local depth = 1
      i = i + 1
      while i <= #tokens and depth > 0 do
        local inner = tokens[i]
        if inner.type == "capture_group" then
          depth = depth + 1
          table.insert(group_children, {
            type = inner.type,
            text = inner.text,
            explanation = inner.explanation,
          })
        elseif inner.type == "capture_group_end" then
          depth = depth - 1
          if depth > 0 then
            table.insert(group_children, {
              type = inner.type,
              text = inner.text,
              explanation = inner.explanation,
            })
          end
        else
          table.insert(group_children, {
            type = inner.type,
            text = inner.text,
            explanation = inner.explanation,
          })
        end
        i = i + 1
      end

      table.insert(children, {
        type = "capture_group",
        text = "(...)",
        explanation = EXPLANATIONS.capture_group,
        children = group_children,
      })

    -- Skip group ends at top level (already handled above)
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
    explanation = "Lua string.match() / string.gsub() Pattern",
    children = children,
  }
end

M.parse = function(pattern, opts)
  opts = opts or {}
  if not pattern or pattern == "" then
    return nil, "Empty pattern"
  end

  local tokens = parse_pattern(pattern)
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
    local matches = {}
    local start = 1

    while start <= #text do
      local s, e = text:find(pattern, start)
      if not s then
        break
      end

      local match_text = text:sub(s, e)
      table.insert(matches, {
        start = s,
        end_pos = e,
        text = match_text,
        groups = {},
      })

      start = e + 1
      if s > e then
        start = s + 1 -- avoid infinite loop on zero-width matches
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
