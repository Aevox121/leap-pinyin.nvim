-- Integration smoke test: verify the leap-pinyin hook installs into leap
-- and extends the equivalence class lookup with Chinese chars.
--
-- Run with:
--   nvim --headless -c "luafile tests/hook_spec.lua" -c "qa!"

local script_dir = (debug.getinfo(1, "S").source:sub(2):match("(.*/)")) or "./"
package.path = table.concat({
  script_dir .. "../lua/?.lua",
  script_dir .. "../lua/?/init.lua",
  package.path,
}, ";")

local pass, fail = 0, 0

local function group(name) print("\n[" .. name .. "]") end
local function check(name, cond)
  if cond then
    pass = pass + 1
    print("  PASS " .. name)
  else
    fail = fail + 1
    print("  FAIL " .. name)
  end
end

-- ============================================================
group("setup with shuangpin (default) — should warn but install")
-- ============================================================
local lp = require("leap-pinyin")
lp.setup({})  -- default mode = shuangpin
check("opts.mode = 'shuangpin'", lp.opts.mode == "shuangpin")
check("opts.shuangpin_scheme = 'xiaohe'", lp.opts.shuangpin_scheme == "xiaohe")

-- ============================================================
group("hook extends opts.eqv_class_of for ASCII letters")
-- ============================================================
local opts = require("leap.opts")
local class_z = opts.default.eqv_class_of["z"]
check("eqv_class_of['z'] is a table", type(class_z) == "table")
check("class_z contains 'z' itself", class_z and class_z[1] == "z")

-- count hanzi entries
local hanzi_count = 0
local has_zhong = false
for _, c in ipairs(class_z or {}) do
  if c ~= "z" then
    hanzi_count = hanzi_count + 1
    if c == "中" then has_zhong = true end
  end
end
check("class_z contains 中 (z initial)", has_zhong)
check("class_z has many hanzi (>500)", hanzi_count > 500)
print(string.format("    [info] z-class hanzi count: %d", hanzi_count))

local class_h = opts.default.eqv_class_of["h"]
local has_hua = false
for _, c in ipairs(class_h or {}) do
  if c == "华" then has_hua = true; break end
end
check("class_h contains 华 (h initial)", has_hua)

-- 行 has initials "xh" — must appear in BOTH x-class and h-class
local class_x = opts.default.eqv_class_of["x"]
local x_has_xing, h_has_xing = false, false
for _, c in ipairs(class_x or {}) do
  if c == "行" then x_has_xing = true; break end
end
for _, c in ipairs(class_h or {}) do
  if c == "行" then h_has_xing = true; break end
end
check("行 appears in x-class (multi-pronunciation)", x_has_xing)
check("行 appears in h-class (multi-pronunciation)", h_has_xing)

-- ============================================================
group("eqv lookup falls back to original for non-letters")
-- ============================================================
-- ' ' should still be in its original whitespace class (default leap behavior)
local class_space = opts.default.eqv_class_of[" "]
check("space char still has its whitespace eqv class", type(class_space) == "table")

-- Random non-letter ASCII should return nil (unchanged behavior)
check("eqv_class_of['#'] is nil (untouched)", opts.default.eqv_class_of["#"] == nil)

-- ============================================================
group("uninstall restores original behavior")
-- ============================================================
require("leap-pinyin.leap-hook").uninstall()
local class_z_after = opts.default.eqv_class_of["z"]
check("after uninstall, z has no hanzi", class_z_after == nil)

-- Reinstall for further tests
require("leap-pinyin.leap-hook").install()

-- ============================================================
group("prepare_pattern integration — pattern includes Chinese chars")
-- ============================================================
-- We can't easily call leap's prepare_pattern (it's local), so we replicate
-- the relevant logic: build a vim regex char class from eqv lookup.
local function make_pattern_class(ch)
  local cls = opts.default.eqv_class_of[ch] or { ch }
  return table.concat(cls)
end

local pat_z = make_pattern_class("z")
check("pattern class for 'z' contains 中", pat_z:find("中", 1, true) ~= nil)
check("pattern class for 'h' contains 华", make_pattern_class("h"):find("华", 1, true) ~= nil)

-- ============================================================
group("end-to-end: vim regex /\\V[zclass][hclass]/ matches 中华")
-- ============================================================
-- Set up a buffer with test content
vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "hello world",
  "中华人民共和国",
  "测试 zhongwen",
  "这会儿",
})

local pat = "\\V\\[" .. make_pattern_class("z") .. "]\\[" .. make_pattern_class("h") .. "]"
vim.cmd("set ignorecase")
vim.fn.cursor(1, 1)

local matches = {}
local pos = vim.fn.searchpos(pat, "W")
local guard = 0
while pos[1] ~= 0 and guard < 20 do
  table.insert(matches, { pos[1], pos[2] })
  guard = guard + 1
  pos = vim.fn.searchpos(pat, "W")
end

print(string.format("    [info] found %d matches", #matches))
for _, m in ipairs(matches) do
  local line = vim.fn.getline(m[1])
  print(string.format("      line %d col %d: '%s'", m[1], m[2], line))
end

check("found at least 3 matches (中华 / zh-wen / 这会)", #matches >= 3)

-- Specifically verify 中华 is found at line 2
local found_zhonghua = false
for _, m in ipairs(matches) do
  if m[1] == 2 and m[2] == 1 then found_zhonghua = true; break end
end
check("中华 found at line 2 col 1", found_zhonghua)

-- Verify 这会 is found at line 4 col 1
local found_zhehui = false
for _, m in ipairs(matches) do
  if m[1] == 4 and m[2] == 1 then found_zhehui = true; break end
end
check("这会 found at line 4 col 1", found_zhehui)

-- Verify literal zh in 'zhongwen' is found at line 3
local found_literal = false
for _, m in ipairs(matches) do
  if m[1] == 3 then found_literal = true; break end
end
check("literal 'zh' found at line 3", found_literal)

-- ============================================================
print(string.format("\n=== %d passed, %d failed ===", pass, fail))
if fail > 0 then os.exit(1) end
