#!/bin/sh
# Stop Godot test process and restore the Python/SDL2 diagnostic terminal.

pkill -f rgb30_diag_terminal_arm64 2>/dev/null || true
systemctl start diag-terminal.service
systemctl is-active diag-terminal.service

