-- Retest with cursor NOT at the target position.

local script_dir = (debug.getinfo(1, "S").source:sub(2):match("(.*/)")) or "./"
package.path = table.concat({
  script_dir .. "../lua/?.lua",
  script_dir .. "../lua/?/init.lua",
  package.path,
}, ";")

require("leap-pinyin").setup({ mode = "pinyin" })

vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "some text here",
  "用户 user info",
  "气泡 bubble",
  "中华 china",
  "another line",
})

local opts = require("leap.opts")
local function char_list_to_collection(chars)
  local escape = {
    ["\7"]="\\a",["\8"]="\\b",["\f"]="\\f",["\n"]="\\n",["\r"]="\\r",
    ["\9"]="\\t",["\v"]="\\v",["\\"]="\\\\",["]"]="\\]",["^"]="\\^",["-"]="\\-",
  }
  local parts = {}
  for _, c in ipairs(chars) do parts[#parts+1] = escape[c] or c end
  return table.concat(parts)
end
local function prepare_pattern(in1, in2)
  local p1 = "\\[" .. char_list_to_collection(opts.default.eqv_class_of[in1] or {in1}) .. "]"
  local p2 = "\\[" .. char_list_to_collection(opts.default.eqv_class_of[in2] or {in2}) .. "]"
  return "\\V\\(" .. p1 .. p2 .. "\\)"
end

local search = require("leap.search")
local get_targets = search["get-targets"]

-- Put cursor on line 1 (NOT where 用户 is)
vim.fn.cursor(1, 1)
local targets = get_targets(prepare_pattern("y", "h"), {
  ["backward?"] = false,
  windows = { vim.api.nvim_get_current_win() },
  inputlen = 2,
})
print("=== yh, cursor at line 1 ===")
if not targets then
  print("NO TARGETS")
else
  print(string.format("%d targets:", #targets))
  for i, t in ipairs(targets) do
    print(string.format("  line %d col %d chars=%q,%q", t.pos[1], t.pos[2], t.chars[1], t.chars[2]))
  end
end

-- Put cursor on line 5 (away from 用户 at line 2)
vim.fn.cursor(5, 1)
local targets2 = get_targets(prepare_pattern("y", "h"), {
  ["backward?"] = true,  -- search backward from line 5
  windows = { vim.api.nvim_get_current_win() },
  inputlen = 2,
})
print("\n=== yh backward from line 5 ===")
if not targets2 then
  print("NO TARGETS")
else
  print(string.format("%d targets:", #targets2))
  for i, t in ipairs(targets2) do
    print(string.format("  line %d col %d chars=%q,%q", t.pos[1], t.pos[2], t.chars[1], t.chars[2]))
  end
end
