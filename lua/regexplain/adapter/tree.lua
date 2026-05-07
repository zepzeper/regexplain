--- Tree utilities for regexplain adapters

local M = {}

--- Collapse adjacent literal nodes into groups within a children array.
--- Each group becomes a collapsible node showing the combined text.
local function collapse_literals_in_children(children)
  if not children or #children == 0 then
    return children
  end

  local result = {}
  local literal_group = nil

  for _, node in ipairs(children) do
    -- Recursively process nested children first
    if node.children and #node.children > 0 then
      node.children = collapse_literals_in_children(node.children)
    end

    if node.type == "literal" then
      if not literal_group then
        literal_group = {
          type = "literal_group",
          text = node.text,
          explanation = "Matches '" .. node.text .. "' literally",
          children = { node },
        }
      else
        literal_group.text = literal_group.text .. node.text
        literal_group.explanation = "Matches '" .. literal_group.text .. "' literally"
        table.insert(literal_group.children, node)
      end
    else
      -- Flush pending literal group
      if literal_group then
        table.insert(result, literal_group)
        literal_group = nil
      end
      table.insert(result, node)
    end
  end

  -- Flush remaining literal group
  if literal_group then
    table.insert(result, literal_group)
  end

  return result
end

--- Collapse adjacent literal nodes into groups recursively throughout a tree.
---@param tree table the root node of the tree
---@return table the modified tree (same root, modified children)
function M.collapse_literals(tree)
  if not tree then
    return tree
  end

  if tree.children and #tree.children > 0 then
    tree.children = collapse_literals_in_children(tree.children)
  end

  return tree
end

--- Number capture groups recursively.
---@param tree table
---@return table tree (same reference)
function M.number_groups(tree)
  if not tree then
    return tree
  end

  local group_count = 0

  local function walk(node)
    if not node.children then
      return
    end

    for _, child in ipairs(node.children) do
      if child.type == "capture_group" then
        group_count = group_count + 1
        child.explanation = "Capture group #" .. group_count .. ": captures the matched text for backreference"
      end
      walk(child)
    end
  end

  walk(tree)
  return tree
end

--- Pools of meaningful example characters for different contexts.
--- Each pool provides variety across multiple generated examples.
local POOLS = {
  digit = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" },
  letter_lower = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
                   "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z" },
  letter_upper = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
                   "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z" },
  hex = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" },
  punct = { ".", "-", "_", "!", "?", ",", ":", ";", "'", "\"", "(", ")", "[", "]", "{", "}", "@", "#", "$", "%", "&", "*", "+", "=", "<", ">", "/", "\\", "|", "~", "^" },
  space = { " ", "\t" },
  non_word = { "@", "#", "$", "%", "&", "*", "+", "=", "<", ">", "/", "\\", "|", "~", "^", " ", "\t", "\n" },
  vowel = { "a", "e", "i", "o", "u" },
  consonant = { "b", "c", "d", "f", "g", "h", "j", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "w", "x", "y", "z" },
}

--- Map character class text to a pool name.
local CLASS_POOLS = {
  ["%d"] = "digit",
  ["%D"] = "letter_upper",
  ["%a"] = "letter_lower",
  ["%A"] = "digit",
  ["%l"] = "letter_lower",
  ["%L"] = "letter_upper",
  ["%u"] = "letter_upper",
  ["%U"] = "letter_lower",
  ["%w"] = "letter_lower",
  ["%W"] = "non_word",
  ["%s"] = "space",
  ["%S"] = "letter_upper",
  ["%p"] = "punct",
  ["%P"] = "letter_lower",
  ["%x"] = "hex",
  ["%X"] = "letter_lower",
  ["%c"] = "space",
  ["%C"] = "letter_lower",
  ["%g"] = "letter_lower",
  ["%G"] = "space",
  ["%z"] = "space",
  -- PHP PCRE
  ["\\d"] = "digit",
  ["\\D"] = "letter_upper",
  ["\\w"] = "letter_lower",
  ["\\W"] = "non_word",
  ["\\s"] = "space",
  ["\\S"] = "letter_upper",
  ["\\h"] = "space",
  ["\\H"] = "letter_upper",
  ["\\v"] = "space",
  ["\\V"] = "letter_upper",
  ["\\R"] = "space",
  ["\\N"] = "letter_lower",
  ["\\X"] = "letter_lower",
  ["\\b"] = nil,
  ["\\B"] = nil,
  ["\\A"] = nil,
  ["\\Z"] = nil,
  ["\\z"] = nil,
  ["\\G"] = nil,
  ["\\K"] = nil,
  -- Vim regex
  ["\\d"] = "digit",
  ["\\D"] = "letter_upper",
  ["\\w"] = "letter_lower",
  ["\\W"] = "non_word",
  ["\\s"] = "space",
  ["\\S"] = "letter_upper",
  ["\\h"] = "letter_lower",
  ["\\H"] = "digit",
  ["\\a"] = "letter_lower",
  ["\\A"] = "digit",
  ["\\l"] = "letter_lower",
  ["\\L"] = "letter_upper",
  ["\\u"] = "letter_upper",
  ["\\U"] = "letter_lower",
  ["\\x"] = "hex",
  ["\\X"] = "letter_lower",
  ["\\o"] = "digit",
  ["\\O"] = "letter_upper",
  ["\\i"] = "letter_lower",
  ["\\I"] = "digit",
  ["\\k"] = "letter_lower",
  ["\\K"] = "digit",
  ["\\f"] = "letter_lower",
  ["\\F"] = "digit",
  ["\\p"] = "letter_lower",
  ["\\P"] = "digit",
  ["\\c"] = "space",
  ["\\C"] = "letter_upper",
  ["\\t"] = "space",
  ["\\r"] = "space",
  ["\\n"] = "space",
  ["\\b"] = nil,
  ["\\<"] = nil,
  ["\\>"] = nil,
}

--- Pick a random-ish element from a list based on a seed/index.
local function pick(pool_name, idx)
  local pool = POOLS[pool_name]
  if not pool then
    return ""
  end
  idx = idx or 1
  return pool[((idx - 1) % #pool) + 1]
end

--- Parse quantifier bounds from text like {1,256} or {3} or {2,}.
local function parse_quantifier(text)
  local min, max = text:match("{(%d+),(%d+)}")
  if min then
    return tonumber(min), tonumber(max)
  end
  local exact = text:match("{(%d+)}")
  if exact then
    return tonumber(exact), tonumber(exact)
  end
  local at_least = text:match("{(%d+),}")
  if at_least then
    return tonumber(at_least), math.huge
  end
  return nil, nil
end

--- Get count for a quantifier type + text + strategy.
--- strategy: 1=minimal, 2=typical, 3=maximal/varied
local function quantifier_count(qtype, text, strategy)
  strategy = strategy or 2

  if qtype == "quantifier_zero_or_more" then
    if strategy == 1 then
      return 0
    elseif strategy == 2 then
      return 2
    else
      return 3
    end
  elseif qtype == "quantifier_one_or_more" then
    if strategy == 1 then
      return 1
    elseif strategy == 2 then
      return 2
    else
      return 3
    end
  elseif qtype == "quantifier_zero_or_one" then
    if strategy == 1 then
      return 0
    else
      return 1
    end
  elseif qtype == "quantifier_count" then
    local min, max = parse_quantifier(text)
    if min then
      if max and max ~= math.huge then
        if strategy == 1 then
          return min
        elseif strategy == 2 then
          return math.min(min + 1, max)
        else
          return max
        end
      else
        -- {n,} or {n}
        if strategy == 1 then
          return min
        elseif strategy == 2 then
          return min + 1
        else
          return min + 2
        end
      end
    end
    return 1
  end
  return 1
end

--- Extract meaningful characters from a character set.
local function pick_from_char_set(text, strategy)
  local inner = text:sub(2, -2)
  local negated = false

  if inner:sub(1, 1) == "^" then
    negated = true
    inner = inner:sub(2)
  end

  if negated then
    -- Pick a safe character NOT commonly in sets
    local safe = { "1", "A", "@", "#" }
    return safe[strategy or 1] or safe[1]
  end

  -- Collect all literal characters and range starts from the set
  local chars = {}
  local i = 1
  while i <= #inner do
    local c = inner:sub(i, i)
    if c == "\\" and i < #inner then
      local esc = inner:sub(i + 1, i + 1)
      local pool = CLASS_POOLS["\\" .. esc]
      if pool then
        table.insert(chars, pick(pool, strategy))
      else
        -- Escaped literal character inside set (e.g., \., \-, \])
        table.insert(chars, esc)
      end
      i = i + 2
    elseif c == "-" and i > 1 and i < #inner then
      -- Range: use start of range
      local prev = inner:sub(i - 1, i - 1)
      if prev:match("%w") then
        table.insert(chars, prev)
      end
      i = i + 1
    elseif c:match("%S") then
      table.insert(chars, c)
      i = i + 1
    else
      i = i + 1
    end
  end

  if #chars > 0 then
    return chars[math.min(strategy or 1, #chars)]
  end
  return "a"
end

--- Generate an example for a single node, using a strategy for variety.
---@param node table
---@param strategy integer 1=minimal, 2=typical, 3=varied/maximal
---@return string
local function generate_node(node, strategy)
  if not node then
    return ""
  end

  strategy = strategy or 2

  -- Find quantifier info
  local qcount = 1
  local has_quantifier = false
  if node.children then
    for _, child in ipairs(node.children) do
      if child.type:match("^quantifier") then
        qcount = quantifier_count(child.type, child.text or "", strategy)
        has_quantifier = true
      end
    end
  end

  local base = ""

  if node.type == "literal" or node.type == "literal_group" then
    base = node.text or ""
  elseif node.type == "escape" then
    local text = node.text or ""
    -- Strip leading escape character and convert known sequences
    if text:sub(1, 1) == "\\" then
      local esc = text:sub(2)
      if esc == "n" then
        base = "\n"
      elseif esc == "t" then
        base = "\t"
      elseif esc == "r" then
        base = "\r"
      elseif esc == "0" then
        base = "\0"
      else
        base = esc
      end
    elseif text:sub(1, 1) == "%" then
      -- Lua escape (e.g., %%. → ., %% → %)
      base = text:sub(2)
    else
      base = text
    end
  elseif node.type == "char_class" then
    local pool = CLASS_POOLS[node.text]
    if pool then
      base = pick(pool, strategy)
    else
      base = "x"
    end
  elseif node.type == "char_set" then
    base = pick_from_char_set(node.text, strategy)
  elseif node.type == "char_set_negated" then
    base = pick_from_char_set(node.text, strategy)
  elseif node.type == "any_character" then
    local any = { "x", "y", "z" }
    base = any[strategy] or "x"
  elseif node.type == "anchor_start" or node.type == "anchor_end"
      or node.type == "anchor_string_start" or node.type == "anchor_string_end"
      or node.type == "anchor_absolute_end"
      or node.type == "word_boundary" or node.type == "non_word_boundary"
      or node.type == "word_boundary_start" or node.type == "word_boundary_end"
      or node.type == "previous_match_end" or node.type == "start_of_match" then
    base = ""
  elseif node.type == "backreference" then
    base = ""
  elseif node.type == "magic_mode" then
    base = ""
  elseif node.type == "flags" or node.type == "flags_group" then
    base = ""
  elseif node.type == "quantifier_zero_or_more" or node.type == "quantifier_one_or_more"
      or node.type == "quantifier_zero_or_one" or node.type == "quantifier_count"
      or node.type == "quantifier_lazy" or node.type == "quantifier_possessive" then
    base = ""
  elseif node.type == "alternation" then
    base = ""
  elseif node.type == "comment" then
    base = ""
  elseif node.type == "lookahead_positive" or node.type == "lookahead_negative"
      or node.type == "lookbehind_positive" or node.type == "lookbehind_negative"
      or node.type == "atomic_group" or node.type == "branch_reset"
      or node.type == "non_capture_group"
      or node.type == "capture_group" or node.type == "named_capture"
      or node.type == "root" then

    -- Collect child parts with alternation branch selection
    local parts = {}
    local current_branch = {}
    local branch_index = 0

    for _, child in ipairs(node.children or {}) do
      if child.type == "alternation" then
        branch_index = branch_index + 1
        -- Strategy determines which branch to pick
        if branch_index == 0 or (strategy == 1 and branch_index == 0)
           or (strategy == 2 and branch_index <= 1)
           or (strategy >= 3 and branch_index == strategy - 2) then
          -- Continue with this branch
        else
          -- Skip to next branch
        end
      else
        table.insert(current_branch, child)
      end
    end

    -- If we hit alternation, we need to be smarter about branches
    -- Simpler approach: collect until alternation, then pick a branch
    parts = {}
    local branches = { {} }
    local current = 1

    for _, child in ipairs(node.children or {}) do
      if child.type == "alternation" then
        current = current + 1
        branches[current] = {}
      elseif not child.type:match("^quantifier") then
        table.insert(branches[current], child)
      end
    end

    -- Pick branch based on strategy (cycling through branches)
    local selected = branches[math.min(strategy, #branches)] or branches[1] or {}
    for _, child in ipairs(selected) do
      table.insert(parts, generate_node(child, strategy))
    end

    base = table.concat(parts)
  else
    -- Fallback: try children
    local parts = {}
    for _, child in ipairs(node.children or {}) do
      if not child.type:match("^quantifier") then
        table.insert(parts, generate_node(child, strategy))
      end
    end
    base = table.concat(parts)
  end

  if has_quantifier then
    -- For quantified char classes, vary the character across repetitions
    local pool = nil
    if node.type == "char_class" then
      pool = CLASS_POOLS[node.text]
    end
    if pool then
      local reps = {}
      for r = 1, qcount do
        table.insert(reps, pick(pool, strategy + r))
      end
      return table.concat(reps)
    end
    return base:rep(qcount)
  end

  return base
end

--- Generate a single example string from a regex tree.
---@param tree table
---@param strategy integer 1=minimal, 2=typical, 3=varied/maximal
---@return string
function M.generate_example(tree, strategy)
  if not tree then
    return ""
  end
  return generate_node(tree, strategy or 2)
end

--- Generate up to `count` distinct example strings from a regex tree.
--- Tries different strategies to produce variety.
---@param tree table
---@param count integer max examples to generate (default 3)
---@return string[] array of example strings
function M.generate_examples(tree, count)
  count = count or 3
  if not tree then
    return {}
  end

  local seen = {}
  local examples = {}

  for strategy = 1, count do
    local ex = generate_node(tree, strategy)
    if ex ~= "" and not seen[ex] then
      seen[ex] = true
      table.insert(examples, ex)
    end
  end

  -- If we got fewer than requested, try more strategies
  local strategy = count + 1
  while #examples < count and strategy < count + 10 do
    local ex = generate_node(tree, strategy)
    if ex ~= "" and not seen[ex] then
      seen[ex] = true
      table.insert(examples, ex)
    end
    strategy = strategy + 1
  end

  return examples
end

return M
