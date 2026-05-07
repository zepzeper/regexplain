local M = {}

---@class Canvas
---@field lines string[]
---@field highlights table[]
---@field mappings table<integer, function>
local Canvas = {}
Canvas.__index = Canvas

function Canvas:new()
  return setmetatable({
    lines = {},
    highlights = {},
    mappings = {},
  }, self)
end

---@param text string
---@param opts? { hl?: string }
function Canvas:write(text, opts)
  opts = opts or {}
  local split_lines = vim.split(text, "\n", { plain = true })
  for i, line in ipairs(split_lines) do
    if i > 1 then
      table.insert(self.lines, "")
    end

    local col_start
    if #self.lines == 0 then
      table.insert(self.lines, line)
      col_start = 0
    else
      local current_line = self.lines[#self.lines]
      col_start = #current_line
      self.lines[#self.lines] = current_line .. line
    end

    if opts.hl and #line > 0 then
      table.insert(self.highlights, {
        line = #self.lines - 1, -- 0-indexed
        col_start = col_start,
        col_end = col_start + #line,
        hl_group = opts.hl,
      })
    end
  end
end

function Canvas:new_line()
  table.insert(self.lines, "")
end

---@param line integer 1-indexed line number
---@param callback function
function Canvas:add_mapping(line, callback)
  self.mappings[line] = callback
end

---@param buf integer buffer number
---@param namespace integer namespace number
---@return table<integer, function> mappings
function Canvas:render_to_buffer(buf, namespace)
  local api = vim.api

  api.nvim_buf_set_option(buf, "modifiable", true)

  api.nvim_buf_clear_namespace(buf, namespace, 0, -1)

  api.nvim_buf_set_lines(buf, 0, -1, false, self.lines)

  for _, hl in ipairs(self.highlights) do
    api.nvim_buf_set_extmark(buf, namespace, hl.line, hl.col_start, {
      end_col = hl.col_end,
      hl_group = hl.hl_group,
    })
  end

  api.nvim_buf_set_option(buf, "modifiable", false)
  api.nvim_buf_set_option(buf, "buftype", "nofile")

  return self.mappings
end

function Canvas:length()
  return #self.lines
end

M.Canvas = Canvas

return M
