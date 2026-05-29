# qr.nvim

Pure Lua QR code generator for Neovim. No external dependencies — encodes text
as QR codes and displays them in floating windows, right in your editor.

## Features

- Pure Lua QR encoder (no shell-out, no `qrencode` binary needed)
- All 4 error correction levels (L, M, Q, H)
- Numeric, alphanumeric, and byte encoding modes (auto-detected)
- Versions 1-40 (auto-selected based on data length)
- Floating window display with backdrop
- Visual selection support
- Inverted color mode for dark terminals

## Installation

### lazy.nvim

```lua
{
  "taigrr/qr.nvim",
  opts = {},
  keys = {
    { "<leader>qr", mode = "v", desc = "Show QR code" },
  },
}
```

### packer.nvim

```lua
use {
  "taigrr/qr.nvim",
  config = function()
    require("qr").setup()
  end,
}
```

## Usage

### Visual Selection

1. Select text in visual mode
2. Press `<leader>qr`
3. QR code appears in a floating window
4. Press `q` or `<Esc>` to close

### Command

```vim
:QR https://example.com
```

### Lua API

```lua
local qr = require("qr")

-- Generate and show in floating window
qr.show("https://example.com")

-- Get rendered lines (for custom display)
local lines, info = qr.render("hello", { ec_level = 2 })
-- info = { version = 1, mask = 3, ec_level = 2, mode = 4 }

-- Get raw bitmap (for programmatic use)
local bm, version, mask = qr.generate("hello", { ec_level = 1 })
local pixel_table = require("qr.render").to_pixel_table(bm)
```

## Configuration

```lua
require("qr").setup({
  ec_level = 1,         -- Error correction: 1=L(7%), 2=M(15%), 3=Q(25%), 4=H(30%)
  quiet_zone = 4,       -- White border width in modules
  invert = false,       -- Invert colors (for dark backgrounds)
  keymap = "<leader>qr", -- Visual mode keymap (false to disable)
})
```

## Error Correction Levels

| Level | Recovery | Use Case |
|-------|----------|----------|
| L (1) | ~7% | Maximum data capacity, clean display |
| M (2) | ~15% | General purpose |
| Q (3) | ~25% | Moderate damage tolerance |
| H (4) | ~30% | High damage tolerance, smaller capacity |

## Architecture

```
lua/qr/
├── init.lua         -- Plugin setup, commands, API
├── galois.lua       -- GF(256) finite field arithmetic
├── reed_solomon.lua -- Reed-Solomon error correction
├── data.lua         -- QR spec tables (capacities, EC params, etc.)
├── encode.lua       -- Data encoding (mode selection, bit packing)
├── bitmap.lua       -- Efficient packed bitmap storage
├── matrix.lua       -- QR matrix construction (patterns, placement)
├── mask.lua         -- 8 mask patterns + penalty scoring
├── render.lua       -- Unicode half-block renderer
└── float.lua        -- Neovim floating window display
```

## Development

```bash
# Run tests (standalone luajit)
make test-pure

# Run tests (nvim headless)
make test

# Format
make format
```

## License

MIT
