#!/bin/sh
set -eu

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

for test_file in \
	can_log_state_test.gd \
	command_tracker_test.gd \
	confirmation_overlay_test.gd \
	confirmation_state_test.gd \
	dangerous_command_test.gd \
	message_dispatcher_test.gd \
	motor_data_test.gd \
	protocol_validation_test.gd \
	raw_input_mapping_test.gd
do
	test_home="${TMPDIR:-/tmp}/gameboy-godot-${test_file%.gd}"
	mkdir -p "$test_home"
	HOME="$test_home" "$GODOT_BIN" --headless --path "$ROOT" \
		--script "$ROOT/tests/$test_file"
done
