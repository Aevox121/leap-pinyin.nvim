"""Build Lua dictionary tables from mozillazg/pinyin-data.

Generates two output files for leap-pinyin.nvim:
  - lua/leap-pinyin/data/initials.lua  (full-pinyin first-letter mode)
  - lua/leap-pinyin/data/shuangpin.lua (xiaohe shuangpin mode)

Usage:
  python scripts/build_dict.py --input path/to/pinyin.txt
  python scripts/build_dict.py --download   # fetch pinyin.txt from GitHub
"""

import argparse
import re
import sys
import urllib.request
from pathlib import Path

PINYIN_DATA_URL = (
    "https://raw.githubusercontent.com/mozillazg/pinyin-data/master/kTGHZ2013.txt"
)

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "lua" / "leap-pinyin" / "data"
CACHE_DIR = PROJECT_ROOT / "scripts" / ".cache"

# ------------------------------------------------------------------
# Tone stripping
# ------------------------------------------------------------------
TONE_MAP = str.maketrans({
    "ā": "a", "á": "a", "ǎ": "a", "à": "a",
    "ē": "e", "é": "e", "ě": "e", "è": "e",
    "ī": "i", "í": "i", "ǐ": "i", "ì": "i",
    "ō": "o", "ó": "o", "ǒ": "o", "ò": "o",
    "ū": "u", "ú": "u", "ǔ": "u", "ù": "u",
    "ǖ": "v", "ǘ": "v", "ǚ": "v", "ǜ": "v", "ü": "v",
    "ń": "n", "ň": "n", "ǹ": "n",
    "ḿ": "m",
})


def strip_tone(syllable: str) -> str:
    return syllable.translate(TONE_MAP).lower()


# ------------------------------------------------------------------
# Xiaohe shuangpin conversion
# ------------------------------------------------------------------
INITIALS_2 = {"zh": "v", "ch": "i", "sh": "u"}
INITIALS_1 = set("bpmfdtnlgkhjqxrzcsyw")

FINAL_MAP = {
    # single vowels direct
    "a": "a", "o": "o", "e": "e", "i": "i", "u": "u", "v": "v",
    # compound finals
    "ai": "d", "ei": "w", "ui": "v",
    "ao": "c", "ou": "z", "iu": "q",
    "ie": "p", "ue": "t", "ve": "t",
    "er": "r",
    # nasal finals
    "an": "j", "en": "f", "in": "b", "un": "y", "vn": "y",
    "ang": "h", "eng": "g", "ing": "k", "ong": "s",
    # i-group + u-group
    "ia": "x", "iao": "n", "ian": "m", "iang": "l", "iong": "s",
    "ua": "x", "uo": "o", "uai": "k", "uan": "r", "uang": "l",
    "ueng": "s",
    # ü-group (written as u after j/q/x/y)
    "van": "r",
}

def to_shuangpin(pinyin: str) -> str | None:
    """Convert a tone-stripped lowercase pinyin syllable to xiaohe shuangpin (2 keys).

    Layout follows the official 小鹤双拼 keyboard (per 何海峰), surface form:
      - 声母: zh→V, ch→I, sh→U; others literal
      - 韵母: per FINAL_MAP (iu→Q, ei→W, uan/van→R, ue/ve→T, ao→C, ...)
      - y/w 整体认读 use surface form: 妖(yao)=yc, 业(ye)=ye, 烟(yan)=yj, 优(you)=yz

    Note: NO j/q/x/y + u → ü rewriting. The 'u' in ju/qu/xu/yu is taken as
    pinyin-literal and maps to U key, so 鱼=yu, 居=ju, 须=xu, 区=qu (not yv/jv/xv/qv).
    Other ü-pinyins (jue/juan/jun + nü/lü) still produce correct codes because
    ue/ve, uan/van, un/vn all share the same 韵母 key.

    Returns None if conversion fails (unknown final).
    """
    if not pinyin:
        return None

    # Identify initial (longest match: 2 chars then 1 char)
    if len(pinyin) >= 2 and pinyin[:2] in INITIALS_2:
        initial_key = INITIALS_2[pinyin[:2]]
        final = pinyin[2:]
    elif pinyin[0] in INITIALS_1:
        initial_key = pinyin[0]
        final = pinyin[1:]
    else:
        # Zero-initial vowel syllable: first letter of syllable doubles as initial key
        initial_key = pinyin[0]
        final = pinyin

    final_key = FINAL_MAP.get(final)
    if final_key is None:
        return None
    return initial_key + final_key


def to_shuangpin_codes(pinyin: str) -> list[str]:
    """Return the xiaohe shuangpin code(s) for a pinyin syllable as a list.

    Strict 小鹤 produces a single code per syllable; this returns a 1-element
    list (or empty on failure) for caller convenience.
    """
    sp = to_shuangpin(pinyin)
    return [sp] if sp else []


# ------------------------------------------------------------------
# pinyin-data parsing
# ------------------------------------------------------------------
LINE_RE = re.compile(r"U\+([0-9A-F]+):\s*([^\s#]+)\s*#\s*(\S+)")


def parse_pinyin_data(path: Path):
    """Yield (char, [pinyin_list_with_tones]) tuples."""
    with path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            m = LINE_RE.match(line)
            if not m:
                continue
            _codepoint, pinyins, char = m.groups()
            yield char, pinyins.split(",")


def fetch_pinyin_data() -> Path:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    target = CACHE_DIR / "kTGHZ2013.txt"
    if target.exists():
        print(f"using cached: {target}")
        return target
    print(f"downloading: {PINYIN_DATA_URL}")
    urllib.request.urlretrieve(PINYIN_DATA_URL, target)
    return target


# ------------------------------------------------------------------
# Output writers
# ------------------------------------------------------------------
def lua_escape(s: str) -> str:
    # Lua single-quoted string escaping
    return s.replace("\\", "\\\\").replace("'", "\\'")


def write_initials(initials: dict[str, str], path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write("-- Generated by scripts/build_dict.py — do not edit by hand.\n")
        f.write("-- Maps Chinese character to a string of unique pinyin first letters.\n")
        f.write("-- Multi-pronunciation chars: all initials concatenated, e.g. 行 -> 'xh'.\n\n")
        f.write("return {\n")
        for ch in sorted(initials):
            f.write(f"  ['{lua_escape(ch)}'] = '{initials[ch]}',\n")
        f.write("}\n")


def write_shuangpin(shuangpin: dict[str, list[str]], path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write("-- Generated by scripts/build_dict.py — do not edit by hand.\n")
        f.write("-- Maps Chinese character to a list of xiaohe shuangpin codes (2 keys each).\n")
        f.write("-- Multi-pronunciation chars produce multiple entries.\n\n")
        f.write("return {\n")
        for ch in sorted(shuangpin):
            codes = ", ".join(f"'{c}'" for c in shuangpin[ch])
            f.write(f"  ['{lua_escape(ch)}'] = {{{codes}}},\n")
        f.write("}\n")


# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
def main():
    # Force UTF-8 stdout on Windows so we can print pinyin with tone marks for diagnostics.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser(description=__doc__)
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--input", type=Path, help="Path to pinyin.txt")
    src.add_argument("--download", action="store_true", help="Download pinyin.txt from GitHub")
    parser.add_argument("--out-dir", type=Path, default=DATA_DIR,
                        help=f"Output directory (default: {DATA_DIR})")
    parser.add_argument("--limit-cjk", action="store_true",
                        help="Skip non-CJK-Unified chars (U+4E00-U+9FFF only)")
    args = parser.parse_args()

    if args.download:
        path = fetch_pinyin_data()
    else:
        path = args.input
        if not path.exists():
            print(f"error: {path} does not exist", file=sys.stderr)
            sys.exit(1)

    initials: dict[str, str] = {}
    shuangpin: dict[str, list[str]] = {}
    failed_syllables: set[str] = set()
    chars_total = 0
    chars_with_failures = 0

    for char, pinyins in parse_pinyin_data(path):
        if args.limit_cjk:
            cp = ord(char)
            if not (0x4E00 <= cp <= 0x9FFF):
                continue
        chars_total += 1

        plain_syllables = [strip_tone(p) for p in pinyins]
        # initials: unique first letters in original order
        seen = []
        for syl in plain_syllables:
            if syl and syl[0] not in seen:
                seen.append(syl[0])
        initials[char] = "".join(seen)

        # shuangpin: unique codes in original order. Each syllable contributes
        # both the phonetic-decomposed form and the surface (pinyin-as-written)
        # form so users can type either style.
        codes: list[str] = []
        had_failure = False
        for syl in plain_syllables:
            sps = to_shuangpin_codes(syl)
            if not sps:
                failed_syllables.add(syl)
                had_failure = True
                continue
            for sp in sps:
                if sp not in codes:
                    codes.append(sp)
        if had_failure:
            chars_with_failures += 1
        if codes:
            shuangpin[char] = codes

    out_dir: Path = args.out_dir
    write_initials(initials, out_dir / "initials.lua")
    write_shuangpin(shuangpin, out_dir / "shuangpin.lua")

    print(f"\n=== Build complete ===")
    print(f"chars processed: {chars_total}")
    print(f"initials.lua:    {len(initials)} entries")
    print(f"shuangpin.lua:   {len(shuangpin)} entries")
    print(f"chars with at least one failed syllable: {chars_with_failures}")
    if failed_syllables:
        print(f"unmatched syllables ({len(failed_syllables)}):")
        for s in sorted(failed_syllables)[:50]:
            print(f"  {s}")
        if len(failed_syllables) > 50:
            print(f"  ... and {len(failed_syllables) - 50} more")


if __name__ == "__main__":
    main()
