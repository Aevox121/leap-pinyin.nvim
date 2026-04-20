-- Re-test with 'Wc' flag (include cursor position, as leap does on first iter)

vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "用户名",
  "气泡",
})

local script_dir = (debug.getinfo(1, "S").source:sub(2):match("(.*/)")) or "./"
package.path = table.concat({
  script_dir .. "../lua/?.lua",
  script_dir .. "../lua/?/init.lua",
  package.path,
}, ";")
require("leap-pinyin").setup({ mode = "pinyin" })
local opts = require("leap.opts")

-- Build full y+h class
local y_class = table.concat(opts.default.eqv_class_of["y"])
local h_class = table.concat(opts.default.eqv_class_of["h"])
local pat_yh_full = "\\V\\[" .. y_class .. "]\\[" .. h_class .. "]"

vim.fn.cursor(1, 1)
print("1. 'Wc' (include cursor), minimal [用][户]:",
  vim.inspect(vim.fn.searchpos("\\V\\[用]\\[户]", "Wc")))

vim.fn.cursor(1, 1)
print("2. 'Wc' full y-class+h-class:",
  vim.inspect(vim.fn.searchpos(pat_yh_full, "Wc")))

-- Leap uses these flags; check what happens from a different starting position
vim.fn.cursor(2, 1)
print("3. 'Wc' from line 2,1, minimal [用][户]:",
  vim.inspect(vim.fn.searchpos("\\V\\[用]\\[户]", "Wc")))
-- Oh we're past 用户, so this would need backward
vim.fn.cursor(2, 1)
print("3b. 'bWc' backward from 2,1, minimal [用][户]:",
  vim.inspect(vim.fn.searchpos("\\V\\[用]\\[户]", "bWc")))

-- And: what about searching forward from cursor 1,1 using leap's "w0" approach?
-- leap sets cursor to (w0, 1) first
vim.fn.cursor(vim.fn.line("w0"), 1)
print("4. from w0,1 with 'Wc' minimal [用][户]:",
  vim.inspect(vim.fn.searchpos("\\V\\[用]\\[户]", "Wc")))

vim.fn.cursor(vim.fn.line("w0"), 1)
print("5. from w0,1 with 'Wc' full y+h class:",
  vim.inspect(vim.fn.searchpos(pat_yh_full, "Wc")))
