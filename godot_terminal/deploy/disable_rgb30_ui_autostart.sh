#!/bin/sh
# 默认生产模式：关闭 UI 开机启动，保留稳定输入桥开机启动。

set -eu

systemctl disable --now rgb30-godot.timer 2>/dev/null || true
systemctl stop rgb30-godot.service 2>/dev/null || true
systemctl enable rgb30-input-bridge.service
systemctl restart rgb30-input-bridge.service
systemctl is-enabled rgb30-input-bridge.service
systemctl is-active rgb30-input-bridge.service
