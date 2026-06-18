#!/bin/bash
# Start mock server + auto-connect RGB30 Godot terminal
# Usage: ./start_mock.sh
# Press Ctrl+C to stop mock server
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RGB30_IP="192.168.31.125"
RGB30_PASS="rocknix"
BINARY="$SCRIPT_DIR/../godot_terminal/build/rgb30_diag_terminal_arm64"
REMOTE_PATH="/storage/handheld_terminal_godot/rgb30_diag_terminal_arm64"

echo "============================================"
echo "  Mock ESP32 CAN Dongle + RGB30 Launcher"
echo "============================================"

# 1. Kill old mock server
pkill -f mock_dongle.py 2>/dev/null && echo "[OK] Stopped old mock server" || true
sleep 0.5

# 2. Start mock server in background
cd "$SCRIPT_DIR"
python3 mock_dongle.py &
MOCK_PID=$!
sleep 2

# 3. Check RGB30
echo ""
echo "--- RGB30 ---"
if ping -c 1 -W 1 "$RGB30_IP" > /dev/null 2>&1; then
    echo "[OK] RGB30 online at $RGB30_IP"

    # Test SSH
    if sshpass -p "$RGB30_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"$RGB30_IP" "echo ssh_ok" 2>/dev/null; then
        echo "[OK] SSH connected"

        # Deploy and restart Godot
        if [ -f "$BINARY" ]; then
            echo "[..] Deploying Godot binary..."
            sshpass -p "$RGB30_PASS" scp -o StrictHostKeyChecking=no "$BINARY" root@"$RGB30_IP":"$REMOTE_PATH" 2>/dev/null

            sshpass -p "$RGB30_PASS" ssh -o StrictHostKeyChecking=no root@"$RGB30_IP" "
                systemctl stop diag-terminal.service 2>/dev/null || true
                pkill -9 rgb30_diag_terminal 2>/dev/null || true
                sleep 1
                nohup bash -c 'systemctl restart sway.service; sleep 5;
                  swaymsg output DSI-1 enable; swaymsg output DSI-1 mode 720x720; swaymsg output DSI-1 power on' > /tmp/sway_restart.log 2>&1 &
            " 2>/dev/null
            sleep 6

            sshpass -p "$RGB30_PASS" ssh -o StrictHostKeyChecking=no root@"$RGB30_IP" "
                export XDG_RUNTIME_DIR=/var/run/0-runtime-dir
                export WAYLAND_DISPLAY=wayland-1
                export SWAYSOCK=/run/0-runtime-dir/sway-ipc.0.sock
                export MALI_WAYLAND_AFBC=0
                export GODOT_SILENCE_ROOT_WARNING=1
                cd /storage/handheld_terminal_godot
                nohup ./rgb30_diag_terminal_arm64 \
                  --display-driver wayland \
                  --rendering-method gl_compatibility \
                  --fullscreen \
                  --resolution 720x720 \
                  > /tmp/godot_terminal.log 2>&1 &
                sleep 3
                pidof rgb30_diag_terminal_arm64 && echo '[OK] Godot running' || echo '[ERR] Godot failed to start'
            " 2>/dev/null
        else
            echo "[WARN] Godot binary not found, skipping deploy"
        fi
    else
        echo "[WARN] SSH failed - RGB30 may need reboot"
    fi
else
    echo "[WARN] RGB30 offline - mock server running, will accept connection when RGB30 comes online"
fi

echo ""
echo "============================================"
echo "  Mock Server:  http://localhost:8080"
echo "  UDP Dongle:   0.0.0.0:5000"
echo "  PID:          $MOCK_PID"
echo "  Ctrl+C to stop"
echo "============================================"

# 4. Wait for mock server (keep it in foreground for Ctrl+C)
wait $MOCK_PID
