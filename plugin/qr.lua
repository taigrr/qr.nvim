if vim.g.loaded_qr then
  return
end
vim.g.loaded_qr = true

require("qr").setup()
