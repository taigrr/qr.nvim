---@brief [[
--- QR code matrix construction.
--- Places all function patterns, data modules, format/version info, and applies masking.
--- This is the main orchestrator that produces a final QrBitmap.
---@brief ]]

local bitmap_mod = require("qr.bitmap")
local data = require("qr.data")
local mask_mod = require("qr.mask")

local M = {}

---Place a finder pattern (7x7) with top-left at (row, col).
---@param bm table QrBitmap
---@param row number 0-based top-left row
---@param col number 0-based top-left column
function M.place_finder(bm, row, col)
  for r = 0, 6 do
    for c = 0, 6 do
      local dark
      if r == 0 or r == 6 or c == 0 or c == 6 then
        dark = 1
      elseif r >= 2 and r <= 4 and c >= 2 and c <= 4 then
        dark = 1
      else
        dark = 0
      end
      bm:set_reserved(row + r, col + c, dark)
    end
  end
end

---Place separator (1-module white border) around finder patterns.
---@param bm table QrBitmap
---@param size number Module size
function M.place_separators(bm, size)
  -- Top-left finder: right edge and bottom edge separators
  for i = 0, 7 do
    if bm:in_bounds(i, 7) then
      bm:set_reserved(i, 7, 0)
    end
    if bm:in_bounds(7, i) then
      bm:set_reserved(7, i, 0)
    end
  end

  -- Top-right finder: left edge and bottom edge separators
  for i = 0, 7 do
    if bm:in_bounds(i, size - 8) then
      bm:set_reserved(i, size - 8, 0)
    end
    if bm:in_bounds(7, size - 8 + i) then
      bm:set_reserved(7, size - 8 + i, 0)
    end
  end

  -- Bottom-left finder: right edge and top edge separators
  for i = 0, 7 do
    if bm:in_bounds(size - 8, i) then
      bm:set_reserved(size - 8, i, 0)
    end
    if bm:in_bounds(size - 8 + i, 7) then
      bm:set_reserved(size - 8 + i, 7, 0)
    end
  end
end

---Place an alignment pattern (5x5) centered at (row, col).
---@param bm table QrBitmap
---@param center_row number
---@param center_col number
function M.place_alignment(bm, center_row, center_col)
  for r = -2, 2 do
    for c = -2, 2 do
      local dark
      if r == -2 or r == 2 or c == -2 or c == 2 or (r == 0 and c == 0) then
        dark = 1
      else
        dark = 0
      end
      bm:set_reserved(center_row + r, center_col + c, dark)
    end
  end
end

---Place all alignment patterns for a version, skipping those that overlap finders.
---@param bm table QrBitmap
---@param version number
function M.place_all_alignments(bm, version)
  local positions = data.ALIGNMENT_POSITIONS[version]
  if not positions then
    return
  end

  for _, row in ipairs(positions) do
    for _, col in ipairs(positions) do
      -- Skip if overlapping with finder patterns
      if not bm:is_reserved(row, col) then
        M.place_alignment(bm, row, col)
      end
    end
  end
end

---Place timing patterns (alternating dark/light between finders).
---@param bm table QrBitmap
---@param size number
function M.place_timing(bm, size)
  for i = 8, size - 9 do
    local val = (i % 2 == 0) and 1 or 0
    -- Horizontal timing (row 6)
    if not bm:is_reserved(6, i) then
      bm:set_reserved(6, i, val)
    end
    -- Vertical timing (col 6)
    if not bm:is_reserved(i, 6) then
      bm:set_reserved(i, 6, val)
    end
  end
end

---Place the dark module (always dark, at position (4*version + 9, 8)).
---@param bm table QrBitmap
---@param version number
function M.place_dark_module(bm, version)
  bm:set_reserved(4 * version + 9, 8, 1)
end

---Reserve format information areas (don't write values yet).
---@param bm table QrBitmap
---@param size number
function M.reserve_format_areas(bm, size)
  -- Around top-left finder
  for i = 0, 8 do
    if not bm:is_reserved(8, i) then
      bm:reserve(8, i)
    end
    if not bm:is_reserved(i, 8) then
      bm:reserve(i, 8)
    end
  end
  -- Around top-right finder
  for i = 0, 7 do
    if not bm:is_reserved(8, size - 1 - i) then
      bm:reserve(8, size - 1 - i)
    end
  end
  -- Around bottom-left finder
  for i = 0, 6 do
    if not bm:is_reserved(size - 1 - i, 8) then
      bm:reserve(size - 1 - i, 8)
    end
  end
end

---Reserve version information areas (versions 7+).
---@param bm table QrBitmap
---@param version number
---@param size number
function M.reserve_version_areas(bm, version, size)
  if version < 7 then
    return
  end
  -- Bottom-left area (6x3)
  for i = 0, 5 do
    for j = 0, 2 do
      bm:reserve(size - 11 + j, i)
    end
  end
  -- Top-right area (3x6)
  for i = 0, 5 do
    for j = 0, 2 do
      bm:reserve(i, size - 11 + j)
    end
  end
end

---Write format information bits to the bitmap.
---@param bm table QrBitmap
---@param ec_level number
---@param mask_pattern number
function M.place_format_info(bm, ec_level, mask_pattern)
  local format_bits = data.FORMAT_INFO[ec_level][mask_pattern + 1]
  local size = bm.size

  -- Place around top-left finder (split into two segments)
  -- Bits 0-7 go along the left edge of top-left (column 8, rows 0-8 skipping row 6)
  -- Bits 8-14 go along the top edge of top-left (row 8, columns 0-7 skipping col 6)
  local positions_vertical = { { 0, 8 }, { 1, 8 }, { 2, 8 }, { 3, 8 }, { 4, 8 }, { 5, 8 }, { 7, 8 }, { 8, 8 } }
  local positions_horizontal = { { 8, 7 }, { 8, 5 }, { 8, 4 }, { 8, 3 }, { 8, 2 }, { 8, 1 }, { 8, 0 } }

  -- Write bits 14 down to 8 vertically (MSB first)
  for i = 1, 8 do
    local b = bit.band(bit.rshift(format_bits, 14 - (i - 1)), 1)
    local pos = positions_vertical[i]
    bm:set(pos[1], pos[2], b)
  end

  -- Write bits 6 down to 0 horizontally
  for i = 1, 7 do
    local b = bit.band(bit.rshift(format_bits, 6 - (i - 1)), 1)
    local pos = positions_horizontal[i]
    bm:set(pos[1], pos[2], b)
  end

  -- Place along top-right (row 8, columns size-1 to size-8)
  for i = 0, 7 do
    local b = bit.band(bit.rshift(format_bits, i), 1)
    bm:set(8, size - 1 - i, b)
  end

  -- Place along bottom-left (column 8, rows size-1 to size-7)
  for i = 0, 6 do
    local b = bit.band(bit.rshift(format_bits, 14 - i), 1)
    bm:set(size - 1 - i, 8, b)
  end
end

---Write version information bits (versions 7+).
---@param bm table QrBitmap
---@param version number
function M.place_version_info(bm, version)
  if version < 7 then
    return
  end
  local size = bm.size
  local version_bits = data.VERSION_INFO[version]

  for i = 0, 17 do
    local b = bit.band(bit.rshift(version_bits, i), 1)
    local row = math.floor(i / 3)
    local col = i % 3
    -- Bottom-left block
    bm:set(size - 11 + col, row, b)
    -- Top-right block
    bm:set(row, size - 11 + col, b)
  end
end

---Place data codewords into the matrix following the QR placement order.
---Traverses in 2-column strips from right to left, bottom to top, alternating.
---@param bm table QrBitmap
---@param codewords number[] Interleaved data + EC codewords
---@param version number
function M.place_data(bm, codewords, version)
  local size = bm.size
  local bit_idx = 0
  local total_bits = #codewords * 8 + data.REMAINDER_BITS[version]

  -- Build a flat bit array from codewords + remainder
  local bits = {}
  for _, cw in ipairs(codewords) do
    for j = 7, 0, -1 do
      bits[#bits + 1] = bit.band(bit.rshift(cw, j), 1)
    end
  end
  -- Add remainder bits
  for _ = 1, data.REMAINDER_BITS[version] do
    bits[#bits + 1] = 0
  end

  -- Traverse in 2-column strips, right to left
  local col = size - 1
  while col >= 0 do
    -- Skip timing pattern column
    if col == 6 then
      col = col - 1
    end

    -- Determine direction: upward for even strip index, downward for odd
    local col_pair_index = math.floor((size - 1 - col) / 2)
    if col <= 6 then
      col_pair_index = math.floor((size - 2 - col) / 2)
    end
    local going_up = (col_pair_index % 2 == 0)

    local row_start, row_end, row_step
    if going_up then
      row_start, row_end, row_step = size - 1, 0, -1
    else
      row_start, row_end, row_step = 0, size - 1, 1
    end

    local row = row_start
    while true do
      -- Right column of the pair
      if not bm:is_reserved(row, col) then
        bit_idx = bit_idx + 1
        if bit_idx <= total_bits then
          bm:set(row, col, bits[bit_idx])
        end
      end
      -- Left column of the pair
      if col - 1 >= 0 and not bm:is_reserved(row, col - 1) then
        bit_idx = bit_idx + 1
        if bit_idx <= total_bits then
          bm:set(row, col - 1, bits[bit_idx])
        end
      end

      if row == row_end then
        break
      end
      row = row + row_step
    end

    col = col - 2
  end
end

---Build a complete QR code matrix.
---@param codewords number[] Interleaved data + EC codewords
---@param version number
---@param ec_level number
---@param mask_pattern? number Force a specific mask (0-7), or nil for auto-select
---@return table QrBitmap The final QR code bitmap
---@return number The mask pattern used
function M.build(codewords, version, ec_level, mask_pattern)
  local size = data.size(version)
  local bm = bitmap_mod.Bitmap.new(size)

  -- 1. Place function patterns
  M.place_finder(bm, 0, 0) -- Top-left
  M.place_finder(bm, 0, size - 7) -- Top-right
  M.place_finder(bm, size - 7, 0) -- Bottom-left
  M.place_separators(bm, size)
  M.place_all_alignments(bm, version)
  M.place_timing(bm, size)
  M.place_dark_module(bm, version)

  -- 2. Reserve format and version areas
  M.reserve_format_areas(bm, size)
  M.reserve_version_areas(bm, version, size)

  -- 3. Place data
  M.place_data(bm, codewords, version)

  -- 4. Apply mask and write format/version info
  local place_fmt = function(candidate, mask)
    M.place_format_info(candidate, ec_level, mask)
    M.place_version_info(candidate, version)
  end

  local final_mask, final_bm
  if mask_pattern then
    final_bm = bm:clone()
    mask_mod.apply(final_bm, mask_pattern)
    place_fmt(final_bm, mask_pattern)
    final_mask = mask_pattern
  else
    final_mask, final_bm = mask_mod.select_best(bm, place_fmt)
  end

  return final_bm, final_mask
end

return M
