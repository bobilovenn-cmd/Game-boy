#!/bin/sh
# connect_dongle.sh — 自动连接 CAN Dongle 热点
# 用于 ROCKNIX (nmcli 或手动 wpa_supplicant)

SSID="CAN_Dongle_01"
PASSWORD="C@nDongle2024"
MAX_RETRIES=30

echo "Scanning for CAN Dongle hotspot..."
for i in $(seq 1 $MAX_RETRIES); do
    # 尝试用 nmcli 连接
    if command -v nmcli >/dev/null 2>&1; then
        nmcli device wifi rescan 2>/dev/null
        sleep 1
        nmcli device wifi connect "$SSID" password "$PASSWORD" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "Connected to $SSID"
            sleep 2
            ping -c 1 -W 2 192.168.4.1 > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "CAN Dongle reachable"
                exit 0
            fi
        fi
    fi
    echo "Retry $i/$MAX_RETRIES..."
    sleep 2
done
echo "Failed to connect to CAN Dongle"
exit 1
