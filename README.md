# qr.nvim

Pure Lua QR code generation for Neovim.

Turn text into a QR code without shelling out to `qrencode` or depending on an external binary. It handles the encoding, error correction, masking, and rendering inside Neovim, then shows the result in a floating window.

## What it does

- Pure Lua QR encoder
- No external runtime dependency
- Auto-detects numeric, alphanumeric, and byte modes
- Supports error correction levels L, M, Q, and H
- Auto-selects QR versions 1-40 based on payload size
- Renders directly in Neovim with Unicode blocks
- Works on visual selections, command input, or Lua calls

## What could still be better

- Kanji mode exists in the encoder but the public mode selection path does not currently expose real Shift-JIS handling, so non-ASCII text effectively goes through byte mode
- Rendering is terminal-first; there is no image export or SVG output
- Scan reliability in inverted mode depends a lot on terminal/theme contrast

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "taigrr/qr.nvim",
  opts = {},
  keys = {
    { "<leader>qr", mode = "v", desc = "Show QR code" },
  },
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "taigrr/qr.nvim",
  config = function()
    require("qr").setup()
  end,
}
```

## Requirements

- Neovim >= 0.9.0
- A terminal/font setup that can render Unicode block characters correctly

## Usage

### Visual selection

1. Select text in visual mode
2. Press `<leader>qr`
3. The QR code opens in a floating window
4. Press `q` or `<Esc>` to close it

### Command

```vim
:QR https://example.com
```

You can also use it on a visual range with `:'<,'>QR`.

### Lua API

```lua
local qr = require("qr")

-- Show a QR code in a floating window
qr.show("https://example.com")

-- Render lines for your own UI
local lines, info = qr.render("hello", { ec_level = 2 })
-- info = { version = 1, mask = 3, ec_level = 2, mode = 4 }

-- Get the raw bitmap
local bm, version, mask = qr.generate("hello", { ec_level = 1 })

-- Convert to a pixel table
local pixel_table = require("qr.render").to_pixel_table(bm)
```

## Commands

| Command | Description |
| --- | --- |
| `:QR <text>` | Generate and show a QR code for the given text |
| `:'<,'>QR` | Generate a QR code from the selected line range |

## Configuration

```lua
require("qr").setup({
  ec_level = 1,          -- 1=L, 2=M, 3=Q, 4=H
  quiet_zone = 4,        -- Border width in modules
  invert = false,        -- Invert colors for dark backgrounds
  keymap = "<leader>qr",  -- Visual-mode keymap, or false to disable
  max_title_length = 40,   -- Truncate long floating titles
})
```

## Error correction levels

| Level | Recovery | Use case |
| --- | --- | --- |
| L (1) | ~7% | Maximum capacity |
| M (2) | ~15% | General use |
| Q (3) | ~25% | More damage tolerance |
| H (4) | ~30% | Highest resilience, lowest capacity |

## Limitations and notes

- Public auto-mode selection currently chooses numeric, alphanumeric, or byte mode. Kanji support exists internally, but there is not yet a real user-facing Shift-JIS path.
- Floating window rendering assumes a terminal that displays Unicode half-blocks consistently.
- Very long titles are truncated in the floating window; `max_title_length` lets you tune that.
- Empty strings currently encode successfully; that is allowed by the plugin, even if it may not be useful in practice.

## Implementation notes

The project is split into small modules instead of one giant encoder file:

```text
lua/qr/
├── init.lua         -- Setup, commands, public API
├── data.lua         -- QR spec tables and capacity logic
├── encode.lua       -- Mode encoding and codeword generation
├── galois.lua       -- GF(256) arithmetic
├── reed_solomon.lua -- Error correction generation
├── bitmap.lua       -- Packed bitmap storage
├── matrix.lua       -- Matrix construction and data placement
├── mask.lua         -- Mask patterns and penalty scoring
├── render.lua       -- Unicode renderer
└── float.lua        -- Floating window display
```

## Development

```bash
# Run tests
make test

# Format
make format

# Lint
make lint
```

## License

[0BSD](LICENSE) © Tai Groot
