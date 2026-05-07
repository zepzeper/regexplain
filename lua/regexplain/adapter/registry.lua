--- Adapter Registry
--- Community adapters can be registered via require("regexplain.adapter.registry").register(name, adapter)

local M = {}

M.adapters = {}

--- Register an adapter
---@param name string unique identifier
---@param adapter table adapter module
M.register = function(name, adapter)
  M.adapters[name] = adapter
end

--- Get an adapter by name
---@param name string
---@return table|nil
M.get = function(name)
  return M.adapters[name]
end

--- List all registered adapter names
---@return string[]
M.list = function()
  return vim.tbl_keys(M.adapters)
end

--- List all adapter names with their display names
---@return table[] { name, display_name }
M.list_with_info = function()
  local result = {}
  for name, adapter in pairs(M.adapters) do
    table.insert(result, {
      name = name,
      display_name = adapter.display_name or name,
    })
  end
  table.sort(result, function(a, b) return a.name < b.name end)
  return result
end

return M
