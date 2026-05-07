local adapter = require("regexplain.adapter.adapters.lua")

describe("Lua pattern adapter", function()
  describe("parse", function()
    it("parses literal characters", function()
      local tree = adapter.parse("hello")
      assert.is_not_nil(tree)
      assert.equals("root", tree.type)
      assert.equals("hello", tree.text)
      assert.is_true(#tree.children == 1)
      assert.equals("literal_group", tree.children[1].type)
      assert.equals("hello", tree.children[1].text)
      assert.is_true(#tree.children[1].children == 5)
      for _, child in ipairs(tree.children[1].children) do
        assert.equals("literal", child.type)
      end
    end)

    it("parses anchors", function()
      local tree = adapter.parse("^test$")
      assert.is_not_nil(tree)
      local types = vim.tbl_map(function(c) return c.type end, tree.children)
      assert.is_true(vim.tbl_contains(types, "anchor_start"))
      assert.is_true(vim.tbl_contains(types, "anchor_end"))
    end)

    it("parses character class escapes", function()
      local tree = adapter.parse("%d+%a")
      assert.is_not_nil(tree)
      local types = vim.tbl_map(function(c) return c.type end, tree.children)
      assert.is_true(vim.tbl_contains(types, "char_class"))
    end)

    it("parses character sets", function()
      local tree = adapter.parse("[a-z]+")
      assert.is_not_nil(tree)
      local types = vim.tbl_map(function(c) return c.type end, tree.children)
      assert.is_true(vim.tbl_contains(types, "char_set"))
    end)

    it("parses quantifiers", function()
      local tree = adapter.parse("a*b+c?")
      assert.is_not_nil(tree)
      -- Quantifiers should be attached to their preceding element as children
      local has_quantifier = false
      for _, child in ipairs(tree.children) do
        if child.children and #child.children > 0 then
          has_quantifier = true
        end
      end
      assert.is_true(has_quantifier)
    end)

    it("parses capture groups", function()
      local tree = adapter.parse("(test)")
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
      assert.equals("hello", result.matches[1].text)
    end)

    it("returns empty matches when no match", function()
      local result = adapter.match("xyz", "hello world")
      assert.is_not_nil(result)
      assert.equals(0, #result.matches)
    end)

    it("returns error for empty pattern", function()
      local result, err = adapter.match("", "text")
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)
  end)
end)
