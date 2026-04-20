local script_dir = (debug.getinfo(1, "S").source:sub(2):match("(.*/)")) or "./"
package.path = table.concat({
  script_dir .. "../lua/?.lua",
  script_dir .. "../lua/?/init.lua",
  package.path,
}, ";")

require("leap-pinyin").setup({ mode = "pinyin" })
vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "用户 user",
  "气泡 bubble",
})

local opts = require("leap.opts")
local y_class = table.concat(opts.default.eqv_class_of["y"])
local h_class = table.concat(opts.default.eqv_class_of["h"])
local q_class = table.concat(opts.default.eqv_class_of["q"])
local p_class = table.concat(opts.default.eqv_class_of["p"])

print(string.format("y_class len: %d bytes, h_class len: %d bytes", #y_class, #h_class))
print(string.format("q_class len: %d bytes, p_class len: %d bytes", #q_class, #p_class))

-- Test 1: naked class concatenation
vim.fn.cursor(1, 1)
local p1 = "\\V\\[" .. y_class .. "]\\[" .. h_class .. "]"
print("\n1. naked yh, 'Wc':", vim.inspect(vim.fn.searchpos(p1, "Wc")))

vim.fn.cursor(2, 1)
local pq = "\\V\\[" .. q_class .. "]\\[" .. p_class .. "]"
print("2. naked qp (line 2) 'Wc':", vim.inspect(vim.fn.searchpos(pq, "Wc")))

-- Test 3: with leap's \( \) grouping
vim.fn.cursor(1, 1)
local p3 = "\\V\\(\\[" .. y_class .. "]\\[" .. h_class .. "]\\)"
print("3. grouped yh 'Wc':", vim.inspect(vim.fn.searchpos(p3, "Wc")))

-- Test 4: does truncating the y class help?
vim.fn.cursor(1, 1)
local y_truncated = y_class:sub(1, 1000)
local p4 = "\\V\\[" .. y_truncated .. "]\\[" .. h_class .. "]"
print(string.format("4. truncated y(1000 bytes)+h, 'Wc': "), vim.inspect(vim.fn.searchpos(p4, "Wc")))

vim.fn.cursor(1, 1)
local y_tiny = "y用"  -- just y and 用
local p5 = "\\V\\[" .. y_tiny .. "]\\[" .. h_class .. "]"
print("5. y={y,用} + full h 'Wc':", vim.inspect(vim.fn.searchpos(p5, "Wc")))

vim.fn.cursor(1, 1)
local h_tiny = "h户"
local p6 = "\\V\\[" .. y_class .. "]\\[" .. h_tiny .. "]"
print("6. full y + h={h,户} 'Wc':", vim.inspect(vim.fn.searchpos(p6, "Wc")))

-- Test 7: scan for the FIRST position in y class that actually breaks matching.
-- Binary search: if half-class works, try larger.
vim.fn.cursor(1, 1)
local half = y_class:sub(1, math.floor(#y_class/2))
local p7 = "\\V\\[" .. half .. "]\\[" .. h_class .. "]"
print(string.format("7. y first half (%d bytes) 'Wc': ", #half), vim.inspect(vim.fn.searchpos(p7, "Wc")))

vim.fn.cursor(1, 1)
local second_half = "y" .. y_class:sub(math.floor(#y_class/2) + 1)
local p8 = "\\V\\[" .. second_half .. "]\\[" .. h_class .. "]"
print(string.format("8. y second half (%d bytes) 'Wc': ", #second_half), vim.inspect(vim.fn.searchpos(p8, "Wc")))

-- Test 9: find 用's byte position in y_class
local yong_start = y_class:find("用", 1, true)
print(string.format("\n9. 用 appears in y_class at byte %s of %d", tostring(yong_start), #y_class))

-- Test 10: exactly as leap calls it — with stopline arg
print("\n10. full yh with stopline=w$:")
vim.fn.cursor(1, 1)
local p_full = "\\V\\[" .. y_class .. "]\\[" .. h_class .. "]"
local stopline = vim.fn.line("w$")
print(string.format("   stopline: %d", stopline))
print("   searchpos result:", vim.inspect(vim.fn.searchpos(p_full, "Wc", stopline)))

-- Test 11: same but with grouped pattern
vim.fn.cursor(1, 1)
local p_group = "\\V\\(\\[" .. y_class .. "]\\[" .. h_class .. "]\\)"
print("11. grouped yh with stopline=w$:", vim.inspect(vim.fn.searchpos(p_group, "Wc", stopline)))

-- Test 12: does cpo setting change anything? leap removes 'c' from cpo
vim.opt.cpo:remove("c")
vim.fn.cursor(1, 1)
print("12. after cpo-=c, yh:", vim.inspect(vim.fn.searchpos(p_full, "Wc", stopline)))

-- Test 13: reproduce with the "w0" cursor set that leap does
vim.fn.cursor(vim.fn.line("w0"), 1)
print("13. from w0,1:", vim.inspect(vim.fn.searchpos(p_full, "Wc", stopline)))
