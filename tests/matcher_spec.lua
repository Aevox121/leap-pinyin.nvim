-- Standalone unit tests for leap-pinyin.pinyin.matcher.
--
-- Run with:
--   nvim --headless -c "luafile tests/matcher_spec.lua" -c "qa!"
-- or:
--   lua tests/matcher_spec.lua          (if lua/luajit is on PATH)
--
-- No external test framework dependency.

-- Set up package.path so requires resolve from project root
local script_dir = (debug.getinfo(1, "S").source:sub(2):match("(.*/)")) or "./"
package.path = table.concat({
  script_dir .. "../lua/?.lua",
  script_dir .. "../lua/?/init.lua",
  package.path,
}, ";")

local matcher = require("leap-pinyin.pinyin.matcher")

local pass, fail = 0, 0
local current_group = ""

local function group(name)
  current_group = name
  print("\n[" .. name .. "]")
end

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
group("get_initials / get_shuangpin sanity")
-- ============================================================
check("中 initials = 'z'",       matcher.get_initials("中") == "z")
check("行 initials = 'xh'",      matcher.get_initials("行") == "xh")
check("华 initials = 'h'",       matcher.get_initials("华") == "h")
check("中 shuangpin = {'vs'}",   matcher.get_shuangpin("中")[1] == "vs")
check("圆 shuangpin = {'yr'}",   matcher.get_shuangpin("圆")[1] == "yr")
check("ASCII 'a' has no initials entry", matcher.get_initials("a") == nil)
check("ASCII 'a' has no shuangpin entry", matcher.get_shuangpin("a") == nil)

-- ============================================================
group("initial_set helper")
-- ============================================================
check("ASCII 'a' -> 'a'",       matcher._initial_set("a") == "a")
check("ASCII 'A' -> 'a' (lower)", matcher._initial_set("A") == "a")
check("ASCII 'Z' -> 'z'",       matcher._initial_set("Z") == "z")
check("中 -> 'z'",              matcher._initial_set("中") == "z")
check("行 -> 'xh' (multi-pinyin)", matcher._initial_set("行") == "xh")

-- ============================================================
group("match_initials: pure ASCII (leap baseline)")
-- ============================================================
check("'he' matches h+e",        matcher.match_initials("h", "e", "he"))
check("'he' matches H+e (case)", matcher.match_initials("H", "e", "he"))
check("'he' matches h+E (case)", matcher.match_initials("h", "E", "he"))
check("'HE' matches h+e (input case)", matcher.match_initials("h", "e", "HE"))
check("'he' does NOT match h+x", not matcher.match_initials("h", "x", "he"))

-- ============================================================
group("match_initials: pure Chinese")
-- ============================================================
check("'zh' matches 中+华",      matcher.match_initials("中", "华", "zh"))
check("'zh' matches 这+会",      matcher.match_initials("这", "会", "zh"))
check("'zh' does NOT match 你+好", not matcher.match_initials("你", "好", "zh"))

-- ============================================================
group("match_initials: mixed Chinese+ASCII")
-- ============================================================
check("'zh' matches 中+h",       matcher.match_initials("中", "h", "zh"))
check("'zh' matches z+华",       matcher.match_initials("z", "华", "zh"))
check("'zh' matches z+h literal", matcher.match_initials("z", "h", "zh"))

-- ============================================================
group("match_initials: multi-pronunciation char (行=xh)")
-- ============================================================
check("'xh' matches 行+行 (xh+xh)",   matcher.match_initials("行", "行", "xh"))
check("'xx' matches 行+行 (x in xh)", matcher.match_initials("行", "行", "xx"))
check("'hh' matches 行+行 (h in xh)", matcher.match_initials("行", "行", "hh"))
check("'xs' does NOT match 行+行",    not matcher.match_initials("行", "行", "xs"))

-- ============================================================
group("match_shuangpin: Chinese single-char hits")
-- ============================================================
check("'vs' matches 中",           matcher.match_shuangpin("中", "vs"))
check("'VS' matches 中 (case)",    matcher.match_shuangpin("中", "VS"))
check("'yr' matches 圆",           matcher.match_shuangpin("圆", "yr"))
check("'aj' matches 安 (zero-init)", matcher.match_shuangpin("安", "aj"))
check("'ad' matches 爱 (zero-init)", matcher.match_shuangpin("爱", "ad"))
check("'xk' matches 行 (xíng)",     matcher.match_shuangpin("行", "xk"))
check("'hh' matches 行 (háng)",     matcher.match_shuangpin("行", "hh"))
check("'hg' matches 行 (hèng)",     matcher.match_shuangpin("行", "hg"))
check("'zz' does NOT match 中",    not matcher.match_shuangpin("中", "zz"))

-- ============================================================
group("match_shuangpin: ASCII never matches (literal is leap's job)")
-- ============================================================
check("'vs' does NOT match 'v' ASCII", not matcher.match_shuangpin("v", "vs"))
check("'aa' does NOT match 'a' ASCII", not matcher.match_shuangpin("a", "aa"))

-- ============================================================
group("match_initials: short input rejected")
-- ============================================================
check("input '' rejected",       not matcher.match_initials("中", "华", ""))
check("input 'z' rejected",      not matcher.match_initials("中", "华", "z"))

-- ============================================================
print(string.format("\n=== %d passed, %d failed ===", pass, fail))
if fail > 0 then
  os.exit(1)
end
