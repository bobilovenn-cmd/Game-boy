#!/bin/sh
# RGB30 firmware upload mode controller.
# Wi-Fi scheme only: do not create a hotspot or change the active network.

set -eu

MODE="${1:-status}"
ROOT="/storage/handheld_terminal_godot"
SERVER="$ROOT/rgb30_firmware_upload_server.py"
PID_FILE="/tmp/agv_firmware_upload.pid"
LOG_FILE="/tmp/agv_firmware_upload.log"
PORT="8080"

pid_running() {
    [ -f "$PID_FILE" ] || return 1
    PID="$(cat "$PID_FILE" 2>/dev/null || true)"
    [ -n "$PID" ] || return 1
    kill -0 "$PID" 2>/dev/null
}

wifi_name() {
    nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null \
        | awk -F: '$2=="wlan0"{print $1; exit}'
}

wifi_ip() {
    ip -4 addr show wlan0 2>/dev/null \
        | awk '/inet /{print $2}' \
        | cut -d/ -f1 \
        | head -n1
}

start_server() {
    if pid_running; then
        return 0
    fi
    nohup /usr/bin/python3 "$SERVER" >"$LOG_FILE" 2>&1 &
    echo "$!" >"$PID_FILE"
}

stop_server() {
    if pid_running; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
}

case "$MODE" in
    start)
        start_server
        SSID="$(wifi_name)"
        IP="$(wifi_ip)"
        [ -n "$SSID" ] || SSID="same_wifi"
        [ -n "$IP" ] || IP="RGB30_IP_NOT_FOUND"
        echo "mode=wifi ssid=$SSID password= url=http://$IP:$PORT"
        ;;
    stop)
        stop_server
        echo "mode=wifi"
        ;;
    status)
        if pid_running; then
            IP="$(wifi_ip)"
            [ -n "$IP" ] || IP="RGB30_IP_NOT_FOUND"
            echo "server=running url=http://$IP:$PORT"
        else
            echo "server=stopped"
        fi
        ;;
    *)
        echo "usage: $0 start|stop|status" >&2
        exit 2
        ;;
esac
