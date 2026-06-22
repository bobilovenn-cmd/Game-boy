#!/bin/sh
# Start the Godot terminal on RGB30 for manual testing.
# This intentionally stops the current Python/SDL2 service first because that
# runtime owns the DRM/KMS display path.

set -eu

systemctl stop diag-terminal.service 2>/dev/null || true
sleep 3

# ROCKNIX can expose Wayland sockets before its first EGL context is usable.
# A compositor restart is required for the Mali Wayland path used by Godot.
systemctl restart sway.service

export XDG_RUNTIME_DIR=/var/run/0-runtime-dir
export WAYLAND_DISPLAY=wayland-1
export SWAYSOCK=/run/0-runtime-dir/sway-ipc.0.sock
export HOME=/storage
export XDG_DATA_HOME=/storage/.local/share
export XDG_CACHE_HOME=/storage/.cache
export MALI_WAYLAND_AFBC=0
export GODOT_SILENCE_ROOT_WARNING=1

mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME"

sway_ready() {
  [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] &&
    [ -S "$SWAYSOCK" ] &&
    swaymsg -t get_outputs >/dev/null 2>&1
}

ready_wait=0
while ! sway_ready; do
  ready_wait=$((ready_wait + 1))
  if [ "$ready_wait" -ge 30 ]; then
    echo "Sway/Wayland did not become ready within 30 seconds" >&2
    exit 1
  fi
  sleep 1
done

# The socket can become visible slightly before EGL initialization settles.
sleep 2

swaymsg output DSI-1 enable >/dev/null 2>&1 || true
swaymsg output DSI-1 mode 720x720 >/dev/null 2>&1 || true
swaymsg output DSI-1 power on >/dev/null 2>&1 || true
echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null || true

cd /storage/handheld_terminal_godot

systemctl start rgb30-input-bridge.service 2>/dev/null || true

exec ./rgb30_diag_terminal_arm64 \
  --display-driver wayland \
  --rendering-method gl_compatibility \
  --fullscreen \
  --resolution 720x720
