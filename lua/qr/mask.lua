---@brief [[
--- QR code masking patterns and penalty score calculation.
--- Implements all 8 mask patterns and the 4 penalty rules from ISO 18004.
---@brief ]]

local M = {}

---@type fun(row: number, col: number): boolean[]
--- Each function returns true if the module should be toggled.
M.PATTERNS = {
  [0] = function(row, col)
    return (row + col) % 2 == 0
  end,
  [1] = function(row, _)
    return row % 2 == 0
  end,
  [2] = function(_, col)
    return col % 3 == 0
  end,
  [3] = function(row, col)
    return (row + col) % 3 == 0
  end,
  [4] = function(row, col)
    return (math.floor(row / 2) + math.floor(col / 3)) % 2 == 0
  end,
  [5] = function(row, col)
    return (row * col) % 2 + (row * col) % 3 == 0
  end,
  [6] = function(row, col)
    return ((row * col) % 2 + (row * col) % 3) % 2 == 0
  end,
  [7] = function(row, col)
    return ((row + col) % 2 + (row * col) % 3) % 2 == 0
  end,
}

---Apply a mask pattern to a bitmap. Only toggles non-reserved modules.
---@param bm table QrBitmap
---@param pattern number Mask pattern index (0-7)
function M.apply(bm, pattern)
  local fn = M.PATTERNS[pattern]
  for row = 0, bm.size - 1 do
    for col = 0, bm.size - 1 do
      if not bm:is_reserved(row, col) and fn(row, col) then
        bm:toggle(row, col)
      end
    end
  end
end

---Compute penalty score rule 1: runs of same-colored modules in rows/columns.
---5+ consecutive same-color modules: 3 + (run_length - 5)
---@param bm table QrBitmap
---@return number
function M.penalty_rule1(bm)
  local penalty = 0
  local size = bm.size

  -- Horizontal runs
  for row = 0, size - 1 do
    local run = 1
    for col = 1, size - 1 do
      if bm:get(row, col) == bm:get(row, col - 1) then
        run = run + 1
      else
        if run >= 5 then
          penalty = penalty + 3 + (run - 5)
        end
        run = 1
      end
    end
    if run >= 5 then
      penalty = penalty + 3 + (run - 5)
    end
  end

  -- Vertical runs
  for col = 0, size - 1 do
    local run = 1
    for row = 1, size - 1 do
      if bm:get(row, col) == bm:get(row - 1, col) then
        run = run + 1
      else
        if run >= 5 then
          penalty = penalty + 3 + (run - 5)
        end
        run = 1
      end
    end
    if run >= 5 then
      penalty = penalty + 3 + (run - 5)
    end
  end

  return penalty
end

---Compute penalty score rule 2: 2x2 blocks of same-colored modules.
---Each 2x2 block of same color adds 3.
---@param bm table QrBitmap
---@return number
function M.penalty_rule2(bm)
  local penalty = 0
  local size = bm.size

  for row = 0, size - 2 do
    for col = 0, size - 2 do
      local val = bm:get(row, col)
      if val == bm:get(row, col + 1) and val == bm:get(row + 1, col) and val == bm:get(row + 1, col + 1) then
        penalty = penalty + 3
      end
    end
  end

  return penalty
end

---Compute penalty score rule 3: finder-like patterns (1011101 with 4 light modules).
---Each occurrence adds 40.
---@param bm table QrBitmap
---@return number
function M.penalty_rule3(bm)
  local penalty = 0
  local size = bm.size

  -- Pattern: 10111010000 or 00001011101
  local function check_pattern(modules)
    -- 1,0,1,1,1,0,1,0,0,0,0
    if
      modules[1] == 1
      and modules[2] == 0
      and modules[3] == 1
      and modules[4] == 1
      and modules[5] == 1
      and modules[6] == 0
      and modules[7] == 1
      and modules[8] == 0
      and modules[9] == 0
      and modules[10] == 0
      and modules[11] == 0
    then
      return true
    end
    -- 0,0,0,0,1,0,1,1,1,0,1
    if
      modules[1] == 0
      and modules[2] == 0
      and modules[3] == 0
      and modules[4] == 0
      and modules[5] == 1
      and modules[6] == 0
      and modules[7] == 1
      and modules[8] == 1
      and modules[9] == 1
      and modules[10] == 0
      and modules[11] == 1
    then
      return true
    end
    return false
  end

  -- Horizontal
  for row = 0, size - 1 do
    for col = 0, size - 11 do
      local modules = {}
      for i = 0, 10 do
        modules[i + 1] = bm:get(row, col + i)
      end
      if check_pattern(modules) then
        penalty = penalty + 40
      end
    end
  end

  -- Vertical
  for col = 0, size - 1 do
    for row = 0, size - 11 do
      local modules = {}
      for i = 0, 10 do
        modules[i + 1] = bm:get(row + i, col)
      end
      if check_pattern(modules) then
        penalty = penalty + 40
      end
    end
  end

  return penalty
end

---Compute penalty score rule 4: dark/light module ratio deviation from 50%.
---Penalty = 10 * floor(|percentage_dark - 50| / 5)
---@param bm table QrBitmap
---@return number
function M.penalty_rule4(bm)
  local size = bm.size
  local dark_count = 0
  local total = size * size

  for row = 0, size - 1 do
    for col = 0, size - 1 do
      if bm:get(row, col) == 1 then
        dark_count = dark_count + 1
      end
    end
  end

  local percent = (dark_count * 100) / total
  local prev_multiple = math.floor(percent / 5) * 5
  local next_multiple = prev_multiple + 5
  local penalty = math.min(math.abs(prev_multiple - 50) / 5, math.abs(next_multiple - 50) / 5)
  return math.floor(penalty) * 10
end

---Compute total penalty score for a bitmap.
---@param bm table QrBitmap
---@return number
function M.total_penalty(bm)
  return M.penalty_rule1(bm) + M.penalty_rule2(bm) + M.penalty_rule3(bm) + M.penalty_rule4(bm)
end

---Select the best mask pattern (lowest penalty).
---@param bm table QrBitmap (with all function patterns placed, data placed, but no mask yet)
---@param place_format_fn fun(bm: table, mask: number) Function to write format info
---@return number Best mask pattern (0-7)
---@return table QrBitmap The final masked bitmap
function M.select_best(bm, place_format_fn)
  local best_mask = 0
  local best_penalty = math.huge
  local best_bm = nil

  for mask = 0, 7 do
    local candidate = bm:clone()
    M.apply(candidate, mask)
    place_format_fn(candidate, mask)
    local penalty = M.total_penalty(candidate)
    if penalty < best_penalty then
      best_penalty = penalty
      best_mask = mask
      best_bm = candidate
    end
  end

  return best_mask, best_bm
end

return M
