-- Core matching logic: decide whether a position in the buffer matches
-- the user's 2-character input, considering Chinese pinyin/shuangpin.
--
-- Public API (to be implemented in M2):
--
--   M.match_initials(c1, c2, input)
--     Full-pinyin first-letter mode: does the pair (c1, c2) match the 2-char
--     input when Chinese chars are reduced to their pinyin initial set?
--     Returns boolean.
--
--   M.match_shuangpin(c, input)
--     Xiaohe shuangpin mode: does the single Chinese char `c` match the 2-char
--     input when `c` is encoded in shuangpin?
--     Returns boolean.
--
--   M.get_initials(ch) -> string | nil
--     Get the pinyin-initial set for a Chinese char, e.g. "行" -> "xh".
--     Returns nil for non-Chinese chars.
--
--   M.get_shuangpin(ch) -> string[] | nil
--     Get the shuangpin code list for a Chinese char, e.g. "行" -> {"xk","hh","hg"}.
--     Returns nil for non-Chinese chars.

local M = {}

local initials_data = nil
local shuangpin_data = nil

local function load_initials()
  if initials_data == nil then
    initials_data = require("leap-pinyin.data.initials")
  end
  return initials_data
end

local function load_shuangpin()
  if shuangpin_data == nil then
    shuangpin_data = require("leap-pinyin.data.shuangpin")
  end
  return shuangpin_data
end

function M.get_initials(ch)
  return load_initials()[ch]
end

function M.get_shuangpin(ch)
  return load_shuangpin()[ch]
end

-- TODO(M2): implement match_initials / match_shuangpin with case-insensitive
--           input, mixed Chinese+ASCII handling, and multi-pronunciation fallback.

return M
