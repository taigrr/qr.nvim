---@brief [[
--- Bit operations for QR encoding.
--- Uses LuaJIT/Neovim's bit library when available, with a Lua fallback for tests.
---@brief ]]

local native_bit = rawget(_G, "bit") or rawget(_G, "bit32")
if native_bit then
  return native_bit
end

local M = {}

local UINT_BITS = 32
local UINT_MOD = 2 ^ UINT_BITS

local function normalize(value)
  value = value % UINT_MOD
  if value < 0 then
    value = value + UINT_MOD
  end
  return value
end

local function bit_op(a, b, op)
  a = normalize(a)
  b = normalize(b)

  local result = 0
  local bit_value = 1

  for _ = 1, UINT_BITS do
    local a_bit = a % 2
    local b_bit = b % 2

    if op(a_bit, b_bit) then
      result = result + bit_value
    end

    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_value = bit_value * 2
  end

  return result
end

function M.band(a, b)
  return bit_op(a, b, function(a_bit, b_bit)
    return a_bit == 1 and b_bit == 1
  end)
end

function M.bor(a, b)
  return bit_op(a, b, function(a_bit, b_bit)
    return a_bit == 1 or b_bit == 1
  end)
end

function M.bxor(a, b)
  return bit_op(a, b, function(a_bit, b_bit)
    return a_bit ~= b_bit
  end)
end

function M.bnot(a)
  return UINT_MOD - 1 - normalize(a)
end

function M.lshift(a, n)
  return normalize(a * 2 ^ n)
end

function M.rshift(a, n)
  return math.floor(normalize(a) / 2 ^ n)
end

return M
