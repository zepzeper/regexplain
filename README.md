# regexplain.nvim

A Neovim plugin for visualizing, explaining, and debugging regular expressions. Inspired by [regex101.com](https://regex101.com/).

## Features

- **Visual explanation tree** — Break down any regex into human-readable tokens with collapsible sections
- **Multiple regex flavors** — Built-in support for:
  - PCRE (Perl Compatible Regular Expressions)
  - Lua patterns (`string.match`, `string.gsub`)
  - Vim regex (magic, nomagic, very magic, very nomagic)
- **Under-cursor detection** — Automatically detects regex patterns in your source code
- **Match visualization** — Highlight matched characters in test strings
- **Example generation** — Auto-generate example strings that match your pattern
- **Extensible adapter system** — Community can add custom parsers for any regex flavor
- **Sidebar panel UI** — Clean, toggleable panel inspired by neotest.nvim

## Requirements

- Neovim >= 0.8.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (for tests)

## Installation

### lazy.nvim

```lua
{
  "zepzeper/regexplain.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("regexplain").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "zepzeper/regexplain.nvim",
  requires = { "nvim-lua/plenary.nvim" },
  config = function()
    require("regexplain").setup()
  end,
}
```

## Usage

### Commands

| Command | Description |
|---|---|
| `:Regexplain [pattern]` | Toggle the sidebar panel (optionally with a pattern) |
| `:RegexplainPanel` | Toggle the sidebar panel |
| `:RegexplainClose` | Close the sidebar panel |
| `:RegexplainUnderCursor` | Detect and explain regex under cursor or selection |

### Default Keymaps

| Mode | Key | Action |
|---|---|---|
| `n`, `x` | `<leader>re` | Explain regex under cursor / selection |

### Panel Keymaps

| Key | Action |
|---|---|
| `<CR>` or `e` | Expand / collapse node |
| `r` | Refresh explanation |
| `t` | Set test string |
| `p` | Set pattern |
| `q` | Close panel |
| `?` | Show help |

### In the Panel

1. **Pattern** — The regex being analyzed
2. **Explanation** — Collapsible tree of tokens (literals, groups, quantifiers, etc.)
3. **Example Matches** — Auto-generated strings that would match the pattern
4. **Test String** — Your manual input with match highlighting

## Configuration

```lua
require("regexplain").setup({
  -- Default adapter (pcre | lua | vim)
  adapter = "pcre",

  -- Panel appearance
  ui = {
    panel = {
      position = "right", -- "right" | "left" | "bottom"
      width = 50,
      height = 15,
    },
  },

  -- Keymaps (set to false to disable)
  keymaps = {
    explain_under_cursor = "<leader>re",
  },
})
```

## Adapters

Built-in adapters:

| Adapter | Languages |
|---|---|
| `pcre` | PHP, JavaScript, TypeScript, Python, Go, Rust, Java, C, C++, Ruby, Perl, ... |
| `lua` | Lua `string.match`, `string.gsub`, `string.find` |
| `vim` | Vim `/search/`, `:s//`, `vim.regex()` |

### Writing a Custom Adapter

```lua
local my_adapter = {
  name = "myadapter",
  display_name = "My Regex Flavor",
  flavors = { "myflavor" },
}

-- Parse a pattern into an explanation tree
function my_adapter.parse(pattern, opts)
  -- Return a tree node:
  -- {
  --   type = "root",
  --   text = pattern,
  --   explanation = "My Regex Pattern",
  --   children = {
  --     { type = "literal", text = "a", explanation = "Matches 'a' literally", children = {} },
  --     { type = "char_class", text = "\\d", explanation = "Matches a digit", children = {} },
  --   },
  -- }
end

-- Match a pattern against text (optional)
function my_adapter.match(pattern, text, opts)
  -- Return { matches = { { start = 1, end_pos = 3, text = "abc", groups = {} } } }
end

-- Register it
require("regexplain.adapter.registry").register("myadapter", my_adapter)
```

## Development

```bash
# Run tests
make test

# Format code (requires stylua)
stylua lua/ plugin/ tests/
```

## License

MIT
