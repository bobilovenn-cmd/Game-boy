---
name: project-dongle-phase0
description: ESP32 CAN Dongle Phase 0 固件编译烧录成功，Wi-Fi AP + CAN + UDP 全部正常，已验证手机 ping 通
metadata: 
  node_type: memory
  type: project
  originSessionId: bcfa578f-bc92-495b-8416-6f53ab096f3b
---

Phase 0 固件已成功编译、烧录并通过初步连通性测试。

**Why:** ESP32-S3 CAN Dongle 是 RGB30 手持诊断工具与 CAN 总线之间的桥梁。Phase 0 目标是 UDP + CAN 原始网关。

**当前状态 (2026-06-12):**

| 模块 | 状态 |
|------|------|
| Wi-Fi AP `CAN_Dongle_01` | 正常，手机/Mac 可连接 |
| 静态 IP 192.168.4.1 | 手机可 ping 通 |
| DHCP 服务器 | 已启用 (池 192.168.4.100+)，但不太稳定，建议客户端设静态 IP |
| CAN 1000 kbps | 已初始化 |
| UDP :5000 | 监听中 |
| 看门狗 500ms | 已就绪 |

**固件文件:**
- `/Users/guoweifeng/esp32-can-dongle/build-can-dongle/zephyr/zephyr.bin` (409 KB)
- `/Users/guoweifeng/esp32-can-dongle/build-can-dongle/zephyr/zephyr.elf`

**内存占用:** ROM 4.6%, DRAM 61.9%, IRAM 14.5%

**硬件:**
- 芯片: ESP32-S3 (QFN56, rev v0.2), 16MB Flash, 8MB PSRAM
- USB: USB-Serial/JTAG (macOS 设备: /dev/tty.usbmodem*)
- MAC: 28:84:85:49:95:c8

**Zephyr 3.6.0 API 适配关键修复:**
1. CAN API: `can_receive()` → `CAN_MSGQ_DEFINE` + `can_add_rx_filter_msgq()` + `k_msgq_get()`; `can_send` → `can_raw_send`
2. Wi-Fi AP: `NET_REQUEST_WIFI_AP_ENABLE` + `wifi_connect_req_params`; ESP32 驱动不触发 `NET_EVENT_WIFI_AP_ENABLE_RESULT` 事件
3. `json_parse` → `cmd_json_parse` 避免与 ESP supplicant 库冲突
4. 控制台: 必须用 `&usb_serial` + `CONFIG_EARLY_CONSOLE=y`，禁用 `&uart0`
5. DTS overlay: `&wifi { status = "okay"; }` + `&twai { bus-speed = <1000000>; }`
6. prj.conf: `CONFIG_NET_L2_ETHERNET=y` + `CONFIG_NET_DHCPV4_SERVER=y` + `CONFIG_WIFI_LOG_LEVEL_DBG=y`
7. `west blobs fetch hal_espressif` 获取 RF 库
8. 初始化顺序: `net_if_up()` → `NET_REQUEST_WIFI_AP_ENABLE()` → DHCP server → UDP socket

**编译/烧录命令:**
```bash
cd /Users/guoweifeng/esp32-can-dongle
source /Users/guoweifeng/zephyrproject/.venv/bin/activate
west build -b esp32s3_devkitm /Users/guoweifeng/GameBoy/dongle_firmware/can_dongle -d build-can-dongle
west flash -d build-can-dongle --runner esp32 --esp-device=/dev/tty.usbmodem114401
```

**监控串口:**
```bash
python3 -c "
import serial, time
ser = serial.Serial('/dev/tty.usbmodem114401', 115200, timeout=1)
ser.setDTR(False); ser.setRTS(True); time.sleep(0.1); ser.setRTS(False)
time.sleep(1.5)
ser.reset_input_buffer()
while True:
    line = ser.readline()
    if line: print(line.decode(errors='replace'), end='', flush=True)
"
```

**Godot 终端:**
- DONGLE_IP 已改为 `192.168.4.1` (`/Users/guoweifeng/GameBoy/godot_terminal/scripts/settings.gd`)
- 二进制已导出: `build/rgb30_diag_terminal_arm64`
- RGB30 IP: 192.168.31.125, 密码: rocknix
- 部署: `sshpass -p "rocknix" scp build/rgb30_diag_terminal_arm64 root@192.168.31.125:/storage/handheld_terminal_godot/`

**客户端连接参数:**
- ESP32 dongle: 192.168.4.1:5000 (UDP)
- 客户端静态 IP 建议: 192.168.4.2 (手机) / 192.168.4.3 (Mac)
- 子网掩码: 255.255.255.0, 网关: 192.168.4.1

**下一步:** RGB30 连 CAN_Dongle_01 测试 Godot ↔ ESP32 通信，验证 LINK/UDP 变绿。
