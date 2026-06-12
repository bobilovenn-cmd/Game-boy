---
name: rgb30-host-setup
description: PowKiddy RGB30 作为手持诊断工具母机，Godot 4.6.3 诊断界面，通过 WiFi UDP 与 ESP32 CAN Dongle 通信，mock server 开发调试
metadata:
  node_type: memory
  type: project
  originSessionId: b4c32e84-189c-4a36-8d47-8a901e9505d7
---

RGB30 作为手持诊断工具母机，运行 Godot 诊断界面，通过 WiFi UDP 与 ESP32 CAN Dongle 通信。

**Why:** 用户正在开发 AGV/AMR 电机诊断调试工具，需要一个便携式手持终端。

## 当前状态（2026-06-11）

### Godot 终端 - 已可运行
- Godot 4.6.3 ARM64 通过 Wayland + gl_compatibility 运行
- 停止 Python SDL2 服务 → 重启 sway → 启动 Godot
- Vulkan Mobile 不可靠（swapchain 创建失败），使用 gl_compatibility
- RGB30 UI 可读性已优化（大字号、高对比度颜色）

### Mock Server - 已可运行
- 位置: /Users/guoweifeng/GameBoy/mock_server/
- 启动: `./start_mock.sh` (一键：mock server + RGB30 SSH 部署 + Godot 启动)
- Web Dashboard: http://localhost:8080 (自动刷新，电机控制 + 参数滑块)
- UDP: 0.0.0.0:5000 (模拟 ESP32 dongle)
- 命令: enable/disable/estop/jog_cw/jog_ccw/jog_stop/sdo_read/sdo_write/ota
- motor_status: 10Hz 推送，含电流/电压/转速/位置/扭矩/状态字

### 通信参数
- DONGLE_IP = 192.168.31.128 (Mac IP，开发调试用)
- 实际 ESP32 子机 AP: CAN_Dongle_01, 192.168.4.1:5000
- 母机监听: 5001
- 心跳: 150ms
- 格式: JSON over UDP

### 已修复的 Bug
- 2026-06-11: motor_status 从未发送 — udp_loop 中 update_motor() 消耗时间间隔后第二个 if 永远为 false，合并为一个代码块修复
- 2026-06-11: DONGLE_IP 指向 192.168.4.1 → 改为 Mac IP 192.168.31.128 开发用
- 2026-06-11: Web dashboard JS 自动刷新为空壳 — 改为 500ms AJAX 轮询更新 DOM

### 排障记录
- LINK 绿色 = 收到 motor_status (1.5s 超时变红)
- UDP 绿色 = 本机 5001 端口绑定成功
- 5000 = ESP32/mock 端口，5001 = Godot 监听端口，8080 = Web Dashboard
- start_mock.sh exit code 1 是 sway 重启导致 SSH 断开，不影响功能

### ESP32 硬件（计划）
- 模块: Waveshare ESP32-S3-RS485-CAN
- CAN: GPIO19(RX)/GPIO20(TX), TJA1050 收发器
- RS485: SP3485 收发器
- 终端电阻: 120Ω 跳线帽使能，仅总线两端使用
- 供电: 7-36V DC 或 USB Type-C 5V

## 按键映射（已验证）

| 按键 | ID | 功能 |
|------|-----|------|
| B | 0 | back |
| A | 1 | confirm |
| X | 2 | enable |
| Y | 3 | disable |
| L1 | 4 | jog_ccw |
| R1 | 5 | jog_cw |
| L2 | 6 | estop |
| R2 | 7 | r2 |
| Select | 8 | estop |
| Start | 9 | menu (切换页面) |
| Up | 13 | up |
| Down | 14 | down |
| Left | 15 | left |
| Right | 16 | right |

## 文件位置

| 文件 | 路径 |
|------|------|
| Godot 项目 | /Users/guoweifeng/GameBoy/godot_terminal/ |
| Mock Server | /Users/guoweifeng/GameBoy/mock_server/ |
| Mac 端代码 | /Users/guoweifeng/GameBoy/handheld_terminal/ |
| 设备端 Godot | /storage/handheld_terminal_godot/ |
| 设备端 Python | /storage/handheld_terminal/ |
| 项目文档 | /Users/guoweifeng/GameBoy/手持诊断工具_软件开发教程.md |
| ESP32 子机 | ~/esp32-can-dongle/ |
| systemd 服务 | /storage/.config/system.d/diag-terminal.service |
| 启动脚本 | /storage/handheld_terminal/start.sh |
| Godot 部署脚本 | /Users/guoweifeng/GameBoy/godot_terminal/deploy/rgb30_start_godot.sh |
