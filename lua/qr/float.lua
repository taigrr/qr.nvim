---@brief [[
--- Floating window display for QR codes in Neovim.
--- Shows the rendered QR code in a centered floating window with backdrop.
---@brief ]]

local M = {}

---@class QrFloat
---@field buf number
---@field win number
---@field backdrop_buf? number
---@field backdrop_win? number
local Float = {}
Float.__index = Float

---Create and display a floating window with QR code lines.
---@param lines string[] Rendered QR code lines
---@param title? string Window title
---@return QrFloat
function Float.open(lines, title)
  local self = setmetatable({}, Float)

  -- Calculate dimensions
  local width = 0
  for _, line in ipairs(lines) do
    -- Use display width for Unicode characters
    local w = vim.fn.strdisplaywidth(line)
    if w > width then
      width = w
    end
  end
  local height = #lines

  -- Add padding
  width = width + 4
  height = height + 2

  -- Create buffer
  self.buf = vim.api.nvim_create_buf(false, true)

  -- Pad lines for centering
  local padded = { "" }
  for _, line in ipairs(lines) do
    padded[#padded + 1] = "  " .. line
  end
  padded[#padded + 1] = ""

  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, padded)

  -- Create backdrop
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  if normal.bg and vim.o.termguicolors then
    self.backdrop_buf = vim.api.nvim_create_buf(false, true)
    self.backdrop_win = vim.api.nvim_open_win(self.backdrop_buf, false, {
      relative = "editor",
      width = vim.o.columns,
      height = vim.o.lines,
      row = 0,
      col = 0,
      style = "minimal",
      focusable = false,
      zindex = 49,
    })
    vim.api.nvim_set_hl(0, "QrBackdrop", { bg = "#000000", default = true })
    vim.wo[self.backdrop_win].winhighlight = "Normal:QrBackdrop"
    vim.wo[self.backdrop_win].winblend = 60
    vim.bo[self.backdrop_buf].buftype = "nofile"
  end

  -- Open main window
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  self.win = vim.api.nvim_open_win(self.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = title and (" " .. title .. " ") or nil,
    title_pos = title and "center" or nil,
    zindex = 50,
  })

  -- Buffer settings
  vim.bo[self.buf].buftype = "nofile"
  vim.bo[self.buf].bufhidden = "wipe"
  vim.bo[self.buf].modifiable = false
  vim.bo[self.buf].filetype = "qr"

  -- Window settings
  vim.wo[self.win].cursorline = false
  vim.wo[self.win].number = false
  vim.wo[self.win].relativenumber = false
  vim.wo[self.win].signcolumn = "no"
  vim.wo[self.win].wrap = false

  -- Set highlight for white background
  vim.api.nvim_set_hl(0, "QrNormal", { fg = "#000000", bg = "#FFFFFF", default = true })
  vim.wo[self.win].winhighlight = "Normal:QrNormal,FloatBorder:FloatBorder"

  -- Close keymaps
  local function close()
    self:close()
  end
  vim.keymap.set("n", "q", close, { buffer = self.buf, nowait = true, desc = "Close QR" })
  vim.keymap.set("n", "<Esc>", close, { buffer = self.buf, nowait = true, desc = "Close QR" })

  -- Auto-close on WinClosed
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(self.win),
    once = true,
    callback = function()
      self:close()
    end,
  })

  return self
end

---Close the floating window and backdrop.
function Float:close()
  vim.schedule(function()
    if self.backdrop_win and vim.api.nvim_win_is_valid(self.backdrop_win) then
      vim.api.nvim_win_close(self.backdrop_win, true)
    end
    if self.backdrop_buf and vim.api.nvim_buf_is_valid(self.backdrop_buf) then
      vim.api.nvim_buf_delete(self.backdrop_buf, { force = true })
    end
    if self.win and vim.api.nvim_win_is_valid(self.win) then
      vim.api.nvim_win_close(self.win, true)
    end
    if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
      vim.api.nvim_buf_delete(self.buf, { force = true })
    end
  end)
end

M.Float = Float

return M
