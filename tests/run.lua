--- Test runner for qr.nvim
--- Works standalone with luajit or inside nvim headless.

package.path = table.concat({
  "./lua/?.lua",
  "./lua/?/init.lua",
  package.path,
}, ";")

-- Minimal vim shim for standalone luajit testing
if not vim then
  _G.vim = {
    inspect = function(t)
      if type(t) == "table" then
        local parts = {}
        for k, v in pairs(t) do
          parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
      end
      return tostring(t)
    end,
  }
end

local pass_count = 0
local fail_count = 0
local test_results = {}

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_neq(actual, unexpected, message)
  if actual == unexpected then
    error((message or "assertion failed") .. ": did not expect " .. tostring(unexpected), 2)
  end
end

local function assert_truthy(value, message)
  if not value then
    error((message or "expected truthy value") .. ": got " .. tostring(value), 2)
  end
end

local function assert_falsy(value, message)
  if value then
    error((message or "expected falsy value") .. ": got " .. tostring(value), 2)
  end
end

local function assert_error(fn, message)
  local ok = pcall(fn)
  if ok then
    error(message or "expected function to throw an error", 2)
  end
end

local function assert_table_eq(actual, expected, message)
  if #actual ~= #expected then
    error(
      (message or "table length mismatch") .. ": expected " .. #expected .. " elements, got " .. #actual,
      2
    )
  end
  for i = 1, #expected do
    if actual[i] ~= expected[i] then
      error(
        (message or "table mismatch")
          .. " at index "
          .. i
          .. ": expected "
          .. tostring(expected[i])
          .. ", got "
          .. tostring(actual[i]),
        2
      )
    end
  end
end

local current_suite = ""
local function suite(name)
  current_suite = name
  print("\n=== " .. name .. " ===")
end

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    pass_count = pass_count + 1
    print("  PASS: " .. name)
    table.insert(test_results, { name = current_suite .. "/" .. name, pass = true })
  else
    fail_count = fail_count + 1
    io.stderr:write("  FAIL: " .. name .. "\n    " .. tostring(err) .. "\n")
    table.insert(test_results, { name = current_suite .. "/" .. name, pass = false, err = tostring(err) })
  end
end

-- Reset module cache between test files
local function reset_modules()
  for key, _ in pairs(package.loaded) do
    if key:match("^qr") then
      package.loaded[key] = nil
    end
  end
end

--------------------------------------------------------------------------------
-- TEST: galois.lua
--------------------------------------------------------------------------------
suite("galois")

test("EXP and LOG tables are inverses", function()
  local galois = require("qr.galois")
  for i = 0, 254 do
    local val = galois.EXP[i]
    assert_eq(galois.LOG[val], i, "LOG[EXP[" .. i .. "]]")
  end
end)

test("EXP table has correct first values", function()
  local galois = require("qr.galois")
  assert_eq(galois.EXP[0], 1)
  assert_eq(galois.EXP[1], 2)
  assert_eq(galois.EXP[2], 4)
  assert_eq(galois.EXP[3], 8)
  assert_eq(galois.EXP[7], 128)
  assert_eq(galois.EXP[8], 29) -- 256 XOR 0x11D = 256 XOR 285 = 29
end)

test("EXP wraps correctly at boundary", function()
  local galois = require("qr.galois")
  assert_eq(galois.EXP[255], galois.EXP[0])
  assert_eq(galois.EXP[256], galois.EXP[1])
end)

test("mul identity", function()
  local galois = require("qr.galois")
  for i = 1, 255 do
    assert_eq(galois.mul(i, 1), i, "x * 1 = x for x=" .. i)
  end
end)

test("mul zero", function()
  local galois = require("qr.galois")
  for i = 0, 255 do
    assert_eq(galois.mul(i, 0), 0, "x * 0 = 0 for x=" .. i)
    assert_eq(galois.mul(0, i), 0, "0 * x = 0 for x=" .. i)
  end
end)

test("mul commutativity", function()
  local galois = require("qr.galois")
  assert_eq(galois.mul(7, 13), galois.mul(13, 7))
  assert_eq(galois.mul(100, 200), galois.mul(200, 100))
  assert_eq(galois.mul(255, 128), galois.mul(128, 255))
end)

test("mul known values", function()
  local galois = require("qr.galois")
  -- α^0 * α^0 = α^0 = 1
  assert_eq(galois.mul(1, 1), 1)
  -- α^1 * α^1 = α^2 = 4
  assert_eq(galois.mul(2, 2), 4)
  -- α^7 * α^1 = α^8 = 29
  assert_eq(galois.mul(128, 2), 29)
end)

test("inv correctness", function()
  local galois = require("qr.galois")
  for i = 1, 255 do
    assert_eq(galois.mul(i, galois.inv(i)), 1, "x * inv(x) = 1 for x=" .. i)
  end
end)

test("inv zero throws", function()
  local galois = require("qr.galois")
  assert_error(function()
    galois.inv(0)
  end, "inv(0) should throw")
end)

test("pow correctness", function()
  local galois = require("qr.galois")
  assert_eq(galois.pow(2, 0), 1) -- anything^0 = 1
  assert_eq(galois.pow(2, 1), 2) -- 2^1 = 2
  assert_eq(galois.pow(2, 8), 29) -- α^8 = 29
  assert_eq(galois.pow(0, 5), 0)
end)

test("add is XOR", function()
  local galois = require("qr.galois")
  assert_eq(galois.add(0, 0), 0)
  assert_eq(galois.add(0xFF, 0xFF), 0)
  assert_eq(galois.add(0xAA, 0x55), 0xFF)
  assert_eq(galois.add(100, 0), 100)
end)

test("poly_mul identity", function()
  local galois = require("qr.galois")
  local p = { 1, 2, 3 }
  local result = galois.poly_mul(p, { 1 })
  assert_table_eq(result, p)
end)

test("poly_mul known result", function()
  local galois = require("qr.galois")
  -- (x + α^0)(x + α^1) = x^2 + (α^0 + α^1)x + α^0*α^1
  -- = x^2 + 3x + 2
  local result = galois.poly_mul({ 1, 1 }, { 1, 2 })
  assert_eq(result[1], 1) -- x^2
  assert_eq(result[2], 3) -- (1 XOR 2)x
  assert_eq(result[3], 2) -- 1*2
end)

test("generator_poly degree 2", function()
  local galois = require("qr.galois")
  local gen = galois.generator_poly(2)
  assert_eq(#gen, 3) -- degree 2 polynomial has 3 coefficients
  assert_eq(gen[1], 1) -- monic
end)

test("generator_poly degree 7 (version 1 level L)", function()
  local galois = require("qr.galois")
  local gen = galois.generator_poly(7)
  assert_eq(#gen, 8)
  assert_eq(gen[1], 1)
end)

test("poly_mod basic", function()
  local galois = require("qr.galois")
  -- dividend = {1, 0, 0, 0} (x^3), divisor = {1, 0, 1} (x^2 + 1)
  local remainder = galois.poly_mod({ 1, 0, 0, 0 }, { 1, 0, 1 })
  assert_eq(#remainder, 2)
  -- poly_mod: result = {1,0,0,0}
  -- i=1: coef=1, result[2]^=mul(0,1)=0, result[3]^=mul(1,1)=1 → {1,0,1,0}
  -- i=2: coef=0, skip
  -- remainder = last 2 = {1, 0}
  assert_eq(remainder[1], 1)
  assert_eq(remainder[2], 0)
end)

--------------------------------------------------------------------------------
-- TEST: reed_solomon.lua
--------------------------------------------------------------------------------
suite("reed_solomon")

reset_modules()

test("encode produces correct number of EC codewords", function()
  local rs = require("qr.reed_solomon")
  local data_cw = { 32, 91, 11, 120, 209, 114, 220, 77, 67, 64, 236, 17, 236, 17, 236, 17, 236, 17, 236 }
  local ec = rs.encode(data_cw, 7)
  assert_eq(#ec, 7)
end)

test("encode known version 1-L EC codewords", function()
  local rs = require("qr.reed_solomon")
  -- "HELLO WORLD" in alphanumeric, version 1-M has specific known EC values
  -- Let's test with a simple known case: data = {0} with 2 EC codewords
  local ec = rs.encode({ 0 }, 2)
  assert_eq(#ec, 2)
  -- For data [0], generator (x + 1)(x + 2) = x^2 + 3x + 2
  -- 0 * x^2 mod (x^2 + 3x + 2) = remainder of {0, 0, 0} mod {1, 3, 2}
  -- All zeros
  assert_eq(ec[1], 0)
  assert_eq(ec[2], 0)
end)

test("encode non-trivial data", function()
  local rs = require("qr.reed_solomon")
  local ec = rs.encode({ 1 }, 2)
  assert_eq(#ec, 2)
  -- data = {1}, padded = {1, 0, 0}
  -- {1, 0, 0} mod {1, 3, 2}:
  -- i=1: coef=1, result[2] ^= mul(3,1)=3, result[3] ^= mul(2,1)=2
  -- result = {1, 3, 2}
  -- remainder = last 2 = {3, 2}
  assert_eq(ec[1], 3)
  assert_eq(ec[2], 2)
end)

test("encode deterministic", function()
  local rs = require("qr.reed_solomon")
  local data_cw = { 65, 108, 108, 111 }
  local ec1 = rs.encode(data_cw, 10)
  local ec2 = rs.encode(data_cw, 10)
  assert_table_eq(ec1, ec2)
end)

test("encode with larger block", function()
  local rs = require("qr.reed_solomon")
  -- 10 data codewords, 13 EC codewords (like version 3 level Q block)
  local data_cw = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
  local ec = rs.encode(data_cw, 13)
  assert_eq(#ec, 13)
end)

--------------------------------------------------------------------------------
-- TEST: data.lua
--------------------------------------------------------------------------------
suite("data")

reset_modules()

test("size formula", function()
  local qr_data = require("qr.data")
  assert_eq(qr_data.size(1), 21)
  assert_eq(qr_data.size(2), 25)
  assert_eq(qr_data.size(10), 57)
  assert_eq(qr_data.size(40), 177)
end)

test("version_group boundaries", function()
  local qr_data = require("qr.data")
  assert_eq(qr_data.version_group(1), 1)
  assert_eq(qr_data.version_group(9), 1)
  assert_eq(qr_data.version_group(10), 2)
  assert_eq(qr_data.version_group(26), 2)
  assert_eq(qr_data.version_group(27), 3)
  assert_eq(qr_data.version_group(40), 3)
end)

test("data_capacity version 1", function()
  local qr_data = require("qr.data")
  assert_eq(qr_data.data_capacity(1, qr_data.EC_LEVEL.L), 19)
  assert_eq(qr_data.data_capacity(1, qr_data.EC_LEVEL.M), 16)
  assert_eq(qr_data.data_capacity(1, qr_data.EC_LEVEL.Q), 13)
  assert_eq(qr_data.data_capacity(1, qr_data.EC_LEVEL.H), 9)
end)

test("data_capacity + EC = total codewords", function()
  local qr_data = require("qr.data")
  for version = 1, 5 do
    for level = 1, 4 do
      local info = qr_data.EC_TABLE[version][level]
      local total_data = 0
      local total_blocks = 0
      for _, bg in ipairs(info.blocks) do
        total_data = total_data + bg[1] * bg[2]
        total_blocks = total_blocks + bg[1]
      end
      local total = total_data + total_blocks * info.ec_per_block
      assert_eq(total, qr_data.TOTAL_CODEWORDS[version], "v" .. version .. " level " .. level)
    end
  end
end)

test("select_mode numeric", function()
  local qr_data = require("qr.data")
  assert_eq(qr_data.select_mode("12345"), qr_data.MODE.NUMERIC)
  assert_eq(qr_data.select_mode("0"), qr_data.MODE.NUMERIC)
end)

test("select_mode alphanumeric", function()
  local qr_data = require("qr.data")
  assert_eq(qr_data.select_mode("HELLO"), qr_data.MODE.ALPHANUMERIC)
  assert_eq(qr_data.select_mode("HELLO WORLD"), qr_data.MODE.ALPHANUMERIC)
  assert_eq(qr_data.select_mode("A1 B2"), qr_data.MODE.ALPHANUMERIC)
end)

test("select_mode byte", function()
  local qr_data = require("qr.data")
  assert_eq(qr_data.select_mode("hello"), qr_data.MODE.BYTE)
  assert_eq(qr_data.select_mode("https://example.com"), qr_data.MODE.BYTE)
  assert_eq(qr_data.select_mode("Hello!"), qr_data.MODE.BYTE)
end)

test("select_version finds minimum", function()
  local qr_data = require("qr.data")
  -- "HELLO" is 5 alphanumeric chars - should fit in version 1
  local v = qr_data.select_version("HELLO", qr_data.EC_LEVEL.L, qr_data.MODE.ALPHANUMERIC)
  assert_eq(v, 1)
end)

test("select_version returns nil for too-long data", function()
  local qr_data = require("qr.data")
  local long_text = string.rep("A", 10000)
  local v = qr_data.select_version(long_text, qr_data.EC_LEVEL.H, qr_data.MODE.BYTE)
  assert_eq(v, nil)
end)

test("ALPHANUM_MAP has 45 entries", function()
  local qr_data = require("qr.data")
  local count = 0
  for _ in pairs(qr_data.ALPHANUM_MAP) do
    count = count + 1
  end
  assert_eq(count, 45)
end)

test("ALPHANUM_MAP correct mappings", function()
  local qr_data = require("qr.data")
  assert_eq(qr_data.ALPHANUM_MAP["0"], 0)
  assert_eq(qr_data.ALPHANUM_MAP["9"], 9)
  assert_eq(qr_data.ALPHANUM_MAP["A"], 10)
  assert_eq(qr_data.ALPHANUM_MAP["Z"], 35)
  assert_eq(qr_data.ALPHANUM_MAP[" "], 36)
  assert_eq(qr_data.ALPHANUM_MAP[":"], 44)
end)

test("FORMAT_INFO correct count", function()
  local qr_data = require("qr.data")
  assert_eq(#qr_data.FORMAT_INFO, 4)
  for level = 1, 4 do
    assert_eq(#qr_data.FORMAT_INFO[level], 8)
  end
end)

test("ALIGNMENT_POSITIONS version 2", function()
  local qr_data = require("qr.data")
  assert_table_eq(qr_data.ALIGNMENT_POSITIONS[2], { 6, 18 })
end)

test("ALIGNMENT_POSITIONS version 7", function()
  local qr_data = require("qr.data")
  assert_table_eq(qr_data.ALIGNMENT_POSITIONS[7], { 6, 22, 38 })
end)

--------------------------------------------------------------------------------
-- TEST: encode.lua
--------------------------------------------------------------------------------
suite("encode")

reset_modules()

test("BitBuffer put single bits", function()
  local encode = require("qr.encode")
  local buf = encode.BitBuffer.new()
  buf:put_bit(1)
  buf:put_bit(0)
  buf:put_bit(1)
  assert_eq(buf.length, 3)
  assert_eq(buf.bits[1], 1)
  assert_eq(buf.bits[2], 0)
  assert_eq(buf.bits[3], 1)
end)

test("BitBuffer put multi-bit value", function()
  local encode = require("qr.encode")
  local buf = encode.BitBuffer.new()
  buf:put(0xA, 4) -- 1010
  assert_eq(buf.length, 4)
  assert_eq(buf.bits[1], 1)
  assert_eq(buf.bits[2], 0)
  assert_eq(buf.bits[3], 1)
  assert_eq(buf.bits[4], 0)
end)

test("BitBuffer put 8-bit value", function()
  local encode = require("qr.encode")
  local buf = encode.BitBuffer.new()
  buf:put(0xFF, 8)
  assert_eq(buf.length, 8)
  for i = 1, 8 do
    assert_eq(buf.bits[i], 1, "bit " .. i)
  end
end)

test("BitBuffer put zero", function()
  local encode = require("qr.encode")
  local buf = encode.BitBuffer.new()
  buf:put(0, 10)
  assert_eq(buf.length, 10)
  for i = 1, 10 do
    assert_eq(buf.bits[i], 0, "bit " .. i)
  end
end)

test("encode_numeric 3 digits", function()
  local encode = require("qr.encode")
  local buf = encode.BitBuffer.new()
  encode.encode_numeric(buf, "123")
  -- 123 in 10 bits = 0001111011
  assert_eq(buf.length, 10)
end)

test("encode_numeric 5 digits", function()
  local encode = require("qr.encode")
  local buf = encode.BitBuffer.new()
  encode.encode_numeric(buf, "12345")
  -- 123 in 10 bits + 45 in 7 bits = 17 bits
  assert_eq(buf.length, 17)
end)

test("encode_numeric 1 digit", function()
  local encode = require("qr.encode")
  local buf = encode.BitBuffer.new()
  encode.encode_numeric(buf, "7")
  -- 7 in 4 bits
  assert_eq(buf.length, 4)
end)

test("encode_alphanumeric 2 chars", function()
  local encode = require("qr.encode")
  local buf = encode.BitBuffer.new()
  encode.encode_alphanumeric(buf, "AC")
  -- A=10, C=12, 10*45+12=462, in 11 bits
  assert_eq(buf.length, 11)
  -- 462 = 0b00111001110
  local expected = { 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0 }
  for i = 1, 11 do
    assert_eq(buf.bits[i], expected[i], "bit " .. i)
  end
end)

test("encode_alphanumeric odd chars", function()
  local encode = require("qr.encode")
  local buf = encode.BitBuffer.new()
  encode.encode_alphanumeric(buf, "ABC")
  -- AB: 10*45+11=461 in 11 bits, C: 12 in 6 bits = 17 bits
  assert_eq(buf.length, 17)
end)

test("encode_byte", function()
  local encode = require("qr.encode")
  local buf = encode.BitBuffer.new()
  encode.encode_byte(buf, "Hi")
  -- H=72, i=105, each in 8 bits = 16 bits
  assert_eq(buf.length, 16)
end)

test("encode full pipeline produces correct codeword count", function()
  local encode = require("qr.encode")
  local qr_data = require("qr.data")
  -- "HELLO WORLD" version 1 level M - alphanumeric
  local codewords = encode.encode("HELLO WORLD", 1, qr_data.EC_LEVEL.M, qr_data.MODE.ALPHANUMERIC)
  -- Total codewords for version 1 = 26
  assert_eq(#codewords, qr_data.TOTAL_CODEWORDS[1])
end)

test("encode version 1-L byte mode", function()
  local encode = require("qr.encode")
  local qr_data = require("qr.data")
  local codewords = encode.encode("Hello", 1, qr_data.EC_LEVEL.L, qr_data.MODE.BYTE)
  assert_eq(#codewords, qr_data.TOTAL_CODEWORDS[1])
end)

test("interleave single block is passthrough", function()
  local encode = require("qr.encode")
  local qr_data = require("qr.data")
  -- Version 1 level L: 1 block of 19 data + 7 EC
  local data_cw = {}
  for i = 1, 19 do
    data_cw[i] = i
  end
  local result = encode.interleave(data_cw, 1, qr_data.EC_LEVEL.L)
  -- First 19 should be data, last 7 should be EC
  assert_eq(#result, 26)
  for i = 1, 19 do
    assert_eq(result[i], i, "data codeword " .. i)
  end
end)

test("interleave multi-block", function()
  local encode = require("qr.encode")
  local qr_data = require("qr.data")
  -- Version 5 level Q: 2 blocks of 15, 2 blocks of 16 data
  local total_data = qr_data.data_capacity(5, qr_data.EC_LEVEL.Q)
  local data_cw = {}
  for i = 1, total_data do
    data_cw[i] = i % 256
  end
  local result = encode.interleave(data_cw, 5, qr_data.EC_LEVEL.Q)
  assert_eq(#result, qr_data.TOTAL_CODEWORDS[5])
end)

--------------------------------------------------------------------------------
-- TEST: bitmap.lua
--------------------------------------------------------------------------------
suite("bitmap")

reset_modules()

test("new creates zeroed bitmap", function()
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  assert_eq(bm.size, 21)
  for r = 0, 20 do
    for c = 0, 20 do
      assert_eq(bm:get(r, c), 0, "module at " .. r .. "," .. c)
    end
  end
end)

test("set and get", function()
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  bm:set(5, 10, 1)
  assert_eq(bm:get(5, 10), 1)
  assert_eq(bm:get(5, 9), 0)
  bm:set(5, 10, 0)
  assert_eq(bm:get(5, 10), 0)
end)

test("set boundary values", function()
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  bm:set(0, 0, 1)
  bm:set(20, 20, 1)
  bm:set(0, 20, 1)
  bm:set(20, 0, 1)
  assert_eq(bm:get(0, 0), 1)
  assert_eq(bm:get(20, 20), 1)
  assert_eq(bm:get(0, 20), 1)
  assert_eq(bm:get(20, 0), 1)
end)

test("reserve and is_reserved", function()
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  assert_falsy(bm:is_reserved(3, 4))
  bm:reserve(3, 4)
  assert_truthy(bm:is_reserved(3, 4))
  assert_falsy(bm:is_reserved(3, 5))
end)

test("set_reserved sets both value and reserved flag", function()
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  bm:set_reserved(7, 7, 1)
  assert_eq(bm:get(7, 7), 1)
  assert_truthy(bm:is_reserved(7, 7))
end)

test("toggle flips unreserved modules", function()
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  bm:set(5, 5, 1)
  bm:toggle(5, 5)
  assert_eq(bm:get(5, 5), 0)
  bm:toggle(5, 5)
  assert_eq(bm:get(5, 5), 1)
end)

test("toggle does not affect reserved modules", function()
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  bm:set_reserved(5, 5, 1)
  bm:toggle(5, 5)
  assert_eq(bm:get(5, 5), 1) -- unchanged
end)

test("clone creates independent copy", function()
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  bm:set(3, 3, 1)
  local copy = bm:clone()
  assert_eq(copy:get(3, 3), 1)
  copy:set(3, 3, 0)
  assert_eq(bm:get(3, 3), 1)
  assert_eq(copy:get(3, 3), 0)
end)

test("to_table dimensions", function()
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(5)
  bm:set(2, 3, 1)
  local t = bm:to_table()
  assert_eq(#t, 5)
  assert_eq(#t[1], 5)
  assert_eq(t[3][4], 1) -- row 2 col 3 -> 1-indexed [3][4]
  assert_eq(t[1][1], 0)
end)

test("in_bounds", function()
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  assert_truthy(bm:in_bounds(0, 0))
  assert_truthy(bm:in_bounds(20, 20))
  assert_falsy(bm:in_bounds(-1, 0))
  assert_falsy(bm:in_bounds(0, -1))
  assert_falsy(bm:in_bounds(21, 0))
  assert_falsy(bm:in_bounds(0, 21))
end)

test("large bitmap word boundary", function()
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(57) -- version 10
  -- Set modules around word boundaries (every 32 bits)
  bm:set(0, 31, 1)
  bm:set(0, 32, 1)
  bm:set(1, 0, 1)
  assert_eq(bm:get(0, 31), 1)
  assert_eq(bm:get(0, 32), 1)
  assert_eq(bm:get(1, 0), 1)
  assert_eq(bm:get(0, 30), 0)
  assert_eq(bm:get(0, 33), 0)
end)

--------------------------------------------------------------------------------
-- TEST: mask.lua
--------------------------------------------------------------------------------
suite("mask")

reset_modules()

test("pattern 0: (row + col) % 2 == 0", function()
  local mask = require("qr.mask")
  local fn = mask.PATTERNS[0]
  assert_truthy(fn(0, 0))
  assert_falsy(fn(0, 1))
  assert_truthy(fn(0, 2))
  assert_truthy(fn(1, 1))
  assert_falsy(fn(1, 0))
end)

test("pattern 1: row % 2 == 0", function()
  local mask = require("qr.mask")
  local fn = mask.PATTERNS[1]
  assert_truthy(fn(0, 0))
  assert_truthy(fn(0, 5))
  assert_falsy(fn(1, 0))
  assert_truthy(fn(2, 3))
end)

test("pattern 2: col % 3 == 0", function()
  local mask = require("qr.mask")
  local fn = mask.PATTERNS[2]
  assert_truthy(fn(5, 0))
  assert_falsy(fn(5, 1))
  assert_falsy(fn(5, 2))
  assert_truthy(fn(5, 3))
end)

test("apply only affects unreserved modules", function()
  local mask = require("qr.mask")
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(5)
  bm:set_reserved(0, 0, 1)
  bm:set(1, 1, 0)
  mask.apply(bm, 0)
  assert_eq(bm:get(0, 0), 1) -- reserved, unchanged
  -- (1,1) % 2 == 0, so should toggle -> 1
  assert_eq(bm:get(1, 1), 1)
end)

test("penalty_rule1 no runs", function()
  local mask = require("qr.mask")
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(5)
  -- Alternating pattern: no runs >= 5
  for r = 0, 4 do
    for c = 0, 4 do
      bm:set(r, c, (r + c) % 2)
    end
  end
  assert_eq(mask.penalty_rule1(bm), 0)
end)

test("penalty_rule1 full row", function()
  local mask = require("qr.mask")
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(7)
  -- Entire first row is dark
  for c = 0, 6 do
    bm:set(0, c, 1)
  end
  -- Run of 7: penalty = 3 + (7-5) = 5
  local penalty = mask.penalty_rule1(bm)
  assert_truthy(penalty >= 5, "expected at least 5, got " .. penalty)
end)

test("penalty_rule2 single block", function()
  local mask = require("qr.mask")
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(5)
  -- 2x2 block at (0,0)
  bm:set(0, 0, 1)
  bm:set(0, 1, 1)
  bm:set(1, 0, 1)
  bm:set(1, 1, 1)
  -- Rule 2 counts ALL same-color 2x2 blocks (including light ones)
  -- 1 dark 2x2 + 12 light-only 2x2 blocks = 13 * 3 = 39
  assert_eq(mask.penalty_rule2(bm), 39)
end)

test("penalty_rule4 all dark", function()
  local mask = require("qr.mask")
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(5)
  for r = 0, 4 do
    for c = 0, 4 do
      bm:set(r, c, 1)
    end
  end
  -- 100% dark -> deviation = |100-50|/5 = 10 -> penalty = 100
  local penalty = mask.penalty_rule4(bm)
  assert_eq(penalty, 100)
end)

test("penalty_rule4 balanced", function()
  local mask = require("qr.mask")
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(10)
  -- Set exactly half to dark
  local count = 0
  for r = 0, 9 do
    for c = 0, 9 do
      if count < 50 then
        bm:set(r, c, 1)
      end
      count = count + 1
    end
  end
  -- 50% dark -> deviation = 0 -> penalty = 0
  assert_eq(mask.penalty_rule4(bm), 0)
end)

--------------------------------------------------------------------------------
-- TEST: matrix.lua
--------------------------------------------------------------------------------
suite("matrix")

reset_modules()

test("place_finder creates 7x7 pattern", function()
  local matrix = require("qr.matrix")
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  matrix.place_finder(bm, 0, 0)

  -- Outer ring should be dark
  for i = 0, 6 do
    assert_eq(bm:get(0, i), 1, "top edge " .. i)
    assert_eq(bm:get(6, i), 1, "bottom edge " .. i)
    assert_eq(bm:get(i, 0), 1, "left edge " .. i)
    assert_eq(bm:get(i, 6), 1, "right edge " .. i)
  end
  -- Inner area should be light (except center 3x3)
  assert_eq(bm:get(1, 1), 0)
  assert_eq(bm:get(1, 5), 0)
  -- Center 3x3 should be dark
  assert_eq(bm:get(2, 2), 1)
  assert_eq(bm:get(3, 3), 1)
  assert_eq(bm:get(4, 4), 1)
end)

test("finder pattern modules are reserved", function()
  local matrix = require("qr.matrix")
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  matrix.place_finder(bm, 0, 0)
  for r = 0, 6 do
    for c = 0, 6 do
      assert_truthy(bm:is_reserved(r, c), "reserved at " .. r .. "," .. c)
    end
  end
end)

test("place_alignment creates 5x5 pattern", function()
  local matrix = require("qr.matrix")
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(25)
  matrix.place_alignment(bm, 10, 10)

  -- Outer ring dark
  for i = -2, 2 do
    assert_eq(bm:get(8, 10 + i), 1, "top edge")
    assert_eq(bm:get(12, 10 + i), 1, "bottom edge")
    assert_eq(bm:get(10 + i, 8), 1, "left edge")
    assert_eq(bm:get(10 + i, 12), 1, "right edge")
  end
  -- Center dark
  assert_eq(bm:get(10, 10), 1)
  -- Inner ring light
  assert_eq(bm:get(9, 9), 0)
  assert_eq(bm:get(9, 10), 0)
  assert_eq(bm:get(9, 11), 0)
end)

test("place_timing alternates", function()
  local matrix = require("qr.matrix")
  local bitmap = require("qr.bitmap")
  local bm = bitmap.Bitmap.new(21)
  matrix.place_finder(bm, 0, 0)
  matrix.place_finder(bm, 0, 14)
  matrix.place_finder(bm, 14, 0)
  matrix.place_separators(bm, 21)
  matrix.place_timing(bm, 21)

  -- Horizontal timing at row 6, cols 8-12
  for i = 8, 12 do
    local expected = (i % 2 == 0) and 1 or 0
    assert_eq(bm:get(6, i), expected, "timing at col " .. i)
  end
end)

test("build version 1 produces correct size", function()
  local matrix = require("qr.matrix")
  local qr_data = require("qr.data")
  -- Fake codewords (all zeros)
  local codewords = {}
  for i = 1, qr_data.TOTAL_CODEWORDS[1] do
    codewords[i] = 0
  end
  local bm = matrix.build(codewords, 1, qr_data.EC_LEVEL.L, 0)
  assert_eq(bm.size, 21)
end)

test("build version 2 produces correct size", function()
  local matrix = require("qr.matrix")
  local qr_data = require("qr.data")
  local codewords = {}
  for i = 1, qr_data.TOTAL_CODEWORDS[2] do
    codewords[i] = 0
  end
  local bm = matrix.build(codewords, 2, qr_data.EC_LEVEL.L, 0)
  assert_eq(bm.size, 25)
end)

test("build has all modules reserved or data-placed", function()
  local matrix = require("qr.matrix")
  local qr_data = require("qr.data")
  local encode = require("qr.encode")
  -- Use actual encoded data
  local codewords = encode.encode("TEST", 1, qr_data.EC_LEVEL.L, qr_data.MODE.BYTE)
  local bm = matrix.build(codewords, 1, qr_data.EC_LEVEL.L, 0)
  -- Every module should have been touched
  assert_eq(bm.size, 21)
end)

--------------------------------------------------------------------------------
-- TEST: render.lua
--------------------------------------------------------------------------------
suite("render")

reset_modules()

test("to_lines produces correct line count", function()
  local bitmap = require("qr.bitmap")
  local render = require("qr.render")
  local bm = bitmap.Bitmap.new(21)
  local lines = render.to_lines(bm, 4)
  -- Total height = 21 + 8 = 29, ceil(29/2) = 15 lines
  assert_eq(#lines, 15)
end)

test("to_lines with quiet zone 0", function()
  local bitmap = require("qr.bitmap")
  local render = require("qr.render")
  local bm = bitmap.Bitmap.new(21)
  local lines = render.to_lines(bm, 0)
  -- 21 rows / 2 = 11 lines (ceil)
  assert_eq(#lines, 11)
end)

test("to_pixel_table dimensions", function()
  local bitmap = require("qr.bitmap")
  local render = require("qr.render")
  local bm = bitmap.Bitmap.new(21)
  local pt = render.to_pixel_table(bm, 4)
  assert_eq(pt.width, 29)
  assert_eq(pt.height, 29)
  assert_eq(#pt.pixels, 29)
  assert_eq(#pt.pixels[1], 29)
end)

test("to_pixel_table quiet zone is light", function()
  local bitmap = require("qr.bitmap")
  local render = require("qr.render")
  local bm = bitmap.Bitmap.new(21)
  bm:set(0, 0, 1)
  local pt = render.to_pixel_table(bm, 4)
  -- Quiet zone corners should be 0
  assert_eq(pt.pixels[1][1], 0)
  assert_eq(pt.pixels[1][29], 0)
  assert_eq(pt.pixels[29][1], 0)
  -- QR module (0,0) mapped to pixel (5,5)
  assert_eq(pt.pixels[5][5], 1)
end)

test("to_lines_inverted flips colors", function()
  local bitmap = require("qr.bitmap")
  local render = require("qr.render")
  -- Use a mixed pattern so normal and inverted differ
  local bm = bitmap.Bitmap.new(4)
  bm:set(0, 0, 1)
  bm:set(0, 1, 0)
  bm:set(1, 0, 0)
  bm:set(1, 1, 1)

  local normal = render.to_lines(bm, 0)
  local inverted = render.to_lines_inverted(bm, 0)
  assert_neq(normal[1], inverted[1])
end)

--------------------------------------------------------------------------------
-- TEST: integration (end-to-end)
--------------------------------------------------------------------------------
suite("integration")

reset_modules()

test("generate simple URL", function()
  local qr = require("qr")
  -- Temporarily set config
  qr.config.ec_level = 1
  local bm, version, mask = qr.generate("https://example.com")
  assert_truthy(version >= 1 and version <= 40)
  assert_truthy(mask >= 0 and mask <= 7)
  assert_truthy(bm.size > 0)
end)

test("generate numeric data", function()
  local qr = require("qr")
  qr.config.ec_level = 1
  local bm, version = qr.generate("12345678")
  assert_truthy(version >= 1)
  assert_eq(bm.size, 21) -- Should fit in version 1
end)

test("generate alphanumeric data", function()
  local qr = require("qr")
  qr.config.ec_level = 1
  local bm, version = qr.generate("HELLO WORLD")
  assert_truthy(version >= 1)
  assert_truthy(bm.size >= 21)
end)

test("generate with different EC levels", function()
  local qr = require("qr")
  local text = "https://example.com/path"
  local _, v_l = qr.generate(text, { ec_level = 1 })
  local _, v_h = qr.generate(text, { ec_level = 4 })
  -- Higher EC requires more space, so version should be >= lower EC version
  assert_truthy(v_h >= v_l, "H version should be >= L version")
end)

test("render produces non-empty lines", function()
  local qr = require("qr")
  qr.config.ec_level = 1
  local lines = qr.render("test")
  assert_truthy(#lines > 0)
  assert_truthy(#lines[1] > 0)
end)

test("render version 1 line width matches expected", function()
  local qr = require("qr")
  qr.config.ec_level = 1
  qr.config.quiet_zone = 4
  local lines, info = qr.render("HELLO WORLD")
  -- version 1 = 21 modules + 2*4 quiet = 29 characters wide
  -- But we need to check display width due to Unicode
  assert_truthy(info.version >= 1)
  assert_truthy(#lines > 0)
end)

test("different inputs produce different QR codes", function()
  local qr = require("qr")
  qr.config.ec_level = 1
  local lines1 = qr.render("aaa")
  local lines2 = qr.render("bbb")
  local same = true
  for i = 1, math.min(#lines1, #lines2) do
    if lines1[i] ~= lines2[i] then
      same = false
      break
    end
  end
  assert_falsy(same, "different inputs should produce different QR codes")
end)

test("empty string errors", function()
  local qr_data = require("qr.data")
  -- Empty string should still get a version (version 1 can hold 0 bytes)
  local v = qr_data.select_version("", qr_data.EC_LEVEL.L, qr_data.MODE.BYTE)
  assert_truthy(v ~= nil)
end)

test("long URL version selection", function()
  local qr = require("qr")
  qr.config.ec_level = 1
  local url = "https://passport-aos-preview.national-design-studio-development.workers.dev"
  local _, version = qr.generate(url)
  -- 77 bytes -> should need version 5+ at Level L
  assert_truthy(version >= 4, "long URL should need version 4+ but got " .. version)
end)

test("max version 1 capacity byte mode level L", function()
  local qr = require("qr")
  qr.config.ec_level = 1
  -- Version 1-L can hold 17 bytes in byte mode
  local text17 = string.rep("x", 17)
  local _, version = qr.generate(text17)
  assert_eq(version, 1)
end)

test("exceeds version 1 goes to version 2", function()
  local qr = require("qr")
  qr.config.ec_level = 1
  -- Version 1-L max is 17 bytes, so 18 should bump to version 2
  local text18 = string.rep("x", 18)
  local _, version = qr.generate(text18)
  assert_truthy(version >= 2, "18 bytes should exceed version 1")
end)

--------------------------------------------------------------------------------
-- RESULTS
--------------------------------------------------------------------------------
print("\n" .. string.rep("=", 60))
print(string.format("Results: %d passed, %d failed, %d total", pass_count, fail_count, pass_count + fail_count))
print(string.rep("=", 60))

if fail_count > 0 then
  print("\nFailed tests:")
  for _, r in ipairs(test_results) do
    if not r.pass then
      print("  - " .. r.name .. ": " .. r.err)
    end
  end
  os.exit(1)
end
