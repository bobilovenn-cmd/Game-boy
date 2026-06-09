#!/bin/sh
# 停止系统 UI
systemctl stop essway.service 2>/dev/null
sleep 1
killall -9 emulationstation sway swaybg 2>/dev/null
sleep 2
echo 0 > /sys/class/graphics/fb0/blank

# 设置环境
export PYTHONPATH=/opt/lib/python3.13/site-packages
export LD_LIBRARY_PATH=/usr/lib
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR

# 启动手持终端
cd /storage/handheld_terminal
exec /usr/bin/python3 main.py
