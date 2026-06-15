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

## 当前状态（2026-06-15）

### 通信架构（STA 模式）
ESP32 和 RGB30 都连接同一 Wi-Fi 路由器，通过 UDP 通信：

| 设备 | IP | UDP 端口 |
|------|-----|---------|
| ESP32 CAN Dongle | 192.168.31.126 | 5000 |
| RGB30 母机 | 192.168.31.125 | 5001 |
| Mac (开发) | 192.168.31.128 | - |

- Wi-Fi: `HC_PRODUCTS_TEST_ANT`, Gateway `192.168.31.1`
- ESP32 Wi-Fi 配置: `wifi_secrets.h`（git-ignored，需手动创建）
- 心跳: 150ms, 格式: JSON over UDP

### 数据流
- ESP32 通过 CANopen SDO 从电机读取数据，封装为 JSON motor_status，UDP 发给 RGB30
- RGB30 只负责显示，不做解算

### 编译与烧录
```bash
cd ~/zephyrproject && source .venv/bin/activate
west build -b esp32s3_devkitc/esp32s3/procpu \
  ~/GameBoy/dongle_firmware/can_dongle \
  -d ~/esp32-can-dongle/build-can-dongle \
  -- -DZEPHYR_TOOLCHAIN_VARIANT=zephyr \
     -DDTC_OVERLAY_FILE=~/GameBoy/dongle_firmware/can_dongle/boards/esp32s3_devkitc.overlay
west flash -d ~/esp32-can-dongle/build-can-dongle
```

### Godot 终端
- Godot 4.6.3 ARM64, Wayland + gl_compatibility
- Vulkan Mobile 不可靠，使用 gl_compatibility

### Mock Server（开发调试）
- 位置: /Users/guoweifeng/GameBoy/mock_server/
- Web Dashboard: http://localhost:8080
- UDP: 0.0.0.0:5000

### 已修复的 Bug
- 2026-06-11: motor_status 从未发送
- 2026-06-11: DONGLE_IP 配置错误
- 2026-06-11: Web dashboard 自动刷新为空壳

### 排障记录
- LINK 绿色 = 收到 motor_status (1.5s 超时变红)
- UDP 绿色 = 本机 5001 端口绑定成功
- 5000 = ESP32/mock 端口, 5001 = Godot 监听端口, 8080 = Web Dashboard

### ESP32 硬件
- 模块: Waveshare ESP32-S3-RS485-CAN
- CAN 引脚: **GPIO15 (TX), GPIO16 (RX)** + 内部上拉 (esp32s3_devkitc.overlay)
- RS485: SP3485 收发器
- 终端电阻: 120Ω 跳线帽使能
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
