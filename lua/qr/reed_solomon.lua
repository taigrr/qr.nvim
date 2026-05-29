---@brief [[
--- Reed-Solomon error correction encoder.
--- Generates EC codewords for a given message polynomial over GF(256).
---@brief ]]

local galois = require("qr.galois")

local M = {}

---@type table<number, number[]> Cache of generator polynomials by EC codeword count
local _gen_cache = {}

---Get (cached) generator polynomial for a given number of EC codewords.
---@param n number
---@return number[]
local function get_generator(n)
  if not _gen_cache[n] then
    _gen_cache[n] = galois.generator_poly(n)
  end
  return _gen_cache[n]
end

---Encode a message and return its error correction codewords.
---@param data number[] Array of data codeword bytes
---@param num_ec number Number of EC codewords to generate
---@return number[] Array of EC codeword bytes
function M.encode(data, num_ec)
  local gen = get_generator(num_ec)

  -- Create message polynomial: data * x^num_ec
  local msg = {}
  for i = 1, #data do
    msg[i] = data[i]
  end
  for i = 1, num_ec do
    msg[#data + i] = 0
  end

  -- Compute remainder = msg mod generator
  local remainder = galois.poly_mod(msg, gen)

  -- Pad remainder to exactly num_ec length
  while #remainder < num_ec do
    table.insert(remainder, 1, 0)
  end

  return remainder
end

return M
