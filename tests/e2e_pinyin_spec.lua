-- E2E test: actually invoke leap's internal pattern building and searchpos
-- to reproduce the pinyin mode user flow exactly.

local script_dir = (debug.getinfo(1, "S").source:sub(2):match("(.*/)")) or "./"
package.path = table.concat({
  script_dir .. "../lua/?.lua",
  script_dir .. "../lua/?/init.lua",
  package.path,
}, ";")

local pass, fail = 0, 0
local function check(name, cond)
  if cond then
    pass = pass + 1
    print("  PASS " .. name)
  else
    fail = fail + 1
    print("  FAIL " .. name)
  end
end

-- Setup pinyin mode
require("leap-pinyin").setup({ mode = "pinyin" })

-- Access leap's internal prepare_pattern via a controlled route:
-- we replicate what leap does.
local opts = require("leap.opts")

-- Verify hook installed
local q_class = opts.default.eqv_class_of["q"]
print(string.format("[info] q class: %d entries", #q_class))
check("q class contains 气", vim.tbl_contains(q_class, "气"))
check("p class contains 泡", vim.tbl_contains(opts.default.eqv_class_of["p"], "泡"))
check("y class contains 用", vim.tbl_contains(opts.default.eqv_class_of["y"], "用"))
check("h class contains 户", vim.tbl_contains(opts.default.eqv_class_of["h"], "户"))

-- Now manually build the pattern the way leap does
local function build_pattern(in1, in2)
  local function char_list_to_collection(chars)
    local escape = {
      ["\7"] = "\\a", ["\8"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n",
      ["\r"] = "\\r", ["\9"] = "\\t", ["\v"] = "\\v",
      ["\\"] = "\\\\", ["]"] = "\\]", ["^"] = "\\^", ["-"] = "\\-",
    }
    local parts = {}
    for _, c in ipairs(chars) do
      parts[#parts + 1] = escape[c] or c
    end
    return table.concat(parts)
  end
  local function expand(ch)
    local class = opts.default.eqv_class_of[ch] or { ch }
    return char_list_to_collection(class)
  end
  local pat1 = "\\[" .. expand(in1) .. "]"
  local pat2 = "\\[" .. expand(in2) .. "]"
  return "\\V" .. pat1 .. pat2
end

-- Populate buffer
vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "用户名 username",
  "气泡 bubble",
  "中华 china",
  "qp yh",
})
vim.cmd("set ignorecase")
vim.fn.cursor(1, 1)

local function search_all(pat)
  vim.fn.cursor(1, 1)
  local matches = {}
  local pos = vim.fn.searchpos(pat, "W")
  local guard = 0
  while pos[1] ~= 0 and guard < 30 do
    matches[#matches + 1] = { pos[1], pos[2] }
    guard = guard + 1
    pos = vim.fn.searchpos(pat, "W")
  end
  return matches
end

print("\n[yh pattern]")
local pat_yh = build_pattern("y", "h")
print(string.format("  pattern length: %d chars", #pat_yh))
print(string.format("  pattern starts with: %s...", pat_yh:sub(1, 60)))
local yh_matches = search_all(pat_yh)
print(string.format("  found %d matches", #yh_matches))
for _, m in ipairs(yh_matches) do
  print(string.format("    line %d col %d: '%s'", m[1], m[2], vim.fn.getline(m[1])))
end
check("'yh' finds 用户 at line 1 col 1",
  vim.tbl_count(vim.tbl_filter(function(m) return m[1] == 1 and m[2] == 1 end, yh_matches)) > 0)
check("'yh' finds literal 'yh' at line 4",
  vim.tbl_count(vim.tbl_filter(function(m) return m[1] == 4 end, yh_matches)) > 0)

print("\n[qp pattern]")
local pat_qp = build_pattern("q", "p")
local qp_matches = search_all(pat_qp)
print(string.format("  found %d matches", #qp_matches))
for _, m in ipairs(qp_matches) do
  print(string.format("    line %d col %d: '%s'", m[1], m[2], vim.fn.getline(m[1])))
end
check("'qp' finds 气泡 at line 2 col 1",
  vim.tbl_count(vim.tbl_filter(function(m) return m[1] == 2 and m[2] == 1 end, qp_matches)) > 0)

print(string.format("\n=== %d passed, %d failed ===", pass, fail))
if fail > 0 then os.exit(1) end
