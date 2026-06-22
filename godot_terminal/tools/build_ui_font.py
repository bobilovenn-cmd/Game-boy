#!/usr/bin/env python3
"""根据 Godot 脚本中的实际字符重新生成 RGB30 UI 字体子集。"""

from pathlib import Path
import sys

from fontTools import subset
from fontTools.ttLib import TTCollection


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path("/System/Library/Fonts/STHeiti Medium.ttc")
OUTPUT_FONT = PROJECT_ROOT / "fonts" / "AGV_CJK.ttf"


def collect_characters() -> str:
    characters = {chr(code) for code in range(0x20, 0x7F)}
    for source_file in sorted((PROJECT_ROOT / "scripts").rglob("*.gd")):
        characters.update(source_file.read_text(encoding="utf-8"))
    characters.discard("\n")
    characters.discard("\r")
    characters.discard("\t")
    return "".join(sorted(characters))


def main() -> int:
    source_font = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SOURCE
    if not source_font.is_file():
        print(f"找不到字体源文件：{source_font}", file=sys.stderr)
        return 1

    collection = TTCollection(source_font)
    if not collection.fonts:
        print(f"字体集合没有可用字形：{source_font}", file=sys.stderr)
        return 1

    font = collection.fonts[0]
    options = subset.Options()
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.layout_features = ["*"]
    options.notdef_glyph = True
    options.notdef_outline = True
    options.recommended_glyphs = True

    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text=collect_characters())
    subsetter.subset(font)
    font.save(OUTPUT_FONT)
    print(f"已生成字体子集：{OUTPUT_FONT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
