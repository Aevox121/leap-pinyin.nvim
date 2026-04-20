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
  end
end

-- Public entry point for shuangpin mode (also callable in pinyin mode but
-- usually unused there since native leap mappings work).
function M.leap(opts)
  return require("leap-pinyin.leap-hook").leap(opts)
end

return M
