-- leap-pinyin.nvim — Chinese pinyin search support for leap.nvim
--
-- Default config:
--   mode = "shuangpin"   -- "pinyin" | "shuangpin"
--   shuangpin_scheme = "xiaohe"
--   enabled = true

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

return M
