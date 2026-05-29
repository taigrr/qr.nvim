---@brief [[
--- qr.nvim - Pure Lua QR code generator for Neovim.
--- Encodes text as QR codes and displays them in floating windows.
---
--- Usage:
---   require("qr").setup({})
---   -- Visual select text, then <leader>qr
---   -- Or: :QR https://example.com
---@brief ]]

local M = {}

---@class QrConfig
---@field ec_level? number Error correction level (1=L, 2=M, 3=Q, 4=H)
---@field quiet_zone? number Quiet zone width in modules (default 4)
---@field invert? boolean Invert colors for dark terminals (default false)
---@field keymap? string|false Visual mode keymap (default "<leader>qr", false to disable)

---@type QrConfig
M.config = {
  ec_level = 1,
  quiet_zone = 4,
  invert = false,
  keymap = "<leader>qr",
}

---Generate a QR code bitmap from text.
---@param text string
---@param opts? { ec_level?: number, mode?: number, version?: number }
---@return table QrBitmap
---@return number version
---@return number mask_pattern
function M.generate(text, opts)
  opts = opts or {}
  local qr_data = require("qr.data")
  local encode = require("qr.encode")
  local matrix = require("qr.matrix")

  local ec_level = opts.ec_level or M.config.ec_level
  local mode = opts.mode or qr_data.select_mode(text)
  local version = opts.version or qr_data.select_version(text, ec_level, mode)

  if not version then
    error("Text too long for QR encoding at EC level " .. ec_level)
  end

  local codewords = encode.encode(text, version, ec_level, mode)
  local bm, mask = matrix.build(codewords, version, ec_level)

  return bm, version, mask
end

---Generate and render a QR code as display lines.
---@param text string
---@param opts? { ec_level?: number, quiet_zone?: number, invert?: boolean }
---@return string[] lines
---@return { version: number, mask: number, ec_level: number, mode: number }
function M.render(text, opts)
  opts = opts or {}
  local qr_data = require("qr.data")
  local render = require("qr.render")

  local ec_level = opts.ec_level or M.config.ec_level
  local quiet_zone = opts.quiet_zone or M.config.quiet_zone
  local invert = opts.invert
  if invert == nil then
    invert = M.config.invert
  end

  local mode = qr_data.select_mode(text)
  local bm, version, mask = M.generate(text, { ec_level = ec_level })

  local lines
  if invert then
    lines = render.to_lines_inverted(bm, quiet_zone)
  else
    lines = render.to_lines(bm, quiet_zone)
  end

  return lines, { version = version, mask = mask, ec_level = ec_level, mode = mode }
end

---Show a QR code in a floating window.
---@param text string
---@param opts? { ec_level?: number, quiet_zone?: number, invert?: boolean, title?: string }
function M.show(text, opts)
  opts = opts or {}
  local float = require("qr.float")

  local lines = M.render(text, opts)
  local title = opts.title or text
  if #title > 40 then
    title = title:sub(1, 37) .. "..."
  end

  float.Float.open(lines, title)
end

---Get visual selection text. Must be called while still in visual mode.
---@return string
local function get_visual_selection()
  local mode = vim.fn.mode()
  if not mode:match("[vV\22]") then
    return ""
  end
  local region = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
  return table.concat(region, "\n")
end

---Get text from a line range using the marks set by a command range.
---@param line1 number 1-based start line
---@param line2 number 1-based end line
---@return string
local function get_range_text(line1, line2)
  local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  return table.concat(lines, "\n")
end

---@param opts? QrConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- User command. Accepts either an argument (:QR <text>) or a range
  -- (e.g. visual selection via :'<,'>QR, which uses the selected lines).
  vim.api.nvim_create_user_command("QR", function(cmd)
    local text = cmd.args
    if text == "" and cmd.range > 0 then
      text = get_range_text(cmd.line1, cmd.line2)
    end
    if text == "" then
      vim.notify("Usage: :QR <text>  (or select lines and run :QR)", vim.log.levels.WARN)
      return
    end
    M.show(text, { ec_level = M.config.ec_level })
  end, {
    desc = "Generate and display a QR code",
    nargs = "*",
    range = true,
  })

  -- Visual mode keymap
  if M.config.keymap then
    vim.keymap.set("x", M.config.keymap, function()
      -- Read selection while still in visual mode.
      local text = get_visual_selection()
      -- Leave visual mode, then open the float on the next tick so the
      -- pending <Esc> is consumed by the mode change instead of closing
      -- the freshly-opened float window.
      local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
      vim.api.nvim_feedkeys(esc, "n", false)

      vim.schedule(function()
        if text and text ~= "" then
          M.show(text, { ec_level = M.config.ec_level })
        else
          vim.notify("No text selected", vim.log.levels.WARN)
        end
      end)
    end, { desc = "Show QR code for selection" })
  end
end

return M
