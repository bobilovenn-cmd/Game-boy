# ESP32 编译环境与 RGB30 通信协议

## 一、Zephyr 编译环境

### 1. 工具链

| 组件 | 版本/路径 |
|------|----------|
| Zephyr RTOS | 4.4.99, `~/zephyrproject/zephyr/` |
| Zephyr SDK | 1.0.1, `~/zephyr-sdk-1.0.1/` |
| 编译器 | xtensa-esp32s3-elf-gcc 12.2.0 (Zephyr SDK 自带) |
| 工具链变体 | `zephyr` |
| Python 虚拟环境 | `~/zephyrproject/.venv/` |
| West | 1.5.0 |
| esptool | v5.2.0 |
| 固件源码 | `~/GameBoy/dongle_firmware/can_dongle/` |
| 构建输出 | `~/esp32-can-dongle/build-can-dongle/` |

### 2. 编译命令

```bash
cd ~/zephyrproject && source .venv/bin/activate

west build -b esp32s3_devkitc/esp32s3/procpu \
  ~/GameBoy/dongle_firmware/can_dongle \
  -d ~/esp32-can-dongle/build-can-dongle \
  -- -DZEPHYR_TOOLCHAIN_VARIANT=zephyr \
     -DDTC_OVERLAY_FILE=~/GameBoy/dongle_firmware/can_dongle/boards/esp32s3_devkitc.overlay
```

### 3. 烧录命令

```bash
west flash -d ~/esp32-can-dongle/build-can-dongle
```

设备: ESP32-S3, 串口 `/dev/cu.usbmodem*`, 921600 bps.

### 4. 硬件

| 项目 | 值 |
|------|-----|
| 模块 | Waveshare ESP32-S3-RS485-CAN |
| 芯片 | ESP32-S3, 16MB Flash, 40MHz 晶振 |
| CAN 引脚 | TX=GPIO15, RX=GPIO16 (内部上拉) |
| CAN 速率 | 1000 kbps |
| CAN 收发器 | TJA1050 |
| RS485 收发器 | SP3485 |
| 板级 overlay | `boards/esp32s3_devkitc.overlay` |

### 5. prj.conf

```
CONFIG_WIFI=y
CONFIG_NETWORKING=y
CONFIG_NET_UDP=y
CONFIG_NET_SOCKETS=y
CONFIG_NET_IPV4=y
CONFIG_CAN=y
CONFIG_JSON_LIBRARY=y
CONFIG_MAIN_STACK_SIZE=8192
CONFIG_HEAP_MEM_POOL_SIZE=65536
```

---

## 二、通信架构

### 1. 网络拓扑

ESP32 和 RGB30 通过同一 Wi-Fi 路由器通信（STA 模式）：

| 设备 | IP | UDP 端口 |
|------|-----|---------|
| ESP32 | 192.168.31.126 | 5000 (监听) |
| RGB30 | 192.168.31.125 | 5001 (监听) |
| Mac | 192.168.31.128 | - |

- Wi-Fi SSID: `HC_PRODUCTS_TEST_ANT`
- 心跳: 150ms
- 格式: JSON over UDP

### 2. 数据流

```
RGB30 ──heartbeat──> ESP32 ──ack──> RGB30
RGB30 <──motor_status (100ms)── ESP32
RGB30 ──enable/jog/sdo──> ESP32 ──ack──> RGB30
                              ESP32 ──SDO──> 电机(CAN)
                              电机 ──SDO response──> ESP32
```

ESP32 通过 CANopen SDO 从电机读取数据，封装为 JSON 发给 RGB30。RGB30 只负责显示。

---

## 三、JSON 协议

### 3.1 命令 (RGB30 → ESP32, port 5000)

**heartbeat** — 心跳
```json
{"cmd":"heartbeat","seq":1,"ts":...,"payload":{"node":2}}
```

**enable** — 使能
```json
{"cmd":"enable","seq":2,"ts":...,"payload":{"node":2}}
```

**disable** — 失能
```json
{"cmd":"disable","seq":3,"ts":...,"payload":{"node":2}}
```

**estop** — 急停
```json
{"cmd":"estop","seq":4,"ts":...}
```

**jog_start** — 点动
```json
{"cmd":"jog_start","seq":5,"ts":...,"payload":{"node":2,"direction":"cw","speed":500}}
```
direction: "cw" | "ccw", speed: rpm

**jog_stop** — 停止点动
```json
{"cmd":"jog_stop","seq":6,"ts":...,"payload":{"node":2}}
```

**sdo_read** — 读对象字典
```json
{"cmd":"sdo_read","seq":7,"ts":...,"payload":{"node":2,"index":24641,"sub":0}}
```

**sdo_write** — 写对象字典
```json
{"cmd":"sdo_write","seq":8,"ts":...,"payload":{"node":2,"index":24640,"sub":0,"data":15}}
```

**OTA 命令**:
```json
{"cmd":"ota_start","seq":9,"ts":0,"payload":{"size":65536,"md5":"..."}}
{"cmd":"ota_chunk","seq":10,"ts":0,"payload":{"offset":0,"data":"<base64>"}}
{"cmd":"ota_verify","seq":11,"ts":0}
{"cmd":"ota_flash","seq":12,"ts":0,"payload":{"node":2}}
```

### 3.2 响应 (ESP32 → RGB30, port 5001)

**ack** — 应答
```json
{"cmd":"ack","seq":1,"ts":0,"payload":{"status":"ok","msg":"alive","node":2}}
```
status: "ok" | "error"

**motor_status** — 电机实时数据 (100ms 周期)
```json
{"cmd":"motor_status","seq":0,"ts":0,"payload":{
  "current":"1.23",
  "voltage":"24.0",
  "speed":500,
  "position":"45.2",
  "torque":"0.15",
  "status_word":39,
  "fault":0,
  "mode":3,
  "alive":true,
  "wdg_ms":480
}}
```

| 字段 | 含义 | 单位 |
|------|------|------|
| current | 实际电流 | A |
| voltage | 母线电压 | V |
| speed | 实际转速 | pulse/s |
| position | 实际位置 | - |
| torque | 实际扭矩 | Nm |
| status_word | CiA 402 状态字 | - |
| fault | 故障码 (0=正常) | - |
| mode | 运行模式 (3=速度) | - |
| alive | 电机在线 | bool |
| wdg_ms | 看门狗剩余 | ms |

**sdo_read_result**:
```json
{"cmd":"sdo_read_result","seq":7,"ts":0,"payload":{"index":24641,"sub":0,"data":"0x27","node":2}}
```

**can_log**:
```json
{"cmd":"can_log","payload":{"id":"0x188","data":"A1 B2 C3 D4","dlc":4}}
```

**ota_status**:
```json
{"cmd":"ota_status","seq":9,"ts":0,"payload":{"state":"ready","msg":"ready"}}
```

---

## 四、CANopen 对象字典 (CiA 402)

| 索引 | 名称 | 作用 |
|------|------|------|
| 0x1000 | Device Type | 电机识别 |
| 0x6040 | Control Word | 使能控制 |
| 0x6041 | Status Word | 状态读取 |
| 0x6060 | Modes of Operation | 模式设置 |
| 0x606C | Velocity Actual | 实际速度 |
| 0x6064 | Position Actual | 实际位置 |
| 0x6077 | Torque Actual | 实际扭矩 |
| 0x6079 | DC Link Voltage | 母线电压 |
| 0x3001 | Current Actual | 实际电流 |
| 0x60FF | Target Velocity | 目标速度(点动) |
| 0x6081 | Profile Velocity | 速度上限 |
| 0x6083 | Profile Acceleration | 加速度 |
| 0x6084 | Profile Deceleration | 减速度 |

### 使能序列

```
Shutdown (0x0006) → Switch On (0x0007) → Enable Operation (0x000F)
```

---

## 五、RGB30 按键映射

| 按键 | js0 ID | 功能 |
|------|--------|------|
| B | 0 | back |
| A | 1 | confirm |
| X | 2 | enable |
| Y | 3 | disable |
| L1 | 4 | jog_ccw |
| R1 | 5 | jog_cw |
| L2 | 6 | estop |
| R2 | 7 | (保留) |
| Select | 8 | estop |
| Start | 9 | menu |
| Up | 13 | up |
| Down | 14 | down |
| Left | 15 | left |
| Right | 16 | right |

---

## 六、关键文件

| 内容 | 路径 |
|------|------|
| ESP32 固件 | `~/GameBoy/dongle_firmware/can_dongle/src/` |
| CAN overlay | `~/GameBoy/dongle_firmware/can_dongle/boards/esp32s3_devkitc.overlay` |
| Wi-Fi 密钥 | `~/GameBoy/dongle_firmware/can_dongle/src/wifi_secrets.h` |
| JSON 协议 (ESP32) | `json_protocol.c/h` |
| JSON 协议 (Godot) | `~/GameBoy/godot_terminal/scripts/protocol.gd` |
| Godot 终端 | `~/GameBoy/godot_terminal/` |
| Mock Server | `~/GameBoy/mock_server/` |
| Zephyr 项目 | `~/zephyrproject/` |
| 构建输出 | `~/esp32-can-dongle/build-can-dongle/` |
