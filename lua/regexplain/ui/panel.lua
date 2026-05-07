local Canvas = require("regexplain.ui.canvas").Canvas

local M = {}

local state = {
  win = nil,
  buf = nil,
  namespace = vim.api.nvim_create_namespace("regexplain_panel"),
  pattern = "",
  test_string = "",
  tree = nil,
  expanded = {},
  mappings = {},
}

M.is_open = function()
  return state.win and vim.api.nvim_win_is_valid(state.win)
end

local function setup_buffer()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    return state.buf
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(state.buf, "Regexplain")
  vim.api.nvim_buf_set_option(state.buf, "filetype", "regexplain")
  vim.api.nvim_buf_set_option(state.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(state.buf, "buflisted", false)
  vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

  -- Buffer-local keymaps (dispatch via line metadata stored in module state)
  vim.keymap.set("n", "<CR>", function()
    local cb = state.mappings[vim.fn.line(".")]
    if type(cb) == "function" then
      cb()
    end
  end, { buffer = state.buf, silent = true, nowait = true, desc = "Expand/collapse node" })

  vim.keymap.set("n", "e", function()
    local cb = state.mappings[vim.fn.line(".")]
    if type(cb) == "function" then
      cb()
    end
  end, { buffer = state.buf, silent = true, nowait = true, desc = "Expand/collapse node" })

  vim.keymap.set("n", "r", function()
    M._explain()
    M.render()
  end, { buffer = state.buf, silent = true, desc = "Refresh explanation" })

  vim.keymap.set("n", "t", function()
    M.prompt_test_string()
  end, { buffer = state.buf, silent = true, desc = "Set test string" })

  vim.keymap.set("n", "p", function()
    M.prompt_pattern()
  end, { buffer = state.buf, silent = true, desc = "Set pattern" })

  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = state.buf, silent = true, desc = "Close panel" })

  vim.keymap.set("n", "?", function()
    vim.api.nvim_echo({
      { "Regexplain Panel\n", "Title" },
      { "\n" },
      { "<CR> or e  ", "Keyword" },
      { "expand / collapse node\n" },
      { "r          ", "Keyword" },
      { "refresh explanation\n" },
      { "t          ", "Keyword" },
      { "set test string\n" },
      { "p          ", "Keyword" },
      { "set pattern\n" },
      { "q          ", "Keyword" },
      { "close panel\n" },
      { "?          ", "Keyword" },
      { "show this help\n" },
    }, false, {})
  end, { buffer = state.buf, silent = true, desc = "Show help" })

  return state.buf
end

M.open = function(opts)
  opts = opts or {}
  if M.is_open() then
    return
  end

  local config = require("regexplain").config.ui.panel
  local prev_win = vim.api.nvim_get_current_win()

  setup_buffer()

  local open_cmd = opts.open or config.open
  if type(open_cmd) == "string" then
    vim.cmd(open_cmd)
    state.win = vim.api.nvim_get_current_win()
  elseif type(open_cmd) == "function" then
    state.win = open_cmd() or vim.api.nvim_get_current_win()
  else
    local position = opts.position or config.position or "right"
    local width = opts.width or config.width or 50
    local height = opts.height or config.height or 15

    if position == "right" then
      vim.cmd("botright vsplit")
      vim.cmd("vertical resize " .. width)
    elseif position == "left" then
      vim.cmd("topleft vsplit")
      vim.cmd("vertical resize " .. width)
    elseif position == "bottom" then
      vim.cmd("botright split")
      vim.cmd("resize " .. height)
    else
      vim.cmd("botright vsplit")
      vim.cmd("vertical resize " .. width)
    end
    state.win = vim.api.nvim_get_current_win()
  end

  vim.api.nvim_win_set_buf(state.win, state.buf)

  local ok, _ = pcall(vim.api.nvim_win_set_option, state.win, "winfixwidth", true)
  pcall(vim.api.nvim_win_set_option, state.win, "winfixheight", true)
  pcall(vim.api.nvim_win_set_option, state.win, "winfixbuf", true)
  pcall(vim.api.nvim_win_set_option, state.win, "number", false)
  pcall(vim.api.nvim_win_set_option, state.win, "relativenumber", false)
  pcall(vim.api.nvim_win_set_option, state.win, "spell", false)
  pcall(vim.api.nvim_win_set_option, state.win, "wrap", true)
  pcall(vim.api.nvim_win_set_option, state.win, "linebreak", true)
  pcall(vim.api.nvim_win_set_option, state.win, "cursorline", true)

  M.render()

  if not opts.enter then
    if vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
  end
end

M.close = function()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil

  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.buf = nil
end

M.toggle = function(opts)
  if M.is_open() then
    M.close()
  else
    M.open(opts)
  end
end

M.set_pattern = function(pattern)
  state.pattern = pattern
  state.expanded = {}
  M._explain()
  M.render()
end

M.set_test_string = function(text)
  state.test_string = text
  M.render()
end

M.prompt_pattern = function()
  vim.ui.input({ prompt = "Pattern: ", default = state.pattern }, function(input)
    if input then
      M.set_pattern(input)
    end
  end)
end

M.prompt_test_string = function()
  vim.ui.input({ prompt = "Test string: ", default = state.test_string }, function(input)
    if input then
      M.set_test_string(input)
    end
  end)
end

M._explain = function()
  if state.pattern == "" then
    state.tree = nil
    return
  end

  local regexplain = require("regexplain")
  local tree, err = regexplain.parse(state.pattern)

  if err then
    state.tree = {
      type = "error",
      text = "",
      explanation = "Error: " .. err,
      children = {},
    }
    return
  end

  state.tree = tree
end

local function node_key(node, depth, index)
  return node.type .. "_" .. (node.text or "") .. "_" .. depth .. "_" .. index
end

local function render_tree(canvas, node, depth, index)
  if not node then
    return
  end
  depth = depth or 0
  index = index or 1

  local has_children = node.children and #node.children > 0
  local key = node_key(node, depth, index)
  local is_expanded = node.type == "root" or state.expanded[key] == true

  local has_content = (node.text and node.text ~= "") or (node.explanation and node.explanation ~= "")
  local should_show_line = has_content

  if should_show_line then
    local indent = string.rep("  ", depth)
    local icon = has_children and (is_expanded and "▼ " or "▶ ") or "  "

    local line_num = canvas:length()
    canvas:write(indent .. icon, { hl = has_children and "RegexplainCollapsed" or nil })

    if node.text and node.text ~= "" then
      canvas:write(node.text, { hl = "RegexplainToken" })
      if node.explanation and node.explanation ~= "" then
        canvas:write(" → ", { hl = "RegexplainArrow" })
        canvas:write(node.explanation, { hl = "RegexplainExplanation" })
      end
    else
      canvas:write(node.explanation, { hl = "RegexplainExplanation" })
    end

    if has_children and node.type ~= "root" then
      canvas:add_mapping(line_num, function()
        state.expanded[key] = not (state.expanded[key] == true)
        M.render()
      end)
    end

    canvas:new_line()
  end

  if has_children and (not should_show_line or is_expanded) then
    for i, child in ipairs(node.children) do
      render_tree(canvas, child, should_show_line and depth + 1 or depth, i)
    end
  end
end

local function render_matches(canvas, pattern, test_string)
  if test_string == "" or pattern == "" then
    return
  end

  local regexplain = require("regexplain")
  local result, err = regexplain.match(pattern, test_string)

  canvas:write("  Test String", { hl = "RegexplainGroup" })
  canvas:new_line()

  if err or not result then
    canvas:write("    Error: " .. tostring(err or "matching not supported"), { hl = "RegexplainError" })
    canvas:new_line()
    return
  end

  local matches = result.matches or {}

  if #matches == 0 then
    canvas:write("    " .. test_string)
    canvas:new_line()
    canvas:write("    (no matches)", { hl = "RegexplainError" })
    canvas:new_line()
    return
  end

  -- Show test string with matched characters highlighted
  canvas:write("    ")
  for pos = 1, #test_string do
    local char = test_string:sub(pos, pos)
    local is_match = false
    for _, m in ipairs(matches) do
      if pos >= m.start and pos <= m.end_pos then
        is_match = true
        break
      end
    end
    if is_match then
      canvas:write(char, { hl = "RegexplainMatch" })
    else
      canvas:write(char)
    end
  end
  canvas:new_line()

  if #matches > 1 then
    canvas:write("    Matches (" .. #matches .. " found):", { hl = "RegexplainGroup" })
    canvas:new_line()
    for i, m in ipairs(matches) do
      local len = m.end_pos - m.start + 1
      canvas:write("      #" .. i .. ": '")
      canvas:write(m.text, { hl = "RegexplainMatch" })
      canvas:write("'", { hl = "Comment" })
      canvas:new_line()
      canvas:write("        at position " .. m.start .. "-" .. m.end_pos .. " (length " .. len .. ")", { hl = "Comment" })
      canvas:new_line()
    end
  else
    local m = matches[1]
    local len = m.end_pos - m.start + 1
    canvas:write("    Match #1: '")
    canvas:write(m.text, { hl = "RegexplainMatch" })
    canvas:write("'", { hl = "Comment" })
    canvas:new_line()
    canvas:write("      at position " .. m.start .. "-" .. m.end_pos .. " (length " .. len .. ")", { hl = "Comment" })
    canvas:new_line()
  end
end

M.render = function()
  if not M.is_open() then
    return
  end

  local canvas = Canvas:new()

  canvas:write(" Pattern", { hl = "RegexplainGroup" })
  canvas:new_line()
  if state.pattern ~= "" then
    canvas:write("  ")
    canvas:write(state.pattern, { hl = "RegexplainPattern" })
    canvas:new_line()
  else
    canvas:write("  (no pattern set)", { hl = "Comment" })
    canvas:new_line()
  end
  canvas:new_line()

  canvas:write(" Explanation", { hl = "RegexplainGroup" })
  canvas:new_line()

  if state.tree then
    render_tree(canvas, state.tree, 0, 1)
  elseif state.pattern == "" then
    canvas:write("  (no pattern set)", { hl = "Comment" })
    canvas:new_line()
  else
    canvas:write("  (unable to explain)", { hl = "RegexplainError" })
    canvas:new_line()
  end

  if state.tree then
    canvas:new_line()
    canvas:write(" Example Matches", { hl = "RegexplainGroup" })
    canvas:new_line()
    local examples = require("regexplain.adapter.tree").generate_examples(state.tree, 3)
    if #examples > 0 then
      for i, ex in ipairs(examples) do
        canvas:write("  " .. i .. ". '")
        canvas:write(ex, { hl = "RegexplainMatch" })
        canvas:write("'", { hl = "Comment" })
        canvas:new_line()
      end
    else
      canvas:write("  (unable to generate examples)", { hl = "Comment" })
      canvas:new_line()
    end
  end

  if state.test_string ~= "" then
    canvas:new_line()
    render_matches(canvas, state.pattern, state.test_string)
  end

  canvas:new_line()
  canvas:write(" [e]xpand [r]efresh [t]est [p]attern [q]uit [?]help", { hl = "RegexplainHelp" })
  canvas:new_line()

  state.mappings = canvas:render_to_buffer(state.buf, state.namespace)
end

return M
