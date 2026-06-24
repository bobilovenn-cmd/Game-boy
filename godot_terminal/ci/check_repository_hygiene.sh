#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

if [ ! -f project.godot ] || [ ! -f export_presets.cfg ] || [ ! -x tests/run_all.sh ]; then
	echo "当前目录不是完整的 RGB30 Godot UI 仓库根目录。"
	exit 1
fi

forbidden=$(
	git ls-files | grep -E '(^|/)\.DS_Store$|(^|/)__pycache__/|\.pyc$|(^|/)build/' || true
)

if [ -n "$forbidden" ]; then
	echo "发现不应提交到 UI 仓库的缓存或构建产物："
	echo "$forbidden"
	exit 1
fi

if [ -d dongle_firmware ]; then
	echo "当前仓库根目录出现 dongle_firmware；请勿把完整 GameBoy 仓库当作 Azure UI 仓库推送。"
	exit 1
fi
