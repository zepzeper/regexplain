require("regexplain.adapter")

local regexplain = {}

regexplain.config = {
  adapter = "pcre",
  ui = {
    panel = {
      position = "right",
      width = 50,
      height = 15,
      open = nil,
    },
    keymaps = {},
  },
}

regexplain.setup = function(opts)
  opts = opts or {}
  regexplain.config = vim.tbl_deep_extend("force", regexplain.config, opts)

  -- Setup default keymaps
  local keymaps = opts.keymaps or {}
  if keymaps.explain_under_cursor ~= false then
    local lhs = keymaps.explain_under_cursor or "<leader>re"
    vim.keymap.set({ "n", "x" }, lhs, function()
      vim.cmd("RegexplainUnderCursor")
    end, { desc = "Explain regex under cursor", silent = true })
  end
end

regexplain.open = function(opts)
  require("regexplain.ui.panel").open(opts)
end

regexplain.close = function()
  require("regexplain.ui.panel").close()
end

regexplain.toggle = function(opts)
  require("regexplain.ui.panel").toggle(opts)
end

local function get_adapter(name)
  name = name or regexplain.config.adapter
  return require("regexplain.adapter.registry").get(name)
end

regexplain.parse = function(pattern, opts)
  opts = opts or {}
  local adapter_name = opts.adapter or regexplain.config.adapter
  local adapter = get_adapter(adapter_name)

  if not adapter then
    return nil, "Adapter not found: " .. adapter_name
  end

  if not adapter.parse then
    return nil, "Adapter '" .. adapter_name .. "' does not support parsing"
  end

  return adapter.parse(pattern, opts)
end

regexplain.match = function(pattern, text, opts)
  opts = opts or {}
  local adapter_name = opts.adapter or regexplain.config.adapter
  local adapter = get_adapter(adapter_name)

  if not adapter then
    return nil, "Adapter not found: " .. adapter_name
  end

  if not adapter.match then
    return nil, "Adapter '" .. adapter_name .. "' does not support matching"
  end

  return adapter.match(pattern, text, opts)
end

regexplain.list_adapters = function()
  return require("regexplain.adapter.registry").list_with_info()
end

regexplain.get_adapter = function(name)
  return get_adapter(name)
end

return regexplain
