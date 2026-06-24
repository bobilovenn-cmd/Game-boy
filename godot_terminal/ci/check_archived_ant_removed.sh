#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# 蚂蚁操控模式已归档到项目根目录 ANT/，当前 RGB30 正式 UI 不应再出现入口、
# 运行分支或打包资源。未来若重新接入，应同步更新此检查和对应测试。
matches=$(
	rg -n "ant_control|AntControl|AntRuntime|ant_|mode_ant|蚂蚁|ANT|车辆操控" \
		scripts tests assets project.godot 2>/dev/null || true
)

if [ -n "$matches" ]; then
	echo "当前 RGB30 UI 中发现已归档蚂蚁模式的残留引用："
	echo "$matches"
	exit 1
fi
