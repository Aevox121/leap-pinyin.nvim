-- Reproduce leap's real target collection flow end-to-end.

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
  "中华 china",
})
vim.cmd("set ignorecase smartcase")
vim.fn.cursor(1, 1)

-- Replicate leap.prepare_pattern(in1, in2, inputlen)
-- (can't import it directly since it's local, but we reproduce the logic)
local opts = require("leap.opts")

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

local function expand_to_eqv_collection(ch)
  local class = opts.default.eqv_class_of[ch] or { ch }
  return char_list_to_collection(class)
end

local function prepare_pattern(in1, in2)
  local prefix = "\\V"  -- no case flag; rely on ignorecase/smartcase
  local in1_expanded = expand_to_eqv_collection(in1)
  local pat1 = "\\[" .. in1_expanded .. "]"
  local _5epat1 = "\\[^" .. in1_expanded .. "]"
  local pat2 = "\\[" .. expand_to_eqv_collection(in2) .. "]"
  local pattern = pat1 .. pat2
  return prefix .. "\\(" .. pattern .. "\\)"
end

-- Call the real leap.search module
local search = require("leap.search")
local get_targets = search["get-targets"]

-- Pattern for "yh"
local pat_yh = prepare_pattern("y", "h")
print("=== pattern for 'yh' ===")
print(string.format("length: %d", #pat_yh))
print(string.format("first 100 chars: %s", pat_yh:sub(1, 100)))

local targets = get_targets(pat_yh, {
  ["backward?"] = false,
  windows = { vim.api.nvim_get_current_win() },
  inputlen = 2,
})
print(string.format("\n=== targets for 'yh' ==="))
if not targets then
  print("NO TARGETS (nil)")
else
  print(string.format("%d targets", #targets))
  for i, t in ipairs(targets) do
    print(string.format("  [%d] line %d col %d chars=%q,%q",
      i, t.pos[1], t.pos[2], t.chars[1], t.chars[2] or ""))
  end
end

-- Pattern for "qp"
print("\n=== pattern for 'qp' ===")
local pat_qp = prepare_pattern("q", "p")
local targets2 = get_targets(pat_qp, {
  ["backward?"] = false,
  windows = { vim.api.nvim_get_current_win() },
  inputlen = 2,
})
if not targets2 then
  print("NO TARGETS (nil)")
else
  print(string.format("%d targets", #targets2))
  for i, t in ipairs(targets2) do
    print(string.format("  [%d] line %d col %d chars=%q,%q",
      i, t.pos[1], t.pos[2], t.chars[1], t.chars[2] or ""))
  end
end
