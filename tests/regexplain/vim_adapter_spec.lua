local adapter = require("regexplain.adapter.adapters.vim")

describe("Vim regex adapter", function()
  describe("parse", function()
    it("parses literal characters in magic mode", function()
      local tree = adapter.parse("hello")
      assert.is_not_nil(tree)
      assert.equals("root", tree.type)
      assert.equals("hello", tree.text)
    end)

    it("parses magic mode switch", function()
      local tree = adapter.parse("\\vhello")
      assert.is_not_nil(tree)
      assert.equals("\\v", tree.children[1].text)
    end)

    it("parses anchors", function()
      local tree = adapter.parse("^test$")
      assert.is_not_nil(tree)
      local types = vim.tbl_map(function(c) return c.type end, tree.children)
      assert.is_true(vim.tbl_contains(types, "anchor_start"))
      assert.is_true(vim.tbl_contains(types, "anchor_end"))
    end)

    it("parses character classes", function()
      local tree = adapter.parse("\\d\\w")
      assert.is_not_nil(tree)
      local types = vim.tbl_map(function(c) return c.type end, tree.children)
      assert.is_true(vim.tbl_contains(types, "char_class"))
    end)

    it("parses capture groups", function()
      local tree = adapter.parse("\\(test\\)")
      assert.is_not_nil(tree)
      local has_group = false
      for _, child in ipairs(tree.children) do
        if child.type == "capture_group" then
          has_group = true
        end
      end
      assert.is_true(has_group)
    end)

    it("returns error for empty pattern", function()
      local tree, err = adapter.parse("")
      assert.is_nil(tree)
      assert.is_not_nil(err)
    end)
  end)

  describe("match", function()
    it("matches literal pattern", function()
      local result = adapter.match("hello", "hello world")
      assert.is_not_nil(result)
      assert.is_table(result.matches)
      assert.equals(1, #result.matches)
    end)

    it("returns error for empty pattern", function()
      local result, err = adapter.match("", "text")
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)
  end)
end)
