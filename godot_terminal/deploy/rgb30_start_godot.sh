#!/bin/sh
# Start the Godot terminal on RGB30 for manual testing.
# This intentionally stops the current Python/SDL2 service first because that
# runtime owns the DRM/KMS display path.

set -eu

systemctl stop diag-terminal.service 2>/dev/null || true
sleep 3

systemctl restart sway.service
sleep 5

export XDG_RUNTIME_DIR=/var/run/0-runtime-dir
export WAYLAND_DISPLAY=wayland-1
export SWAYSOCK=/run/0-runtime-dir/sway-ipc.0.sock
export MALI_WAYLAND_AFBC=0
export GODOT_SILENCE_ROOT_WARNING=1

swaymsg output DSI-1 enable >/dev/null 2>&1 || true
swaymsg output DSI-1 mode 720x720 >/dev/null 2>&1 || true
swaymsg output DSI-1 power on >/dev/null 2>&1 || true
echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null || true

cd /storage/handheld_terminal_godot
exec ./rgb30_diag_terminal_arm64 \
  --display-driver wayland \
  --rendering-method gl_compatibility \
  --fullscreen \
  --resolution 720x720

