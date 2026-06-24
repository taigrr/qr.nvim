---@brief [[
--- GF(256) finite field arithmetic for Reed-Solomon error correction.
--- Uses the QR code primitive polynomial: x^8 + x^4 + x^3 + x^2 + 1 (0x11D).
---@brief ]]

local M = {}
local bit = require("qr.bit")

local PRIMITIVE_POLY = 0x11D

---@type number[] Log table: value -> exponent (log_table[1] = 0, log_table[2] = 1, ...)
M.LOG = {}

---@type number[] Anti-log (exp) table: exponent -> value
M.EXP = {}

-- Build log/exp tables
do
  local val = 1
  for i = 0, 254 do
    M.EXP[i] = val
    M.LOG[val] = i
    val = val * 2
    if val >= 256 then
      val = bit.bxor(val, PRIMITIVE_POLY)
    end
  end
  -- Extend EXP table for convenience (avoid modulo in hot paths)
  for i = 255, 511 do
    M.EXP[i] = M.EXP[i - 255]
  end
end

---Multiply two GF(256) values.
---@param a number
---@param b number
---@return number
function M.mul(a, b)
  if a == 0 or b == 0 then
    return 0
  end
  return M.EXP[M.LOG[a] + M.LOG[b]]
end

---Compute the inverse of a GF(256) value.
---@param a number
---@return number
function M.inv(a)
  assert(a ~= 0, "cannot invert zero")
  return M.EXP[255 - M.LOG[a]]
end

---Raise a GF(256) value to a power.
---@param a number
---@param n number
---@return number
function M.pow(a, n)
  if a == 0 then
    return 0
  end
  return M.EXP[(M.LOG[a] * n) % 255]
end

---Add two GF(256) values (XOR).
---@param a number
---@param b number
---@return number
function M.add(a, b)
  return bit.bxor(a, b)
end

---Multiply two polynomials over GF(256).
---Polynomials are represented as arrays where index 1 is the highest degree coefficient.
---@param p1 number[]
---@param p2 number[]
---@return number[]
function M.poly_mul(p1, p2)
  local result = {}
  local len = #p1 + #p2 - 1
  for i = 1, len do
    result[i] = 0
  end
  for i = 1, #p1 do
    for j = 1, #p2 do
      result[i + j - 1] = bit.bxor(result[i + j - 1], M.mul(p1[i], p2[j]))
    end
  end
  return result
end

---Compute the remainder of polynomial division over GF(256).
---@param dividend number[] Dividend polynomial (high degree first)
---@param divisor number[] Divisor polynomial (high degree first)
---@return number[] Remainder polynomial
function M.poly_mod(dividend, divisor)
  local result = {}
  for i = 1, #dividend do
    result[i] = dividend[i]
  end
  for i = 1, #dividend - #divisor + 1 do
    local coef = result[i]
    if coef ~= 0 then
      for j = 2, #divisor do
        result[i + j - 1] = bit.bxor(result[i + j - 1], M.mul(divisor[j], coef))
      end
    end
  end
  -- Return only the remainder (last #divisor - 1 terms)
  local remainder = {}
  local start = #dividend - #divisor + 2
  for i = start, #dividend do
    remainder[#remainder + 1] = result[i]
  end
  return remainder
end

---Generate a Reed-Solomon generator polynomial of given degree.
---Generator = (x - α^0)(x - α^1)...(x - α^(n-1))
---@param num_ec_codewords number Number of error correction codewords
---@return number[] Generator polynomial (high degree first)
function M.generator_poly(num_ec_codewords)
  local gen = { 1 }
  for i = 0, num_ec_codewords - 1 do
    gen = M.poly_mul(gen, { 1, M.EXP[i] })
  end
  return gen
end

return M
