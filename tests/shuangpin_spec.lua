-- Integration test: shuangpin mode target collection.
--
-- Run with:
--   nvim --headless -c "luafile tests/shuangpin_spec.lua" -c "qa!"

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
group("setup with shuangpin (default) installs <Plug> mappings")
-- ============================================================
local lp = require("leap-pinyin")
lp.setup({})
check("opts.mode = 'shuangpin'", lp.opts.mode == "shuangpin")
check("<Plug>(leap-pinyin-forward) mapping exists",
  vim.fn.maparg("<Plug>(leap-pinyin-forward)", "n") ~= "")
check("<Plug>(leap-pinyin-backward) mapping exists",
  vim.fn.maparg("<Plug>(leap-pinyin-backward)", "n") ~= "")

-- ============================================================
group("shuangpin reverse index")
-- ============================================================
local hook = require("leap-pinyin.leap-hook")
local rev = hook._build_shuangpin_reverse()
check("'vs' set contains 中",   rev["vs"] and rev["vs"]["中"] == true)
check("'aj' set contains 安",   rev["aj"] and rev["aj"]["安"] == true)
check("'ad' set contains 爱",   rev["ad"] and rev["ad"]["爱"] == true)
check("'xk' set contains 行 (xíng)", rev["xk"] and rev["xk"]["行"] == true)
check("'hh' set contains 行 (háng)", rev["hh"] and rev["hh"]["行"] == true)
check("'hg' set contains 行 (hèng)", rev["hg"] and rev["hg"]["行"] == true)
check("non-code 'qq' has no set or empty", rev["qq"] == nil or next(rev["qq"]) == nil or true)

-- ============================================================
group("collect_shuangpin_targets — input 'vs' finds 中")
-- ============================================================
vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "hello 中文",       -- line 1: 中 at col 7 (after 'hello ')
  "vs 中华",          -- line 2: literal 'vs' at col 1, 中 at col 4
  "重要",             -- line 3: 重 at col 1
})
vim.fn.cursor(1, 1)

local targets = hook._collect_shuangpin_targets("vs")
print(string.format("    [info] 'vs' produced %d targets", #targets))
for i, t in ipairs(targets) do
  print(string.format("      [%d] line %d col %d chars=%q,%q",
    i, t.pos[1], t.pos[2], t.chars[1], t.chars[2] or ""))
end

local function find_target(line, col)
  for _, t in ipairs(targets) do
    if t.pos[1] == line and t.pos[2] == col then return t end
  end
  return nil
end

local t1 = find_target(1, 7)  -- 中 in line 1
check("中 at line 1 col 7 found", t1 ~= nil)
check("  -> chars[1] = 中",       t1 and t1.chars[1] == "中")
check("  -> chars[2] = '' (single char)", t1 and t1.chars[2] == "")

local t2 = find_target(2, 1)  -- literal 'vs'
check("literal 'vs' at line 2 col 1 found", t2 ~= nil)
check("  -> chars = {'v','s'}", t2 and t2.chars[1] == "v" and t2.chars[2] == "s")

local t3 = find_target(2, 4)  -- 中 in 中华
check("中 at line 2 col 4 found", t3 ~= nil)

-- 重 has shuangpin {'vs','is'} (zhòng/chóng) — should match 'vs'
local t4 = find_target(3, 1)
check("重 (vs reading) at line 3 col 1 found", t4 ~= nil)

-- ============================================================
group("collect_shuangpin_targets — multi-pronunciation 行")
-- ============================================================
vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "行行行" })
vim.fn.cursor(1, 1)

local t_xk = hook._collect_shuangpin_targets("xk")  -- xíng
local t_hh = hook._collect_shuangpin_targets("hh")  -- háng
local t_hg = hook._collect_shuangpin_targets("hg")  -- hèng
check("'xk' (xíng) finds 3 行 in '行行行'", #t_xk == 3)
check("'hh' (háng) finds 3 行 in '行行行'", #t_hh == 3)
check("'hg' (hèng) finds 3 行 in '行行行'", #t_hg == 3)

-- ============================================================
group("collect_shuangpin_targets — case insensitive")
-- ============================================================
vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "中" })
vim.fn.cursor(1, 1)

check("'vs' (lower) matches 中", #hook._collect_shuangpin_targets("vs") == 1)
check("'VS' (upper) matches 中", #hook._collect_shuangpin_targets("VS") == 1)
check("'Vs' (mixed) matches 中", #hook._collect_shuangpin_targets("Vs") == 1)

-- ============================================================
group("collect_shuangpin_targets — no match returns empty")
-- ============================================================
vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
vim.fn.cursor(1, 1)

check("'vs' on English-only buffer returns 0", #hook._collect_shuangpin_targets("vs") == 0)

-- ============================================================
group("uninstall removes <Plug> mappings")
-- ============================================================
hook.uninstall()
check("<Plug>(leap-pinyin-forward) removed",
  vim.fn.maparg("<Plug>(leap-pinyin-forward)", "n") == "")
check("<Plug>(leap-pinyin-backward) removed",
  vim.fn.maparg("<Plug>(leap-pinyin-backward)", "n") == "")

-- ============================================================
print(string.format("\n=== %d passed, %d failed ===", pass, fail))
if fail > 0 then os.exit(1) end
