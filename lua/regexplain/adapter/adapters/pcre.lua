--- PCRE Adapter
--- Parses PCRE/PCRE2 (Perl Compatible Regular Expressions) into explanation trees.
--- Used by PHP, JavaScript, Python, Go, Rust, Java, and most modern languages.

local M = {
  name = "pcre",
  display_name = "PCRE (Perl Compatible Regular Expressions)",
  flavors = { "pcre", "pcre2" },
}

local EXPLANATIONS = {
  literal = function(text) return "Matches '" .. text .. "' literally" end,
  any_character = "Matches any single character (except line terminators)",
  anchor_start = "Matches the start of the string/line",
  anchor_end = "Matches the end of the string/line",
  anchor_string_start = "Matches the absolute start of the string",
  anchor_string_end = "Matches the absolute end of the string (before final newline)",
  anchor_absolute_end = "Matches the absolute end of the string",
  word_boundary = "Matches a word boundary (start/end of word)",
  non_word_boundary = "Matches inside a word (non-boundary)",
  previous_match_end = "Matches where the previous match ended",
  start_of_match = "Reset match start (drops characters before this point)",
  quantifier_zero_or_more = "Matches zero or more of the preceding",
  quantifier_one_or_more = "Matches one or more of the preceding",
  quantifier_zero_or_one = "Matches zero or one of the preceding (optional)",
  quantifier_lazy = "Lazy: matches as few characters as possible",
  quantifier_possessive = "Possessive: matches as much as possible without backtracking",
  capture_group = "Capture group: captures the matched text",
  non_capture_group = "Non-capturing group: groups without capturing",
  named_capture = function(name) return "Named capture group: '" .. name .. "'" end,
  atomic_group = "Atomic group: prevents backtracking into the group",
  lookahead_positive = "Positive lookahead: asserts what follows matches",
  lookahead_negative = "Negative lookahead: asserts what follows does NOT match",
  lookbehind_positive = "Positive lookbehind: asserts what precedes matches",
  lookbehind_negative = "Negative lookbehind: asserts what precedes does NOT match",
  alternation = "Alternation: match either the left or right side",
  backreference = function(n) return "Backreference to capture group #" .. n end,
  named_backreference = function(name) return "Backreference to named group '" .. name .. "'" end,
  comment = function(text) return "Comment: " .. text:sub(4, -2) end,
  conditional = "Conditional group",
  branch_reset = "Branch reset group: resets capture group numbering",
  newline_sequence = "Matches any newline sequence",
  not_newline = "Matches any character that is not a newline",
  grapheme_cluster = "Matches a Unicode grapheme cluster (user-perceived character)",
}

local CHAR_CLASSES = {
  ["d"] = "digit (0-9)",
  ["D"] = "non-digit",
  ["w"] = "word character [a-zA-Z0-9_]",
  ["W"] = "non-word character",
  ["s"] = "whitespace character",
  ["S"] = "non-whitespace character",
  ["h"] = "horizontal whitespace",
  ["H"] = "non-horizontal whitespace",
  ["v"] = "vertical whitespace",
  ["V"] = "non-vertical whitespace",
  ["R"] = "any newline sequence",
  ["N"] = "any character except newline",
  ["X"] = "Unicode grapheme cluster",
  ["K"] = "reset match start",
}

local POSIX_CLASSES = {
  ["alnum"] = "alphanumeric character",
  ["alpha"] = "alphabetic character",
  ["ascii"] = "ASCII character",
  ["blank"] = "blank character (space/tab)",
  ["cntrl"] = "control character",
  ["digit"] = "digit",
  ["graph"] = "visible character",
  ["lower"] = "lowercase letter",
  ["print"] = "printable character",
  ["punct"] = "punctuation character",
  ["space"] = "whitespace character",
  ["upper"] = "uppercase letter",
  ["word"] = "word character",
  ["xdigit"] = "hexadecimal digit",
}

local ESCAPE_CHARS = {
  ["n"] = "newline (\\n)",
  ["r"] = "carriage return (\\r)",
  ["t"] = "tab (\\t)",
  ["f"] = "form feed (\\f)",
  ["a"] = "bell/alarm (\\a)",
  ["e"] = "escape (\\e)",
  ["0"] = "null character",
}

local function tokenize(pattern)
  local tokens = {}
  local i = 1
  local len = #pattern

  while i <= len do
    local char = pattern:sub(i, i)

    -- Backslash escapes
    if char == "\\" and i < len then
      local next_char = pattern:sub(i + 1, i + 1)

      if next_char:match("[1-9]") then
        -- Octal or backreference? In PCRE, \1-\9 are always backreferences
        table.insert(tokens, {
          type = "backreference",
          text = "\\" .. next_char,
          explanation = EXPLANATIONS.backreference(next_char),
        })
        i = i + 2
      elseif next_char == "g" and i + 2 <= len then
        -- \g{...} or \g<...> or \g'...'
        local sep = pattern:sub(i + 2, i + 2)
        if sep == "{" then
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= "}" do
            j = j + 1
          end
          local ref = pattern:sub(i + 3, j - 1)
          table.insert(tokens, {
            type = "backreference",
            text = pattern:sub(i, j),
            explanation = EXPLANATIONS.backreference(ref),
          })
          i = j + 1
        elseif sep == "<" then
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= ">" do
            j = j + 1
          end
          local name = pattern:sub(i + 3, j - 1)
          table.insert(tokens, {
            type = "named_backreference",
            text = pattern:sub(i, j),
            explanation = EXPLANATIONS.named_backreference(name),
          })
          i = j + 1
        else
          -- \g followed by digit
          local j = i + 2
          while j <= len and pattern:sub(j, j):match("%d") do
            j = j + 1
          end
          local ref = pattern:sub(i + 2, j - 1)
          table.insert(tokens, {
            type = "backreference",
            text = pattern:sub(i, j - 1),
            explanation = EXPLANATIONS.backreference(ref),
          })
          i = j
        end
      elseif next_char == "k" and i + 2 <= len then
        -- \k<name>, \k'name', \k{name}
        local sep = pattern:sub(i + 2, i + 2)
        if sep == "<" then
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= ">" do
            j = j + 1
          end
          local name = pattern:sub(i + 3, j - 1)
          table.insert(tokens, {
            type = "named_backreference",
            text = pattern:sub(i, j),
            explanation = EXPLANATIONS.named_backreference(name),
          })
          i = j + 1
        elseif sep == "'" then
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= "'" do
            j = j + 1
          end
          local name = pattern:sub(i + 3, j - 1)
          table.insert(tokens, {
            type = "named_backreference",
            text = pattern:sub(i, j),
            explanation = EXPLANATIONS.named_backreference(name),
          })
          i = j + 1
        elseif sep == "{" then
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= "}" do
            j = j + 1
          end
          local name = pattern:sub(i + 3, j - 1)
          table.insert(tokens, {
            type = "named_backreference",
            text = pattern:sub(i, j),
            explanation = EXPLANATIONS.named_backreference(name),
          })
          i = j + 1
        else
          table.insert(tokens, { type = "escape", text = "\\k", explanation = "Literal 'k'" })
          i = i + 2
        end
      elseif CHAR_CLASSES[next_char] then
        table.insert(tokens, {
          type = "char_class",
          text = "\\" .. next_char,
          explanation = "Matches a " .. CHAR_CLASSES[next_char],
        })
        i = i + 2
      elseif next_char == "Q" then
        -- \Q...\E - literal text
        local j = i + 2
        while j <= len and not (pattern:sub(j, j) == "\\" and pattern:sub(j + 1, j + 1) == "E") do
          j = j + 1
        end
        local literal_text = pattern:sub(i + 2, j - 1)
        table.insert(tokens, {
          type = "literal_block",
          text = literal_text,
          explanation = "Literal text: '" .. literal_text .. "'",
        })
        i = j + 2
      elseif next_char == "x" then
        -- \xhh or \x{hhhh}
        if pattern:sub(i + 2, i + 2) == "{" then
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= "}" do
            j = j + 1
          end
          local hex = pattern:sub(i + 3, j - 1)
          table.insert(tokens, {
            type = "escape",
            text = pattern:sub(i, j),
            explanation = "Character with hex value 0x" .. hex,
          })
          i = j + 1
        else
          local hex = pattern:sub(i + 2, i + 3)
          table.insert(tokens, {
            type = "escape",
            text = pattern:sub(i, i + 3),
            explanation = "Character with hex value 0x" .. hex,
          })
          i = i + 4
        end
      elseif next_char == "u" then
        if pattern:sub(i + 2, i + 2) == "{" then
          -- \u{hhhh}
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= "}" do
            j = j + 1
          end
          local hex = pattern:sub(i + 3, j - 1)
          table.insert(tokens, {
            type = "escape",
            text = pattern:sub(i, j),
            explanation = "Unicode character U+" .. hex,
          })
          i = j + 1
        else
          -- \uhhhh
          local hex = pattern:sub(i + 2, i + 5)
          table.insert(tokens, {
            type = "escape",
            text = pattern:sub(i, i + 5),
            explanation = "Unicode character U+" .. hex,
          })
          i = i + 6
        end
      elseif next_char == "U" then
        -- \Uhhhhhhhh
        local hex = pattern:sub(i + 2, i + 9)
        table.insert(tokens, {
          type = "escape",
          text = pattern:sub(i, i + 9),
          explanation = "Unicode character U+" .. hex,
        })
        i = i + 10
      elseif next_char == "N" then
        if pattern:sub(i + 2, i + 2) == "{" then
          -- \N{name}
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= "}" do
            j = j + 1
          end
          local name = pattern:sub(i + 3, j - 1)
          table.insert(tokens, {
            type = "escape",
            text = pattern:sub(i, j),
            explanation = "Unicode character '" .. name .. "'",
          })
          i = j + 1
        else
          table.insert(tokens, { type = "escape", text = "\\N", explanation = EXPLANATIONS.not_newline })
          i = i + 2
        end
      elseif next_char == "c" and i + 2 <= len then
        local ctrl = pattern:sub(i + 2, i + 2)
        table.insert(tokens, {
          type = "escape",
          text = pattern:sub(i, i + 2),
          explanation = "Control character: Ctrl+" .. ctrl:upper(),
        })
        i = i + 3
      elseif ESCAPE_CHARS[next_char] then
        table.insert(tokens, {
          type = "escape",
          text = "\\" .. next_char,
          explanation = ESCAPE_CHARS[next_char],
        })
        i = i + 2
      elseif next_char == "o" then
        -- \o{ooo} - octal
        if pattern:sub(i + 2, i + 2) == "{" then
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= "}" do
            j = j + 1
          end
          local oct = pattern:sub(i + 3, j - 1)
          table.insert(tokens, {
            type = "escape",
            text = pattern:sub(i, j),
            explanation = "Character with octal value " .. oct,
          })
          i = j + 1
        else
          table.insert(tokens, { type = "escape", text = "\\o", explanation = "Literal 'o'" })
          i = i + 2
        end
      elseif next_char == "p" or next_char == "P" then
        -- \p{...} or \P{...} Unicode property
        if pattern:sub(i + 2, i + 2) == "{" then
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= "}" do
            j = j + 1
          end
          local prop = pattern:sub(i + 3, j - 1)
          local neg = next_char == "P" and " NOT" or ""
          table.insert(tokens, {
            type = "char_class",
            text = pattern:sub(i, j),
            explanation = "Matches a character" .. neg .. " in Unicode property '" .. prop .. "'",
          })
          i = j + 1
        else
          table.insert(tokens, { type = "escape", text = "\\" .. next_char, explanation = "Literal '" .. next_char .. "'" })
          i = i + 2
        end
      elseif next_char == "b" then
        table.insert(tokens, { type = "word_boundary", text = "\\b", explanation = EXPLANATIONS.word_boundary })
        i = i + 2
      elseif next_char == "B" then
        table.insert(tokens, { type = "non_word_boundary", text = "\\B", explanation = EXPLANATIONS.non_word_boundary })
        i = i + 2
      elseif next_char == "A" then
        table.insert(tokens, { type = "anchor_string_start", text = "\\A", explanation = EXPLANATIONS.anchor_string_start })
        i = i + 2
      elseif next_char == "Z" then
        table.insert(tokens, { type = "anchor_string_end", text = "\\Z", explanation = EXPLANATIONS.anchor_string_end })
        i = i + 2
      elseif next_char == "z" then
        table.insert(tokens, { type = "anchor_absolute_end", text = "\\z", explanation = EXPLANATIONS.anchor_absolute_end })
        i = i + 2
      elseif next_char == "G" then
        table.insert(tokens, { type = "previous_match_end", text = "\\G", explanation = EXPLANATIONS.previous_match_end })
        i = i + 2
      elseif next_char == "K" then
        table.insert(tokens, { type = "start_of_match", text = "\\K", explanation = EXPLANATIONS.start_of_match })
        i = i + 2
      else
        -- Escaped literal
        table.insert(tokens, {
          type = "escape",
          text = "\\" .. next_char,
          explanation = "Escaped character: '" .. next_char .. "'",
        })
        i = i + 2
      end

    elseif char == "^" then
      table.insert(tokens, { type = "anchor_start", text = "^", explanation = EXPLANATIONS.anchor_start })
      i = i + 1
    elseif char == "$" then
      table.insert(tokens, { type = "anchor_end", text = "$", explanation = EXPLANATIONS.anchor_end })
      i = i + 1

    elseif char == "*" then
      if pattern:sub(i + 1, i + 1) == "?" then
        table.insert(tokens, { type = "quantifier_zero_or_more", text = "*?", explanation = EXPLANATIONS.quantifier_zero_or_more .. " (lazy)" })
        i = i + 2
      elseif pattern:sub(i + 1, i + 1) == "+" then
        table.insert(tokens, { type = "quantifier_zero_or_more", text = "*+", explanation = EXPLANATIONS.quantifier_zero_or_more .. " (possessive)" })
        i = i + 2
      else
        table.insert(tokens, { type = "quantifier_zero_or_more", text = "*", explanation = EXPLANATIONS.quantifier_zero_or_more })
        i = i + 1
      end
    elseif char == "+" then
      if pattern:sub(i + 1, i + 1) == "?" then
        table.insert(tokens, { type = "quantifier_one_or_more", text = "+?", explanation = EXPLANATIONS.quantifier_one_or_more .. " (lazy)" })
        i = i + 2
      elseif pattern:sub(i + 1, i + 1) == "+" then
        table.insert(tokens, { type = "quantifier_one_or_more", text = "++", explanation = EXPLANATIONS.quantifier_one_or_more .. " (possessive)" })
        i = i + 2
      else
        table.insert(tokens, { type = "quantifier_one_or_more", text = "+", explanation = EXPLANATIONS.quantifier_one_or_more })
        i = i + 1
      end
    elseif char == "?" then
      if pattern:sub(i + 1, i + 1) == "?" then
        table.insert(tokens, { type = "quantifier_zero_or_one", text = "??", explanation = EXPLANATIONS.quantifier_zero_or_one .. " (lazy)" })
        i = i + 2
      elseif pattern:sub(i + 1, i + 1) == "+" then
        table.insert(tokens, { type = "quantifier_zero_or_one", text = "?+", explanation = EXPLANATIONS.quantifier_zero_or_one .. " (possessive)" })
        i = i + 2
      else
        table.insert(tokens, { type = "quantifier_zero_or_one", text = "?", explanation = EXPLANATIONS.quantifier_zero_or_one })
        i = i + 1
      end
    elseif char == "{" then
      -- {n}, {n,}, {n,m}
      local j = i + 1
      while j <= len and pattern:sub(j, j):match("[%d,]") do
        j = j + 1
      end
      if j <= len and pattern:sub(j, j) == "}" then
        local spec = pattern:sub(i + 1, j - 1)
        local suffix = ""
        local text = pattern:sub(i, j)
        if pattern:sub(j + 1, j + 1) == "?" then
          suffix = " (lazy)"
          text = text .. "?"
          j = j + 1
        elseif pattern:sub(j + 1, j + 1) == "+" then
          suffix = " (possessive)"
          text = text .. "+"
          j = j + 1
        end

        local exp = "Quantifier"
        if spec:match("^%d+,%d+$") then
          exp = "Matches between " .. spec:gsub(",", " and ") .. " times"
        elseif spec:match("^%d+,$") then
          exp = "Matches " .. spec:gsub(",", "") .. " or more times"
        else
          exp = "Matches exactly " .. spec .. " times"
        end

        table.insert(tokens, { type = "quantifier_count", text = text, explanation = exp .. suffix })
        i = j + 1
      else
        -- Literal {
        table.insert(tokens, { type = "literal", text = "{", explanation = EXPLANATIONS.literal("{") })
        i = i + 1
      end

    elseif char == "." then
      table.insert(tokens, { type = "any_character", text = ".", explanation = EXPLANATIONS.any_character })
      i = i + 1

    elseif char == "[" then
      local j = i + 1
      local negated = false
      if j <= len and pattern:sub(j, j) == "^" then
        negated = true
        j = j + 1
      end

      -- Handle nested brackets for POSIX classes [[:alpha:]]
      while j <= len and pattern:sub(j, j) ~= "]" do
        if pattern:sub(j, j) == "\\" and j < len then
          j = j + 2
        elseif pattern:sub(j, j) == "[" then
          -- POSIX class or special construct
          j = j + 1
        else
          j = j + 1
        end
      end

      local text = pattern:sub(i, j)
      if negated then
        table.insert(tokens, { type = "char_set_negated", text = text, explanation = "Negated character set" })
      else
        table.insert(tokens, { type = "char_set", text = text, explanation = "Character set" })
      end
      i = j + 1

    elseif char == "(" then
      if pattern:sub(i + 1, i + 1) == "?" then
        local next2 = pattern:sub(i + 2, i + 2)
        local next3 = pattern:sub(i + 3, i + 3)

        if next2 == ":" then
          -- (?:...) Non-capturing
          table.insert(tokens, { type = "non_capture_group", text = "(?:", explanation = EXPLANATIONS.non_capture_group })
          i = i + 3
        elseif next2 == "=" then
          -- (?=...) Positive lookahead
          table.insert(tokens, { type = "lookahead_positive", text = "(?=", explanation = EXPLANATIONS.lookahead_positive })
          i = i + 3
        elseif next2 == "!" then
          -- (?!...) Negative lookahead
          table.insert(tokens, { type = "lookahead_negative", text = "(?!", explanation = EXPLANATIONS.lookahead_negative })
          i = i + 3
        elseif next2 == "<" and next3 == "=" then
          -- (?<=...) Positive lookbehind
          table.insert(tokens, { type = "lookbehind_positive", text = "(?<=", explanation = EXPLANATIONS.lookbehind_positive })
          i = i + 4
        elseif next2 == "<" and next3 == "!" then
          -- (?<!...) Negative lookbehind
          table.insert(tokens, { type = "lookbehind_negative", text = "(?<!", explanation = EXPLANATIONS.lookbehind_negative })
          i = i + 4
        elseif next2 == ">" then
          -- (?>...) Atomic group
          table.insert(tokens, { type = "atomic_group", text = "(?>", explanation = EXPLANATIONS.atomic_group })
          i = i + 3
        elseif next2 == "#" then
          -- (?#...) Comment
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= ")" do
            if pattern:sub(j, j) == "\\" and j < len then
              j = j + 2
            else
              j = j + 1
            end
          end
          local text = pattern:sub(i, j)
          table.insert(tokens, { type = "comment", text = text, explanation = EXPLANATIONS.comment(text) })
          i = j + 1
        elseif next2 == "|" then
          -- (?|...) Branch reset
          table.insert(tokens, { type = "branch_reset", text = "(?|", explanation = EXPLANATIONS.branch_reset })
          i = i + 3
        elseif next2 == "<" then
          -- (?<name>...) Named capture (PCRE)
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= ">" do
            j = j + 1
          end
          local name = pattern:sub(i + 3, j - 1)
          table.insert(tokens, { type = "named_capture", text = "(?<" .. name .. ">", explanation = EXPLANATIONS.named_capture(name) })
          i = j + 1
        elseif next2 == "'" then
          -- (?'name'...) Named capture (PCRE2)
          local j = i + 3
          while j <= len and pattern:sub(j, j) ~= "'" do
            j = j + 1
          end
          local name = pattern:sub(i + 3, j - 1)
          table.insert(tokens, { type = "named_capture", text = "(?'" .. name .. "'", explanation = EXPLANATIONS.named_capture(name) })
          i = j + 1
        elseif next2 == "P" and next3 == "<" then
          -- (?P<name>...) Named capture (Python/PHP style)
          local j = i + 4
          while j <= len and pattern:sub(j, j) ~= ">" do
            j = j + 1
          end
          local name = pattern:sub(i + 4, j - 1)
          table.insert(tokens, { type = "named_capture", text = "(?P<" .. name .. ">", explanation = EXPLANATIONS.named_capture(name) })
          i = j + 1
        elseif next2 == "P" and next3 == "=" then
          -- (?P=name) Named backreference
          local j = i + 4
          while j <= len and pattern:sub(j, j) ~= ")" do
            j = j + 1
          end
          local name = pattern:sub(i + 4, j - 1)
          table.insert(tokens, { type = "named_backreference", text = "(?P=" .. name .. ")", explanation = EXPLANATIONS.named_backreference(name) })
          i = j + 1
        elseif next2:match("[iJmnsUxXDS]+%)") then
          -- Inline flags like (?i), (?i:...), (?-i), (?i-m)
          local j = i + 2
          while j <= len and pattern:sub(j, j):match("[iJmnsUxXDS%-]") do
            j = j + 1
          end
          if pattern:sub(j, j) == ")" then
            local flags = pattern:sub(i + 2, j - 1)
            table.insert(tokens, { type = "flags", text = pattern:sub(i, j), explanation = "Flags: " .. flags })
            i = j + 1
          elseif pattern:sub(j, j) == ":" then
            local flags = pattern:sub(i + 2, j - 1)
            table.insert(tokens, { type = "flags_group", text = pattern:sub(i, j), explanation = "Flags " .. flags .. ": non-capturing group with local flags" })
            i = j + 1
          else
            table.insert(tokens, { type = "literal", text = "(", explanation = EXPLANATIONS.literal("(") })
            i = i + 1
          end
        else
          table.insert(tokens, { type = "literal", text = "(", explanation = EXPLANATIONS.literal("(") })
          i = i + 1
        end
      else
        -- (...) Capture group
        table.insert(tokens, { type = "capture_group", text = "(", explanation = EXPLANATIONS.capture_group })
        i = i + 1
      end

    elseif char == ")" then
      table.insert(tokens, { type = "capture_group_end", text = ")", explanation = "End of group" })
      i = i + 1

    elseif char == "|" then
      table.insert(tokens, { type = "alternation", text = "|", explanation = EXPLANATIONS.alternation })
      i = i + 1

    else
      table.insert(tokens, { type = "literal", text = char, explanation = EXPLANATIONS.literal(char) })
      i = i + 1
    end
  end

  return tokens
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
    elseif tok.type == "capture_group" or tok.type == "non_capture_group"
        or tok.type == "lookahead_positive" or tok.type == "lookahead_negative"
        or tok.type == "lookbehind_positive" or tok.type == "lookbehind_negative"
        or tok.type == "atomic_group" or tok.type == "branch_reset"
        or tok.type == "named_capture" or tok.type == "flags_group" then
      local group_children = {}
      local depth = 1
      i = i + 1
      while i <= #tokens and depth > 0 do
        local inner = tokens[i]
        if inner.type == "capture_group" or inner.type == "non_capture_group"
            or inner.type == "lookahead_positive" or inner.type == "lookahead_negative"
            or inner.type == "lookbehind_positive" or inner.type == "lookbehind_negative"
            or inner.type == "atomic_group" or inner.type == "branch_reset"
            or inner.type == "named_capture" or inner.type == "flags_group" then
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
        type = tok.type,
        text = tok.text,
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
    explanation = "PCRE Regular Expression Pattern",
    children = children,
  }
end

M.parse = function(pattern, opts)
  opts = opts or {}
  if not pattern or pattern == "" then
    return nil, "Empty pattern"
  end

  local tokens = tokenize(pattern)
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

  -- Use vim.regex for matching if available (it supports some PCRE-like syntax)
  -- For more accurate PCRE matching we'd need a PCRE library, but vim.regex
  -- works for many common patterns
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
