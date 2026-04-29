-- Two integration modes with leap.nvim:
--
-- PINYIN MODE (full pinyin first-letter):
--   Passive hook on opts.default.eqv_class_of so leap's regular 2-char
--   pattern includes Chinese chars whose pinyin initial matches.
--   User keeps their normal `s` -> <Plug>(leap-forward) mapping.
--
-- SHUANGPIN MODE (xiaohe):
--   Active wrapper: user invokes our `leap()` function which reads 2 keys,
--   builds a target list (single-hanzi shuangpin matches + literal 2-char
--   ASCII matches), then hands off to `require("leap").leap({targets=...})`.
--   User maps `s` to <Plug>(leap-pinyin-forward).

local M = {}

local installed = false
local installed_mode = nil
local original_eqv_class_of = nil
local pinyin_reverse_index = nil

-- ============================================================
-- Pinyin mode: extend leap's char equivalence table
-- ============================================================
local function build_pinyin_reverse_index()
  if pinyin_reverse_index then return pinyin_reverse_index end
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
  pinyin_reverse_index = idx
  return idx
end

local function install_pinyin_mode()
  -- Force leap.main to load so its init() runs and populates eqv_class_of.
  -- Without this, opts.default has a recursive __index metatable that loops
  -- forever on missing keys.
  require("leap.main")

  local opts = require("leap.opts")
  local rev = build_pinyin_reverse_index()
  original_eqv_class_of = opts.default.eqv_class_of

  -- CRITICAL: leap's populate_sublists() keys target groups by the
  -- representative char of each target's ch2 (via rep_char(ch) = eqv_class[ch][1]).
  -- For a Chinese char like 户, if we don't give it an eqv class, rep_char returns
  -- 户 itself, and later lookup sublists["h"] (user's in2) misses.
  --
  -- Fix: also expose an eqv class for each Chinese char in the dictionary,
  -- keyed so its first element is the corresponding ASCII initial letter.
  -- This makes rep_char("户") == rep_char("h") == "h".
  -- For multi-pronunciation chars (e.g. 行=xh), we pick the FIRST initial.
  local hanzi_to_class = {}
  local initials_data = require("leap-pinyin.data.initials")
  for hanzi, initials in pairs(initials_data) do
    if #initials >= 1 then
      local first_initial = initials:sub(1, 1)
      if rev[first_initial] then
        hanzi_to_class[hanzi] = rev[first_initial]
      end
    end
  end

  opts.default.eqv_class_of = setmetatable({}, {
    __index = function(_, ch)
      local hit = rev[ch]
      if hit then return hit end
      local hanzi_hit = hanzi_to_class[ch]
      if hanzi_hit then return hanzi_hit end
      if original_eqv_class_of then
        return original_eqv_class_of[ch]
      end
      return nil
    end,
  })
end

local function uninstall_pinyin_mode()
  if original_eqv_class_of ~= nil then
    require("leap.opts").default.eqv_class_of = original_eqv_class_of
    original_eqv_class_of = nil
  end
end

-- ============================================================
-- Shuangpin mode: build targets ourselves, hand to leap
-- ============================================================
-- Pre-built reverse map: shuangpin code -> set of hanzi.
-- Built lazily on first use; ~20K hanzi processed once.
local shuangpin_reverse = nil

local function build_shuangpin_reverse()
  if shuangpin_reverse then return shuangpin_reverse end
  shuangpin_reverse = {}
  local data = require("leap-pinyin.data.shuangpin")
  for hanzi, codes in pairs(data) do
    for _, code in ipairs(codes) do
      local set = shuangpin_reverse[code]
      if not set then
        set = {}
        shuangpin_reverse[code] = set
      end
      set[hanzi] = true
    end
  end
  return shuangpin_reverse
end

-- Read 2 keys from user, returning the input string or nil if cancelled.
local function read_two_keys()
  local function read_one(prompt)
    vim.api.nvim_echo({ { prompt, "ModeMsg" } }, false, {})
    vim.cmd("redraw")
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok then return nil end
    -- ESC or Ctrl-C cancels
    if ch == "" or ch == "\27" or ch == "\3" then return nil end
    return ch
  end
  local k1 = read_one("leap-pinyin> ")
  if not k1 then return nil end
  local k2 = read_one("leap-pinyin> " .. k1)
  vim.api.nvim_echo({ { "" } }, false, {})
  if not k2 then return nil end
  return k1 .. k2
end

-- Collect targets in the current window's visible region.
-- When `backward` is true, only collect targets strictly before the cursor.
-- Otherwise only collect targets strictly after the cursor. This matches
-- leap's native s/S directional behavior.
local function collect_shuangpin_targets(input, backward)
  local lower_input = input:lower()
  local hanzi_set = build_shuangpin_reverse()[lower_input] or {}
  local wininfo = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  local first_line = vim.fn.line("w0")
  local last_line = vim.fn.line("w$")
  local cur_line = vim.fn.line(".")
  local cur_col = vim.fn.col(".") -- 1-based byte col

  if backward then
    last_line = math.min(last_line, cur_line)
  else
    first_line = math.max(first_line, cur_line)
  end

  local targets = {}
  for lnum = first_line, last_line do
    if vim.fn.foldclosed(lnum) == -1 then
      local line = vim.fn.getline(lnum)
      local byte_col = 0
      local line_len = #line
      while byte_col < line_len do
        local ch1 = vim.fn.strpart(line, byte_col, 1, true)
        if ch1 == "" then break end
        local ch1_len = #ch1
        local pos_col = byte_col + 1 -- 1-based

        local include = true
        if lnum == cur_line then
          if backward then
            if pos_col >= cur_col then include = false end
          else
            if pos_col <= cur_col then include = false end
          end
        end

        if include then
          -- Chinese single-char shuangpin match
          if hanzi_set[ch1] then
            table.insert(targets, {
              wininfo = wininfo,
              pos = { lnum, pos_col },
              chars = { ch1, "" },
            })
          end

          -- Literal 2-char match (case-insensitive)
          if byte_col + ch1_len < line_len then
            local ch2 = vim.fn.strpart(line, byte_col + ch1_len, 1, true)
            if ch2 ~= "" and (ch1 .. ch2):lower() == lower_input then
              table.insert(targets, {
                wininfo = wininfo,
                pos = { lnum, pos_col },
                chars = { ch1, ch2 },
              })
            end
          end
        end

        byte_col = byte_col + ch1_len
      end
    end
  end
  return targets
end

-- Sort targets by distance from cursor (forward by default).
local function sort_targets_by_cursor(targets, backward)
  local cur_line, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
  -- nvim_win_get_cursor returns (1-based line, 0-based byte col)
  cur_col = cur_col + 1
  local function dist(t)
    local dl = t.pos[1] - cur_line
    local dc = t.pos[2] - cur_col
    return dl * 1000 + dc
  end
  table.sort(targets, function(a, b)
    local da, db = dist(a), dist(b)
    if backward then
      -- Backward: prefer targets before cursor; closer-to-cursor wins
      if da < 0 and db < 0 then return da > db end
      if da < 0 then return true end
      if db < 0 then return false end
      return da < db
    else
      if da > 0 and db > 0 then return da < db end
      if da > 0 then return true end
      if db > 0 then return false end
      return da > db
    end
  end)
end

-- Apply LeapBackdrop dimming over the search range manually.
-- leap's own backdrop autocmd has timing issues when combined with custom
-- targets via leap.leap({targets=...}); applying it directly here is reliable.
local backdrop_ns = vim.api.nvim_create_namespace("leap_pinyin_backdrop")

local function apply_backdrop(backward)
  local bufnr = vim.api.nvim_get_current_buf()
  local cur_line = vim.fn.line(".") - 1
  local cur_col = vim.fn.col(".") - 1
  local top_line = vim.fn.line("w0") - 1
  local bot_line = vim.fn.line("w$") - 1

  vim.api.nvim_buf_clear_namespace(bufnr, backdrop_ns, 0, -1)

  local start_row, start_col, end_row, end_col
  if backward then
    start_row, start_col = top_line, 0
    end_row, end_col = cur_line, cur_col
  else
    start_row, start_col = cur_line, cur_col + 1
    end_row, end_col = bot_line, -1
  end

  -- Resolve end-of-line byte column (avoid relying on -1 sentinel)
  if end_col == -1 then
    local end_line_text = vim.fn.getline(end_row + 1) or ""
    end_col = #end_line_text
  end

  local hl_range = (vim.hl and vim.hl.range) or vim.highlight.range
  local ok, err = pcall(hl_range, bufnr, backdrop_ns, "LeapBackdrop",
    { start_row, start_col }, { end_row, end_col },
    { priority = 65534, inclusive = false })
  if not ok then
    vim.notify("[leap-pinyin] apply_backdrop failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end

-- Debug helper: apply backdrop and redraw so the user can visually verify
-- the dimming works outside the leap.leap() flow.
-- Run: :lua require("leap-pinyin.leap-hook").debug_backdrop()
function M.debug_backdrop()
  apply_backdrop(false)
  vim.cmd("redraw")
  vim.notify("[leap-pinyin] backdrop applied (forward). Move cursor or press a key to clear.", vim.log.levels.INFO)
  vim.defer_fn(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, backdrop_ns, 0, -1)
      end
    end
  end, 3000)
end

local function clear_backdrop()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, backdrop_ns, 0, -1)
    end
  end
end

-- Public entry for shuangpin mode.
function M.leap(opts)
  opts = opts or {}

  -- Apply backdrop BEFORE key reading so the buffer dims from the moment the
  -- user presses `s`, not just after the 2 keys are collected.
  apply_backdrop(opts.backward)
  vim.cmd("redraw")

  local input = read_two_keys()
  if not input then
    clear_backdrop()
    return
  end

  local targets = collect_shuangpin_targets(input, opts.backward)
  if #targets == 0 then
    clear_backdrop()
    vim.notify("leap-pinyin: no matches for '" .. input .. "'", vim.log.levels.INFO)
    return
  end

  sort_targets_by_cursor(targets, opts.backward)

  -- Re-apply backdrop in case the key-reading echo/redraw dirtied it.
  apply_backdrop(opts.backward)
  vim.cmd("redraw")

  -- When targets are user-given, leap renders labels with offset=0 (overlay
  -- sitting on top of the first char). For single-char shuangpin targets
  -- that covers the hanzi itself. Patch the beacons so each label lands
  -- AFTER the target chars, matching leap's normal phase=1 rendering.
  local function fix_beacons(tlist, s_idx, e_idx)
    for i = (s_idx or 1), (e_idx or #tlist) do
      local t = tlist[i]
      if t.beacon and t.chars then
        local ch1 = t.chars[1] or ""
        local ch2 = t.chars[2] or ""
        t.beacon[1] = #ch1 + #ch2
        local vtext = t.beacon[2] and t.beacon[2].virt_text
        if vtext then
          for _, seg in ipairs(vtext) do
            if seg[1] and seg[1]:sub(1, 1) == " " then
              seg[1] = seg[1]:sub(2)
            end
          end
        end
      end
    end
  end

  local ok, err = pcall(function()
    require("leap").leap({
      targets = targets,
      backward = opts.backward,
      opts = { on_beacons = fix_beacons },
    })
  end)
  clear_backdrop()
  if not ok then error(err) end
end

local function install_shuangpin_mode()
  -- Force leap to initialize so subsequent leap.leap() calls work.
  require("leap.main")

  vim.keymap.set({ "n", "x", "o" }, "<Plug>(leap-pinyin-forward)", function()
    M.leap()
  end, { silent = true, desc = "Leap with pinyin (shuangpin) — forward" })

  vim.keymap.set({ "n", "x", "o" }, "<Plug>(leap-pinyin-backward)", function()
    M.leap({ backward = true })
  end, { silent = true, desc = "Leap with pinyin (shuangpin) — backward" })
end

local function uninstall_shuangpin_mode()
  pcall(vim.keymap.del, { "n", "x", "o" }, "<Plug>(leap-pinyin-forward)")
  pcall(vim.keymap.del, { "n", "x", "o" }, "<Plug>(leap-pinyin-backward)")
end

-- ============================================================
-- Public install / uninstall
-- ============================================================
function M.install()
  if installed then return end
  local plugin_opts = require("leap-pinyin").opts
  if plugin_opts.mode == "pinyin" then
    install_pinyin_mode()
  elseif plugin_opts.mode == "shuangpin" then
    install_shuangpin_mode()
  end
  installed_mode = plugin_opts.mode
  installed = true
end

function M.uninstall()
  if not installed then return end
  if installed_mode == "pinyin" then
    uninstall_pinyin_mode()
  elseif installed_mode == "shuangpin" then
    uninstall_shuangpin_mode()
  end
  installed_mode = nil
  installed = false
end

-- Drop the cached reverse index AND force Lua to re-read the data files
-- from disk. Useful after regenerating shuangpin.lua / initials.lua.
function M.reload_dict()
  shuangpin_reverse = nil
  pinyin_reverse_index = nil
  package.loaded["leap-pinyin.data.shuangpin"] = nil
  package.loaded["leap-pinyin.data.initials"] = nil
end

-- Exposed for tests
M._build_shuangpin_reverse = build_shuangpin_reverse
M._collect_shuangpin_targets = collect_shuangpin_targets

return M
