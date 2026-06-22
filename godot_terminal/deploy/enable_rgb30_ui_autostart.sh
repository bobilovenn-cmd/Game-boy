#!/bin/sh
# 可选恢复：重新启用 RGB30 Godot UI 开机延迟启动。

set -eu

systemctl enable rgb30-godot.timer
systemctl restart rgb30-godot.timer
systemctl is-enabled rgb30-godot.timer
systemctl is-active rgb30-godot.timer
