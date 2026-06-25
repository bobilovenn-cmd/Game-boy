#!/bin/sh
set -eu

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

# 输入桥属于 RGB30 实体输入链路，必须与 Godot 测试一起执行。
python3 -m unittest "$ROOT/tests/rgb30_input_bridge_test.py"

# 先刷新资源导入缓存，避免字体文件已更新但测试仍读取旧 fontdata。
import_home="${TMPDIR:-/tmp}/gameboy-godot-import"
mkdir -p "$import_home"
HOME="$import_home" "$GODOT_BIN" --headless --editor --path "$ROOT" --import --quit

for test_file in \
	can_log_state_test.gd \
	command_tracker_test.gd \
	confirmation_overlay_test.gd \
	confirmation_dispatch_test.gd \
	confirmation_state_test.gd \
	dangerous_command_test.gd \
	font_coverage_test.gd \
	message_dispatcher_test.gd \
	mode_session_test.gd \
	motor_data_test.gd \
	protocol_validation_test.gd \
	raw_input_mapping_test.gd \
	selection_screen_layout_test.gd \
	selection_screen_overlay_test.gd \
	upload_mode_overlay_test.gd
do
	test_home="${TMPDIR:-/tmp}/gameboy-godot-${test_file%.gd}"
	mkdir -p "$test_home"
	HOME="$test_home" "$GODOT_BIN" --headless --path "$ROOT" \
		--script "$ROOT/tests/$test_file"
done
