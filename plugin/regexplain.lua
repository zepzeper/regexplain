local function setup_highlights()
  vim.api.nvim_set_hl(0, "RegexplainPattern", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "RegexplainToken", { link = "Keyword", default = true })
  vim.api.nvim_set_hl(0, "RegexplainExplanation", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "RegexplainArrow", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "RegexplainMatch", { link = "Search", default = true })
  vim.api.nvim_set_hl(0, "RegexplainGroup", { link = "Type", default = true })
  vim.api.nvim_set_hl(0, "RegexplainCollapsed", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "RegexplainHelp", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "RegexplainError", { link = "ErrorMsg", default = true })
end

setup_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("RegexplainHighlights", { clear = true }),
  callback = setup_highlights,
})

vim.api.nvim_create_user_command("Regexplain", function(args)
  local regexplain = require("regexplain")
  if args.args and args.args ~= "" then
    regexplain.open({ enter = true })
    require("regexplain.ui.panel").set_pattern(args.args)
  else
    regexplain.toggle()
  end
end, { nargs = "?", desc = "Toggle Regexplain panel (optional: provide pattern)" })

vim.api.nvim_create_user_command("RegexplainPanel", function()
  require("regexplain").toggle()
end, { desc = "Toggle Regexplain panel" })

vim.api.nvim_create_user_command("RegexplainClose", function()
  require("regexplain").close()
end, { desc = "Close Regexplain panel" })

vim.api.nvim_create_user_command("RegexplainUnderCursor", function()
  local extract = require("regexplain.extract")
  local regexplain = require("regexplain")
  local panel = require("regexplain.ui.panel")

  local mode = vim.fn.mode()
  local is_visual = mode:match("v") or mode == "\22"

  local result
  if is_visual then
    result = extract.extract_visual()
  else
    result = extract.extract_from_cursor()
  end

  if not result then
    vim.notify("[regexplain] No regex pattern found under cursor", vim.log.levels.WARN)
    return
  end

  -- Auto-detect adapter from filetype BEFORE opening panel
  local ft = vim.bo.filetype
  local adapter_map = {
    lua = "lua",
    php = "pcre",
    vim = "vim",
    javascript = "pcre",
    typescript = "pcre",
    python = "pcre",
    perl = "pcre",
    ruby = "pcre",
    c = "pcre",
    cpp = "pcre",
    go = "pcre",
    rust = "pcre",
    java = "pcre",
    kotlin = "pcre",
    scala = "pcre",
    swift = "pcre",
    csharp = "pcre",
    fsharp = "pcre",
    erlang = "pcre",
    elixir = "pcre",
    haskell = "pcre",
    ocaml = "pcre",
    clojure = "pcre",
    lisp = "pcre",
    scheme = "pcre",
    r = "pcre",
    julia = "pcre",
    dart = "pcre",
    crystal = "pcre",
    nim = "pcre",
    zig = "pcre",
    v = "pcre",
    wren = "pcre",
    hack = "pcre",
  }

  local detected = adapter_map[ft]
  if detected then
    regexplain.config.adapter = detected
  elseif not regexplain.get_adapter(regexplain.config.adapter) then
    regexplain.config.adapter = "pcre"
  end

  if not panel.is_open() then
    regexplain.open({ enter = false })
  end

  panel.set_pattern(result.pattern)
end, { desc = "Explain regex under cursor", range = true })
