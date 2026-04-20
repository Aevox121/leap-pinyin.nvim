-- Core matching logic: decide whether positions in the buffer match
-- the user's 2-character input, considering Chinese pinyin/shuangpin.
--
-- Two callable matchers:
--
--   M.match_initials(c1, c2, input)
--     Full-pinyin first-letter mode. `c1` and `c2` are adjacent characters
--     (UTF-8 strings). `input` is a 2-char ASCII string.
--     Each character is reduced to its "initial key set":
--       - ASCII char: itself, lowercased
--       - Chinese char: pinyin initials from dict (e.g. "行" -> "xh")
--       - Other multi-byte: literal match only
--     Returns true iff input[1] is in initials(c1) and input[2] is in initials(c2).
--
--   M.match_shuangpin(c, input)
--     Xiaohe shuangpin mode. `c` is a single Chinese char (UTF-8 string).
--     `input` is a 2-char ASCII string.
--     Returns true iff any of c's shuangpin codes equals input (case-insensitive).
--     Returns false for non-Chinese chars (literal matching is leap's job).

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

-- Compute the set of "initial keys" for a single character.
-- Returns a string where each byte is a candidate initial key.
local function initial_set(ch)
  if #ch == 1 then
    -- Single-byte ASCII: itself, lowercased
    return string.lower(ch)
  end
  -- Multi-byte: try Chinese pinyin initials, else fall back to literal char
  local pyi = load_initials()[ch]
  if pyi then
    return pyi
  end
  return ch
end

M._initial_set = initial_set  -- exposed for tests

function M.match_initials(c1, c2, input)
  if #input < 2 then
    return false
  end
  local i1 = string.lower(string.sub(input, 1, 1))
  local i2 = string.lower(string.sub(input, 2, 2))
  local s1 = initial_set(c1)
  local s2 = initial_set(c2)
  return s1:find(i1, 1, true) ~= nil and s2:find(i2, 1, true) ~= nil
end

function M.match_shuangpin(c, input)
  if #c == 1 then
    -- Single-byte ASCII can never be a shuangpin target (1 char != 2 keys)
    return false
  end
  local codes = load_shuangpin()[c]
  if not codes then
    return false
  end
  local lower_input = string.lower(input)
  for _, code in ipairs(codes) do
    if code == lower_input then
      return true
    end
  end
  return false
end

return M
