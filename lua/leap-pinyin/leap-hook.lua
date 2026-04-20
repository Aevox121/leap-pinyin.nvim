-- Hook into leap.nvim by extending its character equivalence lookup.
--
-- leap builds its 2-char search pattern by:
--   pattern = "\[" .. expand_to_eqv_collection(in1) .. "]"
--          .. "\[" .. expand_to_eqv_collection(in2) .. "]"
-- where expand_to_eqv_collection(ch) returns opts.eqv_class_of[ch] (a list of
-- equivalent chars) joined into a Vim regex char class.
--
-- Strategy for **full-pinyin first-letter mode**:
--   Replace opts.default.eqv_class_of so that for each lowercase ASCII letter
--   `c`, the lookup returns {c, ...all Chinese chars whose pinyin initial set
--   contains c}. Vim's ignorecase handles the upper/lower case match.
--
-- Strategy for **shuangpin mode**: TODO(M4) — single Chinese char encodes 2
-- keys, requiring a different pattern shape. Falls back to pinyin mode for now.

local M = {}

local installed = false
local original_eqv_class_of = nil
local reverse_index_cache = nil

local function build_reverse_index()
  if reverse_index_cache then return reverse_index_cache end
  local idx = {}
  for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
    idx[c] = { c }
  end
  local initials_data = require("leap-pinyin.data.initials")
  for hanzi, initials in pairs(initials_data) do
    for i = 1, #initials do
      local c = initials:sub(i, i)
      if idx[c] then
        table.insert(idx[c], hanzi)
      end
    end
  end
  reverse_index_cache = idx
  return idx
end

local function install_pinyin_hook()
  -- Force leap.main to load so its init() runs and populates eqv_class_of.
  -- Without this, opts.default has a recursive __index metatable that loops
  -- forever on missing keys.
  require("leap.main")

  local opts = require("leap.opts")
  local reverse_index = build_reverse_index()
  original_eqv_class_of = opts.default.eqv_class_of

  opts.default.eqv_class_of = setmetatable({}, {
    __index = function(_, ch)
      local hit = reverse_index[ch]
      if hit then return hit end
      if original_eqv_class_of then
        return original_eqv_class_of[ch]
      end
      return nil
    end,
  })
end

function M.install()
  if installed then return end
  local plugin_opts = require("leap-pinyin").opts
  if plugin_opts.mode == "shuangpin" then
    vim.notify(
      "[leap-pinyin] shuangpin mode is M4 work-in-progress; using pinyin first-letter mode for now.",
      vim.log.levels.WARN
    )
  end
  -- M3: install pinyin first-letter mode regardless of config
  install_pinyin_hook()
  installed = true
end

function M.uninstall()
  if not installed then return end
  local opts = require("leap.opts")
  opts.default.eqv_class_of = original_eqv_class_of
  original_eqv_class_of = nil
  installed = false
end

return M
