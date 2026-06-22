#!/bin/sh
# Install and enable the production RGB30 Godot and stable-input services.

set -eu

ROOT="/storage/handheld_terminal_godot"
UNIT_DIR="/storage/.config/system.d"

for required in \
  "$ROOT/rgb30_diag_terminal_arm64" \
  "$ROOT/rgb30_start_godot.sh" \
  "$ROOT/rgb30_input_bridge.py" \
  "$ROOT/rgb30-godot.service" \
  "$ROOT/rgb30-godot.timer" \
  "$ROOT/rgb30-input-bridge.service"
do
  if [ ! -f "$required" ]; then
    echo "missing required file: $required" >&2
    exit 1
  fi
done

mkdir -p "$UNIT_DIR"
cp "$ROOT/rgb30-godot.service" "$UNIT_DIR/rgb30-godot.service"
cp "$ROOT/rgb30-godot.timer" "$UNIT_DIR/rgb30-godot.timer"
cp "$ROOT/rgb30-input-bridge.service" "$UNIT_DIR/rgb30-input-bridge.service"
chmod +x \
  "$ROOT/rgb30_diag_terminal_arm64" \
  "$ROOT/rgb30_start_godot.sh" \
  "$ROOT/rgb30_input_bridge.py"

systemctl daemon-reload
systemctl disable diag-terminal.service 2>/dev/null || true
systemctl enable rgb30-input-bridge.service
systemctl disable rgb30-godot.service 2>/dev/null || true
systemctl enable rgb30-godot.timer
systemctl restart rgb30-input-bridge.service
systemctl restart rgb30-godot.timer
systemctl stop rgb30-godot.service 2>/dev/null || true
for pid in $(pidof rgb30_diag_terminal_arm64 2>/dev/null || true); do
  kill "$pid" 2>/dev/null || true
done
systemctl restart rgb30-godot.service

systemctl is-active rgb30-input-bridge.service
systemctl is-active rgb30-godot.service
systemctl is-active rgb30-godot.timer
