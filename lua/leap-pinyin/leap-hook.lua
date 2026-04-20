-- Hook point: inject pinyin matching into leap's target collection phase.
--
-- Strategy (to be implemented in M3/M4):
--   1. Wrap or monkey-patch leap's `search.get-match-positions` so that in
--      addition to literal byte-pattern matches, we also produce matches based
--      on pinyin initials (pinyin mode) or shuangpin codes (shuangpin mode).
--   2. Returned targets include `source` = "pinyin" | "shuangpin" | "literal"
--      and a `width` field (display columns) to support the variable-width
--      target needed by single-char shuangpin hits.
--   3. Label assignment stays native; leap sorts targets by distance, so
--      Chinese and English targets share the label pool naturally.

local M = {}

local installed = false

function M.install()
  if installed then return end
  installed = true
  -- TODO(M3): patch leap to use our extended get-match-positions
end

function M.uninstall()
  installed = false
  -- TODO(M3): restore leap's original get-match-positions
end

return M
