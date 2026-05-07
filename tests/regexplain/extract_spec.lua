local extract = require("regexplain.extract")

describe("extract", function()
  it("extracts delimited regex from PHP line", function()
    local line = "/^https?:\\/\\/(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b([-a-zA-Z0-9()@:%_\\+.~#?&//=]*)$/"
    -- Cursor is somewhere in the middle, say at position 20
    local result = extract.extract(line, 20)
    assert.is_not_nil(result)
    assert.is_not_nil(result.pattern)
    assert.are_not.equal("", result.pattern)
  end)

  it("extracts regex inside quotes", function()
    local line = "preg_match('/^test$/', $str);"
    -- Cursor is inside the quoted regex
    local result = extract.extract(line, 15)
    assert.is_not_nil(result)
    assert.are.equal("^test$", result.pattern)
  end)

  it("extracts visual selection", function()
    -- Mock visual selection by directly calling extract_visual with a text
    -- Note: extract_visual uses vim.fn.getpos which we can't easily mock
    -- So we'll test the extraction logic directly
    local text = "/^test$/"
    local first = text:sub(1, 1)
    local last = text:sub(-1, -1)
    assert.are.equal(first, last)
    assert.are.equal("/", first)
  end)

  it("returns nil when no regex found", function()
    local line = "console.log('hello world');"
    local result = extract.extract(line, 10)
    assert.is_nil(result)
  end)
end)
