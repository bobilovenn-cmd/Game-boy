#!/bin/bash
# Quick start: Mock ESP32 CAN Dongle Server
# Usage: ./start_mock.sh
#
# Starts the mock UDP server on port 5000 with web dashboard on port 8080.
# The RGB30 Godot terminal needs DONGLE_IP set to this Mac's IP.
#
# To stop: press Ctrl+C (or pkill -f mock_dongle.py)

cd "$(dirname "$0")"
echo "Starting Mock Motor Server..."
echo "  UDP:  0.0.0.0:5000"
echo "  Web:  http://localhost:8080"
echo "  Press Ctrl+C to stop"
echo ""
python3 mock_dongle.py
