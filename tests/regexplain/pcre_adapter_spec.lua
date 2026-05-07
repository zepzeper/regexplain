local adapter = require("regexplain.adapter.adapters.pcre")

describe("PCRE adapter", function()
  describe("parse", function()
    it("parses literal characters", function()
      local tree = adapter.parse("hello")
      assert.is_not_nil(tree)
      assert.equals("root", tree.type)
      assert.equals("hello", tree.text)
    end)

    it("parses anchors", function()
      local tree = adapter.parse("^test$")
      assert.is_not_nil(tree)
      local types = vim.tbl_map(function(c) return c.type end, tree.children)
      assert.is_true(vim.tbl_contains(types, "anchor_start"))
      assert.is_true(vim.tbl_contains(types, "anchor_end"))
    end)

    it("parses character class escapes", function()
      local tree = adapter.parse("\\d+\\w")
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

    it("parses non-capturing groups", function()
      local tree = adapter.parse("(?:test)")
      assert.is_not_nil(tree)
      local has_group = false
      for _, child in ipairs(tree.children) do
        if child.type == "non_capture_group" then
          has_group = true
        end
      end
      assert.is_true(has_group)
    end)

    it("parses lookahead", function()
      local tree = adapter.parse("foo(?=bar)")
      assert.is_not_nil(tree)
      local has_lookahead = false
      for _, child in ipairs(tree.children) do
        if child.type == "lookahead_positive" then
          has_lookahead = true
        end
      end
      assert.is_true(has_lookahead)
    end)

    it("parses named capture groups", function()
      local tree = adapter.parse("(?<name>test)")
      assert.is_not_nil(tree)
      local has_named = false
      for _, child in ipairs(tree.children) do
        if child.type == "named_capture" then
          has_named = true
        end
      end
      assert.is_true(has_named)
    end)

    it("parses alternation", function()
      local tree = adapter.parse("a|b")
      assert.is_not_nil(tree)
      local types = vim.tbl_map(function(c) return c.type end, tree.children)
      assert.is_true(vim.tbl_contains(types, "alternation"))
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
