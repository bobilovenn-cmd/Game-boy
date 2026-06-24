#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUTPUT="$ROOT/build/rgb30_diag_terminal_arm64"
SHA_FILE="$OUTPUT.sha256"

if [ ! -x "$GODOT_BIN" ]; then
	echo "找不到可执行 Godot：$GODOT_BIN"
	echo "请在 Azure 自托管 Mac Agent 上安装 Godot 4.6.3，并确认 Linux ARM64 导出模板可用。"
	exit 1
fi

mkdir -p "$ROOT/build"

"$GODOT_BIN" \
	--headless \
	--path "$ROOT" \
	--export-release "RGB30 Linux ARM64" \
	"$OUTPUT"

if [ ! -s "$OUTPUT" ]; then
	echo "RGB30 ARM64 导出产物不存在或为空：$OUTPUT"
	exit 1
fi

file "$OUTPUT"

if command -v shasum >/dev/null 2>&1; then
	shasum -a 256 "$OUTPUT" > "$SHA_FILE"
else
	sha256sum "$OUTPUT" > "$SHA_FILE"
fi

cat "$SHA_FILE"
