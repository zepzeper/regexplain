local regexplain = require("regexplain")

describe("regexplain", function()
  describe("setup", function()
    it("has default config", function()
      assert.is_not_nil(regexplain.config)
      assert.is_table(regexplain.config.ui)
      assert.is_table(regexplain.config.ui.panel)
      assert.equals("pcre", regexplain.config.adapter)
    end)

    it("allows custom config", function()
      regexplain.setup({
        adapter = "lua",
        ui = {
          panel = { width = 40 },
        },
      })
      assert.equals("lua", regexplain.config.adapter)
      assert.equals(40, regexplain.config.ui.panel.width)
    end)
  end)

  describe("ui api", function()
    it("has open function", function()
      assert.is_function(regexplain.open)
    end)

    it("has close function", function()
      assert.is_function(regexplain.close)
    end)

    it("has toggle function", function()
      assert.is_function(regexplain.toggle)
    end)
  end)

  describe("adapter api", function()
    it("lists adapters", function()
      local adapters = regexplain.list_adapters()
      assert.is_table(adapters)
      assert.is_true(#adapters >= 3)

      local names = vim.tbl_map(function(a) return a.name end, adapters)
      assert.is_true(vim.tbl_contains(names, "lua"))
      assert.is_true(vim.tbl_contains(names, "vim"))
      assert.is_true(vim.tbl_contains(names, "pcre"))
    end)

    it("can get an adapter", function()
      local adapter = regexplain.get_adapter("lua")
      assert.is_not_nil(adapter)
      assert.equals("lua", adapter.name)
      assert.is_function(adapter.parse)
      assert.is_function(adapter.match)
    end)
  end)
end)
