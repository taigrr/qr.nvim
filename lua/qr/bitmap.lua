---@brief [[
--- Efficient bitmap storage for QR code matrix data.
--- Uses a flat integer array where each int stores 32 modules (bits).
--- Separates storage from display representation.
---@brief ]]

local M = {}
local bit = require("qr.bit")

---@class QrBitmap
---@field size number Width/height in modules
---@field _data number[] Packed 32-bit integers storing module values (1=dark, 0=light)
---@field _reserved number[] Packed 32-bit integers marking reserved/function pattern areas
local Bitmap = {}
Bitmap.__index = Bitmap

---Create a new bitmap of the given size.
---@param size number Width and height in modules
---@return QrBitmap
function Bitmap.new(size)
  local word_count = math.ceil(size * size / 32)
  local bm = setmetatable({
    size = size,
    _data = {},
    _reserved = {},
  }, Bitmap)
  for i = 1, word_count do
    bm._data[i] = 0
    bm._reserved[i] = 0
  end
  return bm
end

---Get the bit index (word index and bit offset) for coordinates.
---@param row number 0-based row
---@param col number 0-based column
---@return number word_idx, number bit_offset
local function coords_to_index(size, row, col)
  local linear = row * size + col
  local word_idx = math.floor(linear / 32) + 1
  local bit_offset = linear % 32
  return word_idx, bit_offset
end

---Set a module value.
---@param row number 0-based row
---@param col number 0-based column
---@param value number 0 or 1
function Bitmap:set(row, col, value)
  local word_idx, bit_offset = coords_to_index(self.size, row, col)
  if value == 1 then
    self._data[word_idx] = bit.bor(self._data[word_idx], bit.lshift(1, bit_offset))
  else
    self._data[word_idx] = bit.band(self._data[word_idx], bit.bnot(bit.lshift(1, bit_offset)))
  end
end

---Get a module value.
---@param row number 0-based row
---@param col number 0-based column
---@return number 0 or 1
function Bitmap:get(row, col)
  local word_idx, bit_offset = coords_to_index(self.size, row, col)
  return bit.band(bit.rshift(self._data[word_idx], bit_offset), 1)
end

---Mark a module as reserved (part of function patterns).
---@param row number 0-based row
---@param col number 0-based column
function Bitmap:reserve(row, col)
  local word_idx, bit_offset = coords_to_index(self.size, row, col)
  self._reserved[word_idx] = bit.bor(self._reserved[word_idx], bit.lshift(1, bit_offset))
end

---Check if a module is reserved.
---@param row number 0-based row
---@param col number 0-based column
---@return boolean
function Bitmap:is_reserved(row, col)
  local word_idx, bit_offset = coords_to_index(self.size, row, col)
  return bit.band(bit.rshift(self._reserved[word_idx], bit_offset), 1) == 1
end

---Set a module value and mark it as reserved.
---@param row number 0-based row
---@param col number 0-based column
---@param value number 0 or 1
function Bitmap:set_reserved(row, col, value)
  self:set(row, col, value)
  self:reserve(row, col)
end

---Toggle (XOR) a module value. Only affects unreserved modules.
---@param row number 0-based row
---@param col number 0-based column
function Bitmap:toggle(row, col)
  if not self:is_reserved(row, col) then
    local word_idx, bit_offset = coords_to_index(self.size, row, col)
    self._data[word_idx] = bit.bxor(self._data[word_idx], bit.lshift(1, bit_offset))
  end
end

---Create a deep copy of this bitmap.
---@return QrBitmap
function Bitmap:clone()
  local copy = setmetatable({
    size = self.size,
    _data = {},
    _reserved = {},
  }, Bitmap)
  for i = 1, #self._data do
    copy._data[i] = self._data[i]
    copy._reserved[i] = self._reserved[i]
  end
  return copy
end

---Convert to a 2D table for display/testing (row-major, 0-indexed internally).
---Returns 1-indexed table of rows, each row a 1-indexed table of 0/1 values.
---@return number[][]
function Bitmap:to_table()
  local result = {}
  for row = 0, self.size - 1 do
    local r = {}
    for col = 0, self.size - 1 do
      r[col + 1] = self:get(row, col)
    end
    result[row + 1] = r
  end
  return result
end

---Check if coordinates are within bounds.
---@param row number
---@param col number
---@return boolean
function Bitmap:in_bounds(row, col)
  return row >= 0 and row < self.size and col >= 0 and col < self.size
end

M.Bitmap = Bitmap

return M
