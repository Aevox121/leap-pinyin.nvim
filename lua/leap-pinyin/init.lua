-- leap-pinyin.nvim — Chinese pinyin search support for leap.nvim
--
-- Default config:
--   mode = "shuangpin"   -- "pinyin" | "shuangpin"
--   shuangpin_scheme = "xiaohe"
--   enabled = true
--
-- Pinyin mode: extends leap's char equivalence so that typing 'zh' matches
--              both literal "zh" and any pair of Chinese chars whose pinyin
--              initials are 'z' and 'h'. User keeps their normal `s` mapping
--              to <Plug>(leap-forward).
--
-- Shuangpin mode: provides <Plug>(leap-pinyin-forward) /
--                 <Plug>(leap-pinyin-backward) which read 2 keys, then jump
--                 to single Chinese chars whose xiaohe shuangpin code matches
--                 (literal 2-char ASCII matches included).
--                 User maps `s` / `S` to these <Plug> targets.

local M = {}

local default_opts = {
  mode = "shuangpin",
  shuangpin_scheme = "xiaohe",
  enabled = true,
}

M.opts = vim.deepcopy(default_opts)

-- LazyVim's plugin load order causes leap to init() before the colorscheme
-- defines LeapBackdrop. Without that highlight group, leap skips registering
-- its backdrop autocmd entirely, so the buffer never dims during a search.
-- We reinforce by (1) providing a default LeapBackdrop and (2) re-running
-- leap's highlight init now and again on every ColorScheme change.
local function ensure_backdrop()
  -- Use an explicit dim color instead of `link = Comment` — Comment on many
  -- colorschemes (including catppuccin) is too close to normal text to be
  -- visually distinguishable as dimming. If the current LeapBackdrop is
  -- undefined or is our own previous Comment-link fallback, force-replace
  -- with an explicit grey. A real colorscheme leap integration (with fg/bg
  -- of its own) will NOT be overridden.
  local existing = vim.api.nvim_get_hl(0, { name = "LeapBackdrop" })
  local is_fallback = vim.tbl_isempty(existing) or existing.link == "Comment"
  if is_fallback then
    local is_dark = vim.o.background == "dark"
    vim.api.nvim_set_hl(0, "LeapBackdrop", {
      fg = is_dark and "#585b70" or "#9ca0b0",
    })
  end
  pcall(function()
    require("leap.highlight"):init()
  end)
end

function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend("force", default_opts, user_opts or {})

  if M.opts.mode ~= "pinyin" and M.opts.mode ~= "shuangpin" then
    error(string.format("leap-pinyin: invalid mode %q (expected 'pinyin' or 'shuangpin')", M.opts.mode))
  end
  if M.opts.shuangpin_scheme ~= "xiaohe" then
    error(string.format("leap-pinyin: only 'xiaohe' shuangpin_scheme is supported (got %q)", M.opts.shuangpin_scheme))
  end

  if M.opts.enabled then
    require("leap-pinyin.leap-hook").install()

    ensure_backdrop()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("LeapPinyinBackdrop", { clear = true }),
      callback = ensure_backdrop,
    })
  end
end

-- Public entry point for shuangpin mode (also callable in pinyin mode but
-- usually unused there since native leap mappings work).
function M.leap(opts)
  return require("leap-pinyin.leap-hook").leap(opts)
end

return M
