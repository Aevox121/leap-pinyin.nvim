# leap-pinyin.nvim

> A fork of [leap.nvim](https://github.com/ggandor/leap.nvim) that lets you jump to Chinese characters via pinyin.

Search for Chinese characters by typing their pinyin — in the same 2-key motion you already use for English. Works entirely inside leap's native label flow: dimming, labels, forward/backward, operator-pending, all just work.

Two matching modes:

- **Pinyin (首字母)** — 2 keys match 2 adjacent characters by pinyin initial. Type `zh` to jump to `中华` / `这会` / `最后` / literal `zh`.
- **Shuangpin (小鹤双拼)** — 2 keys match a single Chinese character by its full xiaohe code. Type `vs` to jump to `中`, `yr` for `圆`, `aj` for `安`.

Chinese and English matches share the same label pool, so mixed-script buffers work naturally.

## Requirements

- Neovim 0.9+
- A CJK-capable font + UTF-8 encoding

## Install (lazy.nvim)

```lua
{
  "Aevox121/leap-pinyin.nvim",
  event = "VeryLazy",
  config = function()
    require("leap-pinyin").setup({
      mode = "shuangpin", -- "pinyin" | "shuangpin" (default: "shuangpin")
    })

    -- Optional: disable leap's autojump so every match gets a label.
    require("leap").opts.safe_labels = ""

    -- Pinyin mode: use leap's native mappings.
    -- vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap-forward)")
    -- vim.keymap.set({ "n", "x", "o" }, "S", "<Plug>(leap-backward)")

    -- Shuangpin mode: use leap-pinyin's own mappings.
    vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap-pinyin-forward)")
    vim.keymap.set({ "n", "x", "o" }, "S", "<Plug>(leap-pinyin-backward)")
  end,
}
```

If you use LazyVim (which bundles flash.nvim), also disable flash's `s`/`S` so they don't shadow leap:

```lua
{
  "folke/flash.nvim",
  keys = {
    { "s", mode = { "n", "x", "o" }, false },
    { "S", mode = { "n", "x", "o" }, false },
  },
},
```

This plugin **includes its own vendored copy of leap.nvim** — do not install upstream leap alongside it.

## Configuration

```lua
require("leap-pinyin").setup({
  mode = "shuangpin",        -- "pinyin" | "shuangpin"
  shuangpin_scheme = "xiaohe", -- only "xiaohe" for now
  enabled = true,
})
```

## Usage

### Pinyin mode

Standard leap flow — press `s` or `S`, leap reads 2 characters, jumps or labels:

| Input | Matches |
|---|---|
| `zh` | `中华`, `这会`, `最后`, literal `zh` in English |
| `yh` | `用户`, `有huo`-type pairs, literal `yh` |
| `qp` | `气泡`, literal `qp` |
| `xk` | `行k`-initial combos, literal `xk` |

Every 2-key input matches **2 adjacent characters**, each reduced to its pinyin initial (multi-pronunciation chars included). Case-insensitive.

### Shuangpin mode (xiaohe)

Press `s`/`S`, you see a `leap-pinyin>` prompt, type the 2-key xiaohe code:

| Input | Matches |
|---|---|
| `vs` | `中` (zhōng) — `zh` → `v`, `ong` → `s` |
| `aj` | `安` (ān) — zero-initial `a` + `an` → `j` |
| `yr` | `圆` (yuán) — `y` + `üan` → `r` |
| `xk` / `hh` / `hg` | `行` — all three readings (xíng/háng/hèng) |

2 keys match **1 Chinese character** (the entire syllable encoded in xiaohe). Literal 2-char ASCII matches are included too.

## How it works

### Pinyin mode

Monkey-patches `leap.opts.default.eqv_class_of` so that each ASCII letter returns an extended equivalence class containing all Chinese characters whose pinyin initial matches. leap's native `prepare_pattern` then builds a `\V[a+hanzi...][b+hanzi...]` regex char class — no changes to leap's search, labeling, or UI code are needed.

Every Chinese character also gets an eqv entry pointing back at its initial's class (first element = ASCII letter), so leap's `populate_sublists` keys sublists correctly for the second-char refinement phase.

### Shuangpin mode

leap's 2-key model assumes 2 characters, but xiaohe 2 keys = 1 character. So this mode bypasses leap's input collection:

1. Read 2 keys ourselves (showing a `leap-pinyin>` prompt).
2. Scan the visible region of the current buffer, collect a target list of:
   - Single Chinese chars whose xiaohe code matches (chars = `{hanzi, ""}`).
   - Literal 2-char ASCII matches (chars = `{c1, c2}`).
3. Apply `LeapBackdrop` dimming.
4. Hand the pre-built targets to `leap.leap({targets = ...})` so leap handles labels, distance ranking, jumping, operator-pending, etc.

leap's beacon rendering natively supports the `chars[2] == ""` single-char target shape — no leap-side patches required.

## Dictionary

Built from [mozillazg/pinyin-data](https://github.com/mozillazg/pinyin-data) `kTGHZ2013.txt` (MIT licensed) — the 通用规范汉字表 standard set of ~7800 common characters. Only modern standard readings are included, so rare/archaic/dialectal Unihan readings (e.g. `方` as `wǎng`) don't cause false matches. Legitimate multi-readings like `行` (xíng / háng / héng) are preserved.

Regenerate:

```bash
python scripts/build_dict.py --download --limit-cjk
```

Outputs `lua/leap-pinyin/data/initials.lua` and `lua/leap-pinyin/data/shuangpin.lua`.

## Xiaohe shuangpin scheme

This plugin encodes the [official xiaohe (小鹤双拼)](https://flypy.com/) scheme:

- Two-letter initials: `zh → v`, `ch → i`, `sh → u`. Other initials keep their single letter.
- Finals mapped per the official table (`ong → s`, `ang → h`, `ing → k`, ...).
- Zero-initial syllables use the syllable's first letter as the initial key (`安` = `aj`).

Full mapping lives in `scripts/build_dict.py`.

## Tests

Run the test suite via headless Neovim:

```bash
nvim --headless -c "luafile tests/matcher_spec.lua" -c "qa!"
nvim --headless --clean --cmd "set rtp+=." -c "luafile tests/hook_spec.lua" -c "qa!"
nvim --headless --clean --cmd "set rtp+=." -c "luafile tests/shuangpin_spec.lua" -c "qa!"
```

Three suites, 86 checks total: matcher logic, pinyin-mode leap integration, shuangpin-mode target collection.

## Credits

- [leap.nvim](https://codeberg.org/andyg/leap.nvim) by @ggandor — the upstream motion plugin this is forked from.
- [mozillazg/pinyin-data](https://github.com/mozillazg/pinyin-data) — the pinyin dictionary source.
- [小鹤双拼 (flypy)](https://flypy.com/) — the xiaohe shuangpin scheme.

## License

Same as upstream leap.nvim. See `LICENSE.md`.
