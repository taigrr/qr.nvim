---@brief [[
--- QR data encoding: converts text into a bit stream and then codewords.
--- Supports numeric, alphanumeric, byte, and kanji encoding modes.
---@brief ]]

local data = require("qr.data")
local reed_solomon = require("qr.reed_solomon")

local M = {}

---@class QrBitBuffer
---@field bits number[] Array of 0/1 bits
---@field length number Total bit count
local BitBuffer = {}
BitBuffer.__index = BitBuffer

---Create a new bit buffer.
---@return QrBitBuffer
function BitBuffer.new()
  return setmetatable({ bits = {}, length = 0 }, BitBuffer)
end

---Append a value as a fixed number of bits (MSB first).
---@param value number
---@param num_bits number
function BitBuffer:put(value, num_bits)
  for i = num_bits - 1, 0, -1 do
    local b = bit.band(bit.rshift(value, i), 1)
    self.length = self.length + 1
    self.bits[self.length] = b
  end
end

---Append a single bit.
---@param b number 0 or 1
function BitBuffer:put_bit(b)
  self.length = self.length + 1
  self.bits[self.length] = b
end

M.BitBuffer = BitBuffer

---Encode data in numeric mode into the bit buffer.
---@param buf QrBitBuffer
---@param text string Digit-only string
function M.encode_numeric(buf, text)
  local i = 1
  while i <= #text do
    local remaining = #text - i + 1
    if remaining >= 3 then
      local group = tonumber(text:sub(i, i + 2))
      buf:put(group, 10)
      i = i + 3
    elseif remaining == 2 then
      local group = tonumber(text:sub(i, i + 1))
      buf:put(group, 7)
      i = i + 2
    else
      local group = tonumber(text:sub(i, i))
      buf:put(group, 4)
      i = i + 1
    end
  end
end

---Encode data in alphanumeric mode into the bit buffer.
---@param buf QrBitBuffer
---@param text string
function M.encode_alphanumeric(buf, text)
  local i = 1
  while i <= #text do
    if i + 1 <= #text then
      local v1 = data.ALPHANUM_MAP[text:sub(i, i)]
      local v2 = data.ALPHANUM_MAP[text:sub(i + 1, i + 1)]
      buf:put(v1 * 45 + v2, 11)
      i = i + 2
    else
      local v1 = data.ALPHANUM_MAP[text:sub(i, i)]
      buf:put(v1, 6)
      i = i + 1
    end
  end
end

---Encode data in byte mode into the bit buffer.
---@param buf QrBitBuffer
---@param text string
function M.encode_byte(buf, text)
  for i = 1, #text do
    buf:put(text:byte(i), 8)
  end
end

---Encode data in kanji mode into the bit buffer.
---@param buf QrBitBuffer
---@param text string Shift-JIS encoded bytes (2 bytes per character)
function M.encode_kanji(buf, text)
  local i = 1
  while i + 1 <= #text do
    local hi = text:byte(i)
    local lo = text:byte(i + 1)
    local code = hi * 256 + lo
    if code >= 0x8140 and code <= 0x9FFC then
      code = code - 0x8140
    elseif code >= 0xE040 and code <= 0xEBBF then
      code = code - 0xC140
    end
    local value = (math.floor(code / 256)) * 0xC0 + (code % 256)
    buf:put(value, 13)
    i = i + 2
  end
end

---Build the complete data codeword sequence (data + EC, interleaved).
---@param text string Input text to encode
---@param version number QR version (1-40)
---@param ec_level number Error correction level (1-4)
---@param mode number Encoding mode
---@return number[] Final codeword sequence (data + EC interleaved)
function M.encode(text, version, ec_level, mode)
  local buf = BitBuffer.new()
  local vg = data.version_group(version)
  local cc_bits = data.CHAR_COUNT_BITS[mode][vg]

  -- Mode indicator (4 bits)
  buf:put(data.MODE_INDICATOR[mode], 4)

  -- Character count indicator
  local char_count = #text
  if mode == data.MODE.KANJI then
    char_count = math.floor(#text / 2)
  end
  buf:put(char_count, cc_bits)

  -- Data encoding
  if mode == data.MODE.NUMERIC then
    M.encode_numeric(buf, text)
  elseif mode == data.MODE.ALPHANUMERIC then
    M.encode_alphanumeric(buf, text)
  elseif mode == data.MODE.BYTE then
    M.encode_byte(buf, text)
  elseif mode == data.MODE.KANJI then
    M.encode_kanji(buf, text)
  end

  -- Terminator: up to 4 zero bits
  local total_data_codewords = data.data_capacity(version, ec_level)
  local total_data_bits = total_data_codewords * 8
  local terminator_len = math.min(4, total_data_bits - buf.length)
  buf:put(0, terminator_len)

  -- Pad to byte boundary
  while buf.length % 8 ~= 0 do
    buf:put_bit(0)
  end

  -- Pad with alternating bytes 0xEC, 0x11
  local pad_bytes = { 0xEC, 0x11 }
  local pad_idx = 1
  while buf.length < total_data_bits do
    buf:put(pad_bytes[pad_idx], 8)
    pad_idx = pad_idx == 1 and 2 or 1
  end

  -- Convert bit buffer to codewords
  local codewords = {}
  for i = 1, buf.length, 8 do
    local byte = 0
    for j = 0, 7 do
      if buf.bits[i + j] == 1 then
        byte = byte + bit.lshift(1, 7 - j)
      end
    end
    codewords[#codewords + 1] = byte
  end

  -- Split into blocks and compute EC for each block
  return M.interleave(codewords, version, ec_level)
end

---Split data into blocks, compute EC, and interleave.
---@param codewords number[]
---@param version number
---@param ec_level number
---@return number[]
function M.interleave(codewords, version, ec_level)
  local ec_info = data.EC_TABLE[version][ec_level]
  local ec_per_block = ec_info.ec_per_block

  -- Split data into blocks
  local data_blocks = {}
  local ec_blocks = {}
  local cw_idx = 1

  for _, block_group in ipairs(ec_info.blocks) do
    local count = block_group[1]
    local data_per_block = block_group[2]
    for _ = 1, count do
      local block = {}
      for j = 1, data_per_block do
        block[j] = codewords[cw_idx]
        cw_idx = cw_idx + 1
      end
      data_blocks[#data_blocks + 1] = block
      ec_blocks[#ec_blocks + 1] = reed_solomon.encode(block, ec_per_block)
    end
  end

  -- Interleave data blocks
  local result = {}
  local max_data_len = 0
  for _, block in ipairs(data_blocks) do
    if #block > max_data_len then
      max_data_len = #block
    end
  end

  for i = 1, max_data_len do
    for _, block in ipairs(data_blocks) do
      if block[i] then
        result[#result + 1] = block[i]
      end
    end
  end

  -- Interleave EC blocks
  for i = 1, ec_per_block do
    for _, block in ipairs(ec_blocks) do
      if block[i] then
        result[#result + 1] = block[i]
      end
    end
  end

  return result
end

return M
