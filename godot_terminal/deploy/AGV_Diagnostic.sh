#!/bin/sh
# EmulationStation Ports 入口：启动诊断 UI，并在离开 Ports 时停止服务。

set -eu

SERVICE="rgb30-godot.service"

stop_ui() {
  trap - EXIT INT TERM HUP
  systemctl stop "$SERVICE" 2>/dev/null || true
}

trap stop_ui EXIT INT TERM HUP

systemctl start rgb30-input-bridge.service
systemctl reset-failed "$SERVICE" 2>/dev/null || true
systemctl start "$SERVICE"

# 保持 Ports 启动进程存活，使 ES 在 Godot 运行期间继续等待。
# Godot 异常退出时 systemd 会短暂进入 activating/auto-restart，不能把该状态
# 误判为正常退出。
while true
do
  active_state=$(systemctl show "$SERVICE" -p ActiveState --value)
  sub_state=$(systemctl show "$SERVICE" -p SubState --value)
  case "$active_state:$sub_state" in
    active:*|activating:*|*:auto-restart)
      sleep 1
      ;;
    failed:*)
      exit 1
      ;;
    *)
      exit 0
      ;;
  esac
done
