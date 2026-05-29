---@brief [[
--- QR code specification data tables.
--- Contains capacities, EC codeword counts, alignment pattern positions,
--- and all version/level-dependent parameters from ISO 18004.
---@brief ]]

local M = {}

---@enum QrMode
M.MODE = {
  NUMERIC = 1,
  ALPHANUMERIC = 2,
  BYTE = 4,
  KANJI = 8,
}

---@enum QrEcLevel
M.EC_LEVEL = {
  L = 1, -- ~7% recovery
  M = 2, -- ~15% recovery
  Q = 3, -- ~25% recovery
  H = 4, -- ~30% recovery
}

--- Mode indicator bits (4-bit field in data stream)
M.MODE_INDICATOR = {
  [M.MODE.NUMERIC] = 0x1,
  [M.MODE.ALPHANUMERIC] = 0x2,
  [M.MODE.BYTE] = 0x4,
  [M.MODE.KANJI] = 0x8,
}

--- Character count indicator bit lengths per mode per version group.
--- Index: [mode][version_group] where version_group = 1 (1-9), 2 (10-26), 3 (27-40)
M.CHAR_COUNT_BITS = {
  [M.MODE.NUMERIC] = { 10, 12, 14 },
  [M.MODE.ALPHANUMERIC] = { 9, 11, 13 },
  [M.MODE.BYTE] = { 8, 16, 16 },
  [M.MODE.KANJI] = { 8, 10, 12 },
}

---Get the version group index for character count indicator.
---@param version number QR version (1-40)
---@return number 1, 2, or 3
function M.version_group(version)
  if version <= 9 then
    return 1
  elseif version <= 26 then
    return 2
  else
    return 3
  end
end

--- Total number of codewords (data + EC) for each version.
--- Index: version (1-40)
M.TOTAL_CODEWORDS = {
  26, 44, 70, 100, 134, 172, 196, 242, 292, 346,
  404, 466, 532, 581, 655, 733, 815, 901, 991, 1085,
  1156, 1258, 1364, 1474, 1588, 1706, 1828, 1921, 2051, 2185,
  2323, 2465, 2611, 2761, 2876, 3034, 3196, 3362, 3532, 3706,
}

--- Error correction codewords per block, indexed [version][ec_level]
--- Each entry is: { num_ec_codewords_per_block, { {num_blocks, data_codewords_per_block}, ... } }
---@type table<number, table<number, {ec_per_block: number, blocks: number[][]}>>
M.EC_TABLE = {}

-- Populate EC table from the spec.
-- Format: { ec_codewords_per_block, { {count, data_codewords}, ... } }
local function ec(ec_per_block, ...)
  local blocks = { ... }
  return { ec_per_block = ec_per_block, blocks = blocks }
end

-- Version 1-40, each level L/M/Q/H
M.EC_TABLE[1] = {
  ec(7, { 1, 19 }),
  ec(10, { 1, 16 }),
  ec(13, { 1, 13 }),
  ec(17, { 1, 9 }),
}
M.EC_TABLE[2] = {
  ec(10, { 1, 34 }),
  ec(16, { 1, 28 }),
  ec(22, { 1, 22 }),
  ec(28, { 1, 16 }),
}
M.EC_TABLE[3] = {
  ec(15, { 1, 55 }),
  ec(26, { 1, 44 }),
  ec(18, { 2, 17 }),
  ec(22, { 2, 13 }),
}
M.EC_TABLE[4] = {
  ec(20, { 1, 80 }),
  ec(18, { 2, 32 }),
  ec(26, { 2, 24 }),
  ec(16, { 4, 9 }),
}
M.EC_TABLE[5] = {
  ec(26, { 1, 108 }),
  ec(24, { 2, 43 }),
  ec(18, { 2, 15 }, { 2, 16 }),
  ec(22, { 2, 11 }, { 2, 12 }),
}
M.EC_TABLE[6] = {
  ec(18, { 2, 68 }),
  ec(16, { 4, 27 }),
  ec(24, { 4, 19 }),
  ec(28, { 4, 15 }),
}
M.EC_TABLE[7] = {
  ec(20, { 2, 78 }),
  ec(18, { 4, 31 }),
  ec(18, { 2, 14 }, { 4, 15 }),
  ec(26, { 4, 13 }, { 1, 14 }),
}
M.EC_TABLE[8] = {
  ec(24, { 2, 97 }),
  ec(22, { 2, 38 }, { 2, 39 }),
  ec(22, { 4, 18 }, { 2, 19 }),
  ec(26, { 4, 14 }, { 2, 15 }),
}
M.EC_TABLE[9] = {
  ec(30, { 2, 116 }),
  ec(22, { 3, 36 }, { 2, 37 }),
  ec(20, { 4, 16 }, { 4, 17 }),
  ec(24, { 4, 12 }, { 4, 13 }),
}
M.EC_TABLE[10] = {
  ec(18, { 2, 68 }, { 2, 69 }),
  ec(26, { 4, 43 }, { 1, 44 }),
  ec(24, { 6, 19 }, { 2, 20 }),
  ec(28, { 6, 15 }, { 2, 16 }),
}
M.EC_TABLE[11] = {
  ec(20, { 4, 81 }),
  ec(30, { 1, 50 }, { 4, 51 }),
  ec(28, { 4, 22 }, { 4, 23 }),
  ec(24, { 3, 12 }, { 8, 13 }),
}
M.EC_TABLE[12] = {
  ec(24, { 2, 92 }, { 2, 93 }),
  ec(22, { 6, 36 }, { 2, 37 }),
  ec(26, { 4, 20 }, { 6, 21 }),
  ec(28, { 7, 14 }, { 4, 15 }),
}
M.EC_TABLE[13] = {
  ec(26, { 4, 107 }),
  ec(22, { 8, 37 }, { 1, 38 }),
  ec(24, { 8, 20 }, { 4, 21 }),
  ec(22, { 12, 11 }, { 4, 12 }),
}
M.EC_TABLE[14] = {
  ec(30, { 3, 115 }, { 1, 116 }),
  ec(24, { 4, 40 }, { 5, 41 }),
  ec(20, { 11, 16 }, { 5, 17 }),
  ec(24, { 11, 12 }, { 5, 13 }),
}
M.EC_TABLE[15] = {
  ec(22, { 5, 87 }, { 1, 88 }),
  ec(24, { 5, 41 }, { 5, 42 }),
  ec(30, { 5, 24 }, { 7, 25 }),
  ec(24, { 11, 12 }, { 7, 13 }),
}
M.EC_TABLE[16] = {
  ec(24, { 5, 98 }, { 1, 99 }),
  ec(28, { 7, 45 }, { 3, 46 }),
  ec(24, { 15, 19 }, { 2, 20 }),
  ec(30, { 3, 15 }, { 13, 16 }),
}
M.EC_TABLE[17] = {
  ec(28, { 1, 107 }, { 5, 108 }),
  ec(28, { 10, 46 }, { 1, 47 }),
  ec(28, { 1, 22 }, { 15, 23 }),
  ec(28, { 2, 14 }, { 17, 15 }),
}
M.EC_TABLE[18] = {
  ec(30, { 5, 120 }, { 1, 121 }),
  ec(26, { 9, 43 }, { 4, 44 }),
  ec(28, { 17, 22 }, { 1, 23 }),
  ec(28, { 2, 14 }, { 19, 15 }),
}
M.EC_TABLE[19] = {
  ec(28, { 3, 113 }, { 4, 114 }),
  ec(26, { 3, 44 }, { 11, 45 }),
  ec(26, { 17, 21 }, { 4, 22 }),
  ec(26, { 9, 13 }, { 16, 14 }),
}
M.EC_TABLE[20] = {
  ec(28, { 3, 107 }, { 5, 108 }),
  ec(26, { 3, 41 }, { 13, 42 }),
  ec(30, { 15, 24 }, { 5, 25 }),
  ec(28, { 15, 15 }, { 10, 16 }),
}
M.EC_TABLE[21] = {
  ec(28, { 4, 116 }, { 4, 117 }),
  ec(26, { 17, 42 }),
  ec(28, { 17, 22 }, { 6, 23 }),
  ec(30, { 19, 16 }, { 6, 17 }),
}
M.EC_TABLE[22] = {
  ec(28, { 2, 111 }, { 7, 112 }),
  ec(28, { 17, 46 }),
  ec(30, { 7, 24 }, { 16, 25 }),
  ec(24, { 34, 13 }),
}
M.EC_TABLE[23] = {
  ec(30, { 4, 121 }, { 5, 122 }),
  ec(28, { 4, 47 }, { 14, 48 }),
  ec(30, { 11, 24 }, { 14, 25 }),
  ec(30, { 16, 15 }, { 14, 16 }),
}
M.EC_TABLE[24] = {
  ec(30, { 6, 117 }, { 4, 118 }),
  ec(28, { 6, 45 }, { 14, 46 }),
  ec(30, { 11, 24 }, { 16, 25 }),
  ec(30, { 30, 16 }, { 2, 17 }),
}
M.EC_TABLE[25] = {
  ec(26, { 8, 106 }, { 4, 107 }),
  ec(28, { 8, 47 }, { 13, 48 }),
  ec(30, { 7, 24 }, { 22, 25 }),
  ec(30, { 22, 15 }, { 13, 16 }),
}
M.EC_TABLE[26] = {
  ec(28, { 10, 114 }, { 2, 115 }),
  ec(28, { 19, 46 }, { 4, 47 }),
  ec(28, { 28, 22 }, { 6, 23 }),
  ec(30, { 33, 16 }, { 4, 17 }),
}
M.EC_TABLE[27] = {
  ec(30, { 8, 122 }, { 4, 123 }),
  ec(28, { 22, 45 }, { 3, 46 }),
  ec(30, { 8, 23 }, { 26, 24 }),
  ec(30, { 12, 15 }, { 28, 16 }),
}
M.EC_TABLE[28] = {
  ec(30, { 3, 117 }, { 10, 118 }),
  ec(28, { 3, 45 }, { 23, 46 }),
  ec(30, { 4, 24 }, { 31, 25 }),
  ec(30, { 11, 15 }, { 31, 16 }),
}
M.EC_TABLE[29] = {
  ec(30, { 7, 116 }, { 7, 117 }),
  ec(28, { 21, 45 }, { 7, 46 }),
  ec(30, { 1, 23 }, { 37, 24 }),
  ec(30, { 19, 15 }, { 26, 16 }),
}
M.EC_TABLE[30] = {
  ec(30, { 5, 115 }, { 10, 116 }),
  ec(28, { 19, 47 }, { 10, 48 }),
  ec(30, { 15, 24 }, { 25, 25 }),
  ec(30, { 23, 15 }, { 25, 16 }),
}
M.EC_TABLE[31] = {
  ec(30, { 13, 115 }, { 3, 116 }),
  ec(28, { 2, 46 }, { 29, 47 }),
  ec(30, { 42, 24 }, { 1, 25 }),
  ec(30, { 23, 15 }, { 28, 16 }),
}
M.EC_TABLE[32] = {
  ec(30, { 17, 115 }),
  ec(28, { 10, 46 }, { 23, 47 }),
  ec(30, { 10, 24 }, { 35, 25 }),
  ec(30, { 19, 15 }, { 35, 16 }),
}
M.EC_TABLE[33] = {
  ec(30, { 17, 115 }, { 1, 116 }),
  ec(28, { 14, 46 }, { 21, 47 }),
  ec(30, { 29, 24 }, { 19, 25 }),
  ec(30, { 11, 15 }, { 46, 16 }),
}
M.EC_TABLE[34] = {
  ec(30, { 13, 115 }, { 6, 116 }),
  ec(28, { 14, 46 }, { 23, 47 }),
  ec(30, { 44, 24 }, { 7, 25 }),
  ec(30, { 59, 16 }, { 1, 17 }),
}
M.EC_TABLE[35] = {
  ec(30, { 12, 121 }, { 7, 122 }),
  ec(28, { 12, 47 }, { 26, 48 }),
  ec(30, { 39, 24 }, { 14, 25 }),
  ec(30, { 22, 15 }, { 41, 16 }),
}
M.EC_TABLE[36] = {
  ec(30, { 6, 121 }, { 14, 122 }),
  ec(28, { 6, 47 }, { 34, 48 }),
  ec(30, { 46, 24 }, { 10, 25 }),
  ec(30, { 2, 15 }, { 64, 16 }),
}
M.EC_TABLE[37] = {
  ec(30, { 17, 122 }, { 4, 123 }),
  ec(28, { 29, 46 }, { 14, 47 }),
  ec(30, { 49, 24 }, { 10, 25 }),
  ec(30, { 24, 15 }, { 46, 16 }),
}
M.EC_TABLE[38] = {
  ec(30, { 4, 122 }, { 18, 123 }),
  ec(28, { 13, 46 }, { 32, 47 }),
  ec(30, { 48, 24 }, { 14, 25 }),
  ec(30, { 42, 15 }, { 32, 16 }),
}
M.EC_TABLE[39] = {
  ec(30, { 20, 117 }, { 4, 118 }),
  ec(28, { 40, 47 }, { 7, 48 }),
  ec(30, { 43, 24 }, { 22, 25 }),
  ec(30, { 10, 15 }, { 67, 16 }),
}
M.EC_TABLE[40] = {
  ec(30, { 19, 118 }, { 6, 119 }),
  ec(28, { 18, 47 }, { 31, 48 }),
  ec(30, { 34, 24 }, { 34, 25 }),
  ec(30, { 20, 15 }, { 61, 16 }),
}

--- Alignment pattern center positions per version.
--- Version 1 has none; version 2+ have these coordinates.
M.ALIGNMENT_POSITIONS = {
  [2] = { 6, 18 },
  [3] = { 6, 22 },
  [4] = { 6, 26 },
  [5] = { 6, 30 },
  [6] = { 6, 34 },
  [7] = { 6, 22, 38 },
  [8] = { 6, 24, 42 },
  [9] = { 6, 26, 46 },
  [10] = { 6, 28, 50 },
  [11] = { 6, 30, 54 },
  [12] = { 6, 32, 58 },
  [13] = { 6, 34, 62 },
  [14] = { 6, 26, 46, 66 },
  [15] = { 6, 26, 48, 70 },
  [16] = { 6, 26, 50, 74 },
  [17] = { 6, 30, 54, 78 },
  [18] = { 6, 30, 56, 82 },
  [19] = { 6, 30, 58, 86 },
  [20] = { 6, 34, 62, 90 },
  [21] = { 6, 28, 50, 72, 94 },
  [22] = { 6, 26, 50, 74, 98 },
  [23] = { 6, 30, 54, 78, 102 },
  [24] = { 6, 28, 54, 80, 106 },
  [25] = { 6, 32, 58, 84, 110 },
  [26] = { 6, 30, 58, 86, 114 },
  [27] = { 6, 34, 62, 90, 118 },
  [28] = { 6, 26, 50, 74, 98, 122 },
  [29] = { 6, 30, 54, 78, 102, 126 },
  [30] = { 6, 26, 52, 78, 104, 130 },
  [31] = { 6, 30, 56, 82, 108, 134 },
  [32] = { 6, 34, 60, 86, 112, 138 },
  [33] = { 6, 30, 58, 86, 114, 142 },
  [34] = { 6, 34, 62, 90, 118, 146 },
  [35] = { 6, 30, 54, 78, 102, 126, 150 },
  [36] = { 6, 24, 50, 76, 102, 128, 154 },
  [37] = { 6, 28, 54, 80, 106, 132, 158 },
  [38] = { 6, 32, 58, 84, 110, 136, 162 },
  [39] = { 6, 26, 54, 82, 110, 138, 166 },
  [40] = { 6, 30, 58, 86, 114, 142, 170 },
}

--- Alphanumeric character mapping
M.ALPHANUM_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"

---@type table<string, number>
M.ALPHANUM_MAP = {}
for i = 1, #M.ALPHANUM_CHARS do
  M.ALPHANUM_MAP[M.ALPHANUM_CHARS:sub(i, i)] = i - 1
end

--- Remainder bits after data placement per version (must be padded with 0)
M.REMAINDER_BITS = {
  0, 7, 7, 7, 7, 7, 0, 0, 0, 0,
  0, 0, 0, 3, 3, 3, 3, 3, 3, 3,
  4, 4, 4, 4, 4, 4, 4, 3, 3, 3,
  3, 3, 3, 3, 0, 0, 0, 0, 0, 0,
}

---Get the size (modules per side) for a QR version.
---@param version number
---@return number
function M.size(version)
  return 17 + version * 4
end

---Get data capacity in codewords for a version/ec_level combination.
---@param version number
---@param ec_level number QrEcLevel
---@return number
function M.data_capacity(version, ec_level)
  local info = M.EC_TABLE[version][ec_level]
  local total_data = 0
  for _, block_group in ipairs(info.blocks) do
    total_data = total_data + block_group[1] * block_group[2]
  end
  return total_data
end

---Get the character capacity for a given version, EC level, and mode.
---@param version number
---@param ec_level number
---@param mode number QrMode
---@return number
function M.char_capacity(version, ec_level, mode)
  local data_codewords = M.data_capacity(version, ec_level)
  local bits = data_codewords * 8
  local vg = M.version_group(version)
  local cc_bits = M.CHAR_COUNT_BITS[mode][vg]

  -- Subtract mode indicator (4 bits) and character count indicator
  bits = bits - 4 - cc_bits

  if mode == M.MODE.NUMERIC then
    -- 10 bits per 3 digits, 7 bits per 2, 4 bits per 1
    return math.floor(bits / 10) * 3 + math.min(math.floor((bits % 10) / 7) + math.floor((bits % 10) / 4), math.floor(bits % 10 / 4) >= 1 and 1 or 0)
  elseif mode == M.MODE.ALPHANUMERIC then
    -- 11 bits per 2 chars, 6 bits per 1
    return math.floor(bits / 11) * 2 + (bits % 11 >= 6 and 1 or 0)
  elseif mode == M.MODE.BYTE then
    return math.floor(bits / 8)
  elseif mode == M.MODE.KANJI then
    return math.floor(bits / 13)
  end
  return 0
end

---Select the best mode for encoding the given data.
---@param text string
---@return number QrMode
function M.select_mode(text)
  -- Check if all numeric
  if text:match("^%d+$") then
    return M.MODE.NUMERIC
  end
  -- Check if all alphanumeric
  local all_alphanum = true
  for i = 1, #text do
    if not M.ALPHANUM_MAP[text:sub(i, i)] then
      all_alphanum = false
      break
    end
  end
  if all_alphanum then
    return M.MODE.ALPHANUMERIC
  end
  return M.MODE.BYTE
end

---Select the minimum version that can hold the data at the given EC level.
---@param text string
---@param ec_level number
---@param mode number
---@return number? version, or nil if too large
function M.select_version(text, ec_level, mode)
  local char_count = #text
  if mode == M.MODE.KANJI then
    char_count = math.floor(#text / 2)
  end
  for version = 1, 40 do
    if M.char_capacity(version, ec_level, mode) >= char_count then
      return version
    end
  end
  return nil
end

--- Format information lookup: 15-bit BCH encoded values.
--- Indexed by [ec_level][mask_pattern+1] (mask 0-7).
M.FORMAT_INFO = {
  -- Level L (ec_level = 1)
  {
    0x77C4, 0x72F3, 0x7DAA, 0x789D, 0x662F, 0x6318, 0x6C41, 0x6976,
  },
  -- Level M (ec_level = 2)
  {
    0x5412, 0x5125, 0x5E7C, 0x5B4B, 0x45F9, 0x40CE, 0x4F97, 0x4AA0,
  },
  -- Level Q (ec_level = 3)
  {
    0x355F, 0x3068, 0x3F31, 0x3A06, 0x24B4, 0x2183, 0x2EDA, 0x2BED,
  },
  -- Level H (ec_level = 4)
  {
    0x1689, 0x13BE, 0x1CE7, 0x19D0, 0x0762, 0x0255, 0x0D0C, 0x083B,
  },
}

--- Version information lookup (versions 7-40): 18-bit BCH encoded values.
M.VERSION_INFO = {
  [7] = 0x07C94,
  [8] = 0x085BC,
  [9] = 0x09A99,
  [10] = 0x0A4D3,
  [11] = 0x0BBF6,
  [12] = 0x0C762,
  [13] = 0x0D847,
  [14] = 0x0E60D,
  [15] = 0x0F928,
  [16] = 0x10B78,
  [17] = 0x1145D,
  [18] = 0x12A17,
  [19] = 0x13532,
  [20] = 0x149A6,
  [21] = 0x15683,
  [22] = 0x168C9,
  [23] = 0x177EC,
  [24] = 0x18EC4,
  [25] = 0x191E1,
  [26] = 0x1AFAB,
  [27] = 0x1B08E,
  [28] = 0x1CC1A,
  [29] = 0x1D33F,
  [30] = 0x1ED75,
  [31] = 0x1F250,
  [32] = 0x209D5,
  [33] = 0x216F0,
  [34] = 0x228BA,
  [35] = 0x2379F,
  [36] = 0x24B0B,
  [37] = 0x2542E,
  [38] = 0x26A64,
  [39] = 0x27541,
  [40] = 0x28C69,
}

return M
