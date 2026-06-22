#!/bin/sh
# 在 RGB30 已有的 Sway/Wayland 会话中启动 Godot 终端。

set -eu

systemctl stop diag-terminal.service 2>/dev/null || true

export XDG_RUNTIME_DIR=/var/run/0-runtime-dir
export WAYLAND_DISPLAY=wayland-1
export SWAYSOCK=/run/0-runtime-dir/sway-ipc.0.sock
export HOME=/storage
export XDG_DATA_HOME=/storage/.local/share
export XDG_CACHE_HOME=/storage/.cache
export MALI_WAYLAND_AFBC=0
export GODOT_SILENCE_ROOT_WARNING=1

mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME"

# 手动从 ES Ports 启动时 Sway 已经运行。这里只等待图形会话就绪，
# 禁止重启 Sway，避免 Godot 异常恢复时反复重置整个 ES 图形环境。
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

# Wayland socket 可见后，Mali EGL 仍可能需要短暂稳定时间。
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
