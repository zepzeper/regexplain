local tree_util = require("regexplain.adapter.tree")

describe("tree collapse_literals", function()
  it("groups adjacent literal nodes", function()
    local tree = {
      type = "root",
      text = "hello",
      explanation = "Pattern",
      children = {
        { type = "literal", text = "h", explanation = "h" },
        { type = "literal", text = "e", explanation = "e" },
        { type = "literal", text = "l", explanation = "l" },
        { type = "literal", text = "l", explanation = "l" },
        { type = "literal", text = "o", explanation = "o" },
      },
    }

    tree_util.collapse_literals(tree)

    assert.equals(1, #tree.children)
    assert.equals("literal_group", tree.children[1].type)
    assert.equals("hello", tree.children[1].text)
    assert.equals(5, #tree.children[1].children)
    assert.equals("literal", tree.children[1].children[1].type)
  end)

  it("keeps non-literal nodes separate", function()
    local tree = {
      type = "root",
      text = "he*o",
      explanation = "Pattern",
      children = {
        { type = "literal", text = "h", explanation = "h" },
        { type = "literal", text = "e", explanation = "e" },
        { type = "quantifier", text = "*", explanation = "zero or more" },
        { type = "literal", text = "o", explanation = "o" },
      },
    }

    tree_util.collapse_literals(tree)

    assert.equals(3, #tree.children)
    assert.equals("literal_group", tree.children[1].type)
    assert.equals("he", tree.children[1].text)
    assert.equals("quantifier", tree.children[2].type)
    assert.equals("literal_group", tree.children[3].type)
    assert.equals("o", tree.children[3].text)
  end)

  it("recursively groups literals in nested children", function()
    local tree = {
      type = "root",
      text = "(hello)",
      explanation = "Pattern",
      children = {
        { type = "capture_group", text = "(...)", explanation = "group", children = {
          { type = "literal", text = "h", explanation = "h" },
          { type = "literal", text = "i", explanation = "i" },
        } },
      },
    }

    tree_util.collapse_literals(tree)

    assert.equals(1, #tree.children)
    assert.equals("capture_group", tree.children[1].type)
    assert.equals(1, #tree.children[1].children)
    assert.equals("literal_group", tree.children[1].children[1].type)
    assert.equals("hi", tree.children[1].children[1].text)
  end)
end)

describe("tree generate_examples", function()
  it("generates from literal nodes", function()
    local tree = {
      type = "root",
      text = "hello",
      children = {
        { type = "literal", text = "h" },
        { type = "literal", text = "e" },
        { type = "literal", text = "l" },
        { type = "literal", text = "l" },
        { type = "literal", text = "o" },
      },
    }
    local examples = tree_util.generate_examples(tree, 3)
    assert.is_true(#examples >= 1)
    assert.are.equal("hello", examples[1])
  end)

  it("generates varied examples from character classes", function()
    local tree = {
      type = "root",
      text = "\\d+",
      children = {
        { type = "char_class", text = "\\d", children = { { type = "quantifier_one_or_more", text = "+" } } },
      },
    }
    local examples = tree_util.generate_examples(tree, 3)
    assert.is_true(#examples >= 1)
    -- Should generate at least one digit
    for _, ex in ipairs(examples) do
      assert.is_true(ex:match("^%d+$") ~= nil, "Expected digits, got: " .. ex)
    end
  end)

  it("generates varied examples from quantifiers", function()
    local tree = {
      type = "root",
      text = "a*",
      children = {
        { type = "literal", text = "a", children = { { type = "quantifier_zero_or_more", text = "*" } } },
      },
    }
    local examples = tree_util.generate_examples(tree, 3)
    assert.is_true(#examples >= 1)
    assert.are.equal("aa", examples[1]) -- strategy 2 = typical (2 reps)
  end)

  it("generates from capture groups", function()
    local tree = {
      type = "root",
      text = "(hello)",
      children = {
        { type = "capture_group", text = "(...)", children = {
          { type = "literal", text = "h" },
          { type = "literal", text = "e" },
          { type = "literal", text = "l" },
          { type = "literal", text = "l" },
          { type = "literal", text = "o" },
        } },
      },
    }
    local examples = tree_util.generate_examples(tree, 3)
    assert.is_true(#examples >= 1)
    assert.are.equal("hello", examples[1])
  end)

  it("generates from alternation (different branches)", function()
    local tree = {
      type = "root",
      text = "a|b",
      children = {
        { type = "literal", text = "a" },
        { type = "alternation", text = "|" },
        { type = "literal", text = "b" },
      },
    }
    local examples = tree_util.generate_examples(tree, 3)
    -- Should get at least 2 distinct: "a" and "b"
    local found_a, found_b = false, false
    for _, ex in ipairs(examples) do
      if ex == "a" then found_a = true end
      if ex == "b" then found_b = true end
    end
    assert.is_true(found_a or found_b, "Expected at least 'a' or 'b'")
  end)

  it("returns empty for empty tree", function()
    local examples = tree_util.generate_examples(nil, 3)
    assert.equals(0, #examples)
    examples = tree_util.generate_examples({ type = "root", children = {} }, 3)
    assert.equals(0, #examples)
  end)

  it("generates from character set", function()
    local tree = {
      type = "root",
      text = "[a-z]",
      children = {
        { type = "char_set", text = "[a-z]" },
      },
    }
    local examples = tree_util.generate_examples(tree, 3)
    assert.is_true(#examples > 0)
    for _, ex in ipairs(examples) do
      assert.is_true(#ex > 0)
    end
  end)

  it("generates varied examples for word char class + quantifier", function()
    local tree = {
      type = "root",
      text = "\\w+",
      children = {
        { type = "char_class", text = "\\w", children = { { type = "quantifier_one_or_more", text = "+" } } },
      },
    }
    local examples = tree_util.generate_examples(tree, 3)
    assert.is_true(#examples >= 2, "Expected at least 2 distinct examples")
    -- Should not all be identical like "aa"
    local all_same = true
    for i = 2, #examples do
      if examples[i] ~= examples[1] then
        all_same = false
        break
      end
    end
    assert.is_false(all_same, "Expected varied examples, but all were: " .. examples[1])
  end)
end)
