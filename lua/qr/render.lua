---@brief [[
--- QR code renderer: converts a QrBitmap into displayable text lines.
--- Uses Unicode half-block characters to fit 2 rows per terminal line.
--- Also supports a "pixel table" output for programmatic use.
---@brief ]]

local M = {}

-- Unicode block characters for 2-row-per-line rendering:
-- Each terminal character encodes a top half and bottom half pixel.
-- ▀ (U+2580) = top dark, bottom light
-- ▄ (U+2584) = top light, bottom dark
-- █ (U+2588) = both dark
-- " " (space) = both light
local CHAR_BOTH_DARK = "█"
local CHAR_TOP_DARK = "▀"
local CHAR_BOTTOM_DARK = "▄"
local CHAR_BOTH_LIGHT = " "

---Render a QrBitmap to an array of strings using Unicode half-blocks.
---Includes a quiet zone (4 modules wide) around the code.
---@param bm table QrBitmap
---@param quiet_zone? number Quiet zone width in modules (default 4)
---@return string[] Array of display lines
function M.to_lines(bm, quiet_zone)
  quiet_zone = quiet_zone or 4
  local size = bm.size
  local total = size + quiet_zone * 2
  local lines = {}

  -- Process 2 rows at a time
  for y = 0, total - 1, 2 do
    local line = {}
    for x = 0, total - 1 do
      local top_row = y - quiet_zone
      local bot_row = y + 1 - quiet_zone
      local col = x - quiet_zone

      local top_dark = false
      local bot_dark = false

      if top_row >= 0 and top_row < size and col >= 0 and col < size then
        top_dark = bm:get(top_row, col) == 1
      end
      if bot_row >= 0 and bot_row < size and col >= 0 and col < size then
        bot_dark = bm:get(bot_row, col) == 1
      end

      if top_dark and bot_dark then
        line[#line + 1] = CHAR_BOTH_DARK
      elseif top_dark then
        line[#line + 1] = CHAR_TOP_DARK
      elseif bot_dark then
        line[#line + 1] = CHAR_BOTTOM_DARK
      else
        line[#line + 1] = CHAR_BOTH_LIGHT
      end
    end
    lines[#lines + 1] = table.concat(line)
  end

  return lines
end

---Render with inverted colors (light-on-dark terminal).
---@param bm table QrBitmap
---@param quiet_zone? number
---@return string[]
function M.to_lines_inverted(bm, quiet_zone)
  quiet_zone = quiet_zone or 4
  local size = bm.size
  local total = size + quiet_zone * 2
  local lines = {}

  for y = 0, total - 1, 2 do
    local line = {}
    for x = 0, total - 1 do
      local top_row = y - quiet_zone
      local bot_row = y + 1 - quiet_zone
      local col = x - quiet_zone

      -- Inverted: QR "dark" → display light, QR "light" → display dark
      -- Quiet zone (outside QR) is QR-light → display dark in inverted mode
      local top_qr_light = true
      local bot_qr_light = true

      if top_row >= 0 and top_row < size and col >= 0 and col < size then
        top_qr_light = bm:get(top_row, col) == 0
      end
      if bot_row >= 0 and bot_row < size and col >= 0 and col < size then
        bot_qr_light = bm:get(bot_row, col) == 0
      end

      -- In inverted display: QR-light → display dark, QR-dark → display light
      local top_display_dark = top_qr_light
      local bot_display_dark = bot_qr_light

      if top_display_dark and bot_display_dark then
        line[#line + 1] = CHAR_BOTH_DARK
      elseif top_display_dark then
        line[#line + 1] = CHAR_TOP_DARK
      elseif bot_display_dark then
        line[#line + 1] = CHAR_BOTTOM_DARK
      else
        line[#line + 1] = CHAR_BOTH_LIGHT
      end
    end
    lines[#lines + 1] = table.concat(line)
  end

  return lines
end

---Convert bitmap to a flat pixel table for programmatic access.
---Returns a table with { width, height, pixels } where pixels[row][col] = 0 or 1.
---@param bm table QrBitmap
---@param quiet_zone? number
---@return { width: number, height: number, pixels: number[][] }
function M.to_pixel_table(bm, quiet_zone)
  quiet_zone = quiet_zone or 4
  local size = bm.size
  local total = size + quiet_zone * 2

  local pixels = {}
  for y = 0, total - 1 do
    local row = {}
    for x = 0, total - 1 do
      local qr_row = y - quiet_zone
      local qr_col = x - quiet_zone
      if qr_row >= 0 and qr_row < size and qr_col >= 0 and qr_col < size then
        row[x + 1] = bm:get(qr_row, qr_col)
      else
        row[x + 1] = 0
      end
    end
    pixels[y + 1] = row
  end

  return { width = total, height = total, pixels = pixels }
end

return M
