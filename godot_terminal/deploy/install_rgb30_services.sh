#!/bin/sh
# 安装 RGB30 Godot 服务；默认仅让输入桥开机启动，UI 从 ES Ports 手动进入。

set -eu

ROOT="/storage/handheld_terminal_godot"
UNIT_DIR="/storage/.config/system.d"

for required in \
  "$ROOT/rgb30_diag_terminal_arm64" \
  "$ROOT/rgb30_start_godot.sh" \
  "$ROOT/rgb30_input_bridge.py" \
  "$ROOT/rgb30-godot.service" \
  "$ROOT/rgb30-godot.timer" \
  "$ROOT/rgb30-input-bridge.service" \
  "$ROOT/AGV_Diagnostic.sh" \
  "$ROOT/enable_rgb30_ui_autostart.sh" \
  "$ROOT/disable_rgb30_ui_autostart.sh"
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
  "$ROOT/rgb30_input_bridge.py" \
  "$ROOT/AGV_Diagnostic.sh" \
  "$ROOT/enable_rgb30_ui_autostart.sh" \
  "$ROOT/disable_rgb30_ui_autostart.sh"

for ports_dir in /storage/roms/Ports /storage/roms/ports
do
  if [ -d "$ports_dir" ]; then
    cp "$ROOT/AGV_Diagnostic.sh" "$ports_dir/AGV_Diagnostic.sh"
    chmod +x "$ports_dir/AGV_Diagnostic.sh"
  fi
done

systemctl daemon-reload
systemctl disable diag-terminal.service 2>/dev/null || true
systemctl enable rgb30-input-bridge.service
systemctl disable rgb30-godot.service 2>/dev/null || true
systemctl disable --now rgb30-godot.timer 2>/dev/null || true
systemctl restart rgb30-input-bridge.service
systemctl stop rgb30-godot.service 2>/dev/null || true
for pid in $(pidof rgb30_diag_terminal_arm64 2>/dev/null || true); do
  kill "$pid" 2>/dev/null || true
done

systemctl is-active rgb30-input-bridge.service
systemctl is-enabled rgb30-input-bridge.service
if systemctl is-enabled rgb30-godot.timer 2>/dev/null; then
  echo "rgb30-godot.timer should be disabled in manual-start mode" >&2
  exit 1
fi
