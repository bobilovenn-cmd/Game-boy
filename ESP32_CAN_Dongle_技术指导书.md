# ESP32 CAN Dongle 固件技术指导书

> **项目名称:** AGV 手持诊断与调试工具 — ESP32 CAN Dongle 固件
> **文档版本:** v1.0
> **编写日期:** 2026-06-15
> **适用硬件:** Waveshare ESP32-S3-RS485-CAN / ESP32-S3-DevKitC / ESP32-S3-DevKitM
> **当前阶段:** Phase 0 完成 (UDP + CAN 原始网关)，Phase 1 开发中 (CANopen 电机控制)

---

## 目录

1. [系统架构概览](#1-系统架构概览)
2. [硬件规格](#2-硬件规格)
3. [引脚定义与接线](#3-引脚定义与接线)
4. [开发环境搭建](#4-开发环境搭建)
5. [工具链与版本清单](#5-工具链与版本清单)
6. [固件源码结构](#6-固件源码结构)
7. [构建配置文件详解](#7-构建配置文件详解)
8. [软件模块架构](#8-软件模块架构)
9. [通信协议规范 (UDP JSON)](#9-通信协议规范)
10. [CAN / CANopen 协议细节](#10-can--canopen-协议细节)
11. [编译与烧录流程](#11-编译与烧录流程)
12. [调试与监控](#12-调试与监控)
13. [安全机制](#13-安全机制)
14. [测试清单](#14-测试清单)
15. [常见问题排查](#15-常见问题排查)
16. [附录：快速参考卡](#16-附录快速参考卡)

---

## 1. 系统架构概览

本项目是一个**三层 AGV 电机诊断系统**：

```
┌─────────────────────────────────────────┐
│  RGB30 手持终端 (ROCKNIX Linux)          │
│  ├── Godot 4.6.3 诊断 UI (主要)          │
│  └── Python/SDL2 终端 (备用)             │
│       ↓ 本地UDP:5001                     │
└──────────────┬──────────────────────────┘
               │  Wi-Fi (UDP JSON)
               │
┌──────────────▼──────────────────────────┐
│  ESP32-S3 CAN Dongle ← 【本文件范围】     │
│  ├── Zephyr RTOS 固件                    │
│  ├── Wi-Fi AP "CAN_Dongle_01"            │
│  ├── UDP Server :5000                    │
│  ├── TWAI (CAN 2.0B 控制器)              │
│  └── CiA 402 CANopen 电机控制            │
│       ↓ CAN 1 Mbps                       │
└──────────────┬──────────────────────────┘
               │  CAN Bus
┌──────────────▼──────────────────────────┐
│  电机驱动器 (CANopen 从站)               │
│  节点 ID: 1..127                        │
│  CiA 402 Profile Velocity Mode          │
└─────────────────────────────────────────┘
```

**核心通信参数:**

| 参数 | 值 |
|------|-----|
| Dongle IP (AP 模式) | `192.168.4.1` |
| Dongle IP (STA 模式) | `192.168.31.126` |
| Dongle UDP 端口 | `5000` |
| RGB30 UDP 端口 | `5001` |
| 数据格式 | UTF-8 JSON |
| 心跳间隔 | 150 ms (RGB30 → Dongle) |
| 心跳超时保护 | 500 ms |
| 电机状态上报周期 | 100 ms |
| CAN 日志上报周期 | 20 ms |

---

## 2. 硬件规格

### 2.1 主控芯片

| 属性 | 规格 |
|------|------|
| **芯片型号** | ESP32-S3 (QFN56) |
| **芯片版本** | rev v0.2 |
| **CPU** | Xtensa LX7 双核, 最高 240 MHz |
| **SRAM** | 512 KB 内置 |
| **PSRAM** | 8 MB (Octal SPI) |
| **Flash** | 16 MB (Quad SPI) |
| **Wi-Fi** | 802.11 b/g/n, 2.4 GHz |
| **蓝牙** | BLE 5.0 (本项目未使用) |
| **CAN 控制器** | 内置 TWAI (Two-Wire Automotive Interface), CAN 2.0B |
| **USB** | USB-Serial/JTAG (原生, 无需外置 UART 芯片) |
| **MAC 地址 (当前硬件)** | `28:84:85:49:95:c8` |

### 2.2 开发板

**主选方案 (当前使用):**
- **型号:** Waveshare ESP32-S3-RS485-CAN (微雪电子)
- **CAN 收发器:** TJA1050
- **CAN 终端电阻:** 120Ω (通过跳线帽控制, 仅总线末端开启)
- **供电:** 7-36V DC 接线端子 或 USB-C 5V

**备用方案 (已验证可用):**
- ESP32-S3-DevKitC
- ESP32-S3-DevKitM

### 2.3 固件内存占用 (当前 Phase 0 固件)

| 区域 | 占用比例 |
|------|----------|
| ROM (Flash) | 4.6% |
| DRAM | 61.9% |
| IRAM | 14.5% |
| 固件大小 (zephyr.bin) | 约 409 KB |

---

## 3. 引脚定义与接线

### 3.1 CAN 总线引脚 (TWAI)

ESP32-S3 的 TWAI 控制器可以映射到任意 GPIO，通过设备树 overlay 配置。

**当前使用的两套配置:**

| 配置文件 | 用途 | CAN TX | CAN RX |
|----------|------|--------|--------|
| `esp32s3_devkitc.overlay` | 实际使用的板子 | **GPIO15** | **GPIO16** (内部上拉) |
| `esp32s3_devkitm.overlay` | 通用/参考配置 | GPIO19 | GPIO20 |

> **注意:** `esp32s3_devkitc.overlay` 是当前**实际验证通过**的引脚配置。TX=GPIO15 / RX=GPIO16 + bias-pull-up 已确认可用。编译时通过 `-b esp32s3_devkitm` 指定板级，但 overlay 可以覆盖任意板的默认引脚。

### 3.2 CAN 收发器接线 (TJA1050)

```
ESP32-S3          TJA1050          CAN Bus
─────────         ────────         ───────
GPIO15 (TX)  →    TXD (1)          CANH (7) ─── CAN_H ─── 电机驱动器
GPIO16 (RX)  ←    RXD (4)          CANL (6) ─── CAN_L ─── 电机驱动器
3.3V         →    VCC (3)          Rs  (8) ─── GND (高速模式)
GND          →    GND (2)          Vref(5) ─── 悬空或 VCC/2
```

### 3.3 USB 连接

- ESP32-S3 的 USB-Serial/JTAG 口直接连接 Mac USB-C
- macOS 识别为 `/dev/tty.usbmodem*` (设备名包含序列号)
- 当前硬件设备: `/dev/tty.usbmodem114401`
- 波特率: **115200** (串口日志)
- 该 USB 口同时用于烧录固件和查看日志

### 3.4 其他关键引脚

| 功能 | 引脚 | 说明 |
|------|------|------|
| 串口日志 | USB-Serial/JTAG | Zephyr console 输出, 禁用 UART0 |
| 下载模式 | GPIO0 (BOOT) | 烧录时拉低进入下载模式 |
| 复位 | EN (RESET) | 复位引脚 |

---

## 4. 开发环境搭建

### 4.1 macOS 系统依赖

```bash
# 安装 Homebrew (如已安装可跳过)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装编译工具链
brew install cmake ninja gperf python3 ccache dtc wget
```

### 4.2 Zephyr 开发环境 (已配置, 路径记录)

当前 Mac 上已有的 Zephyr 环境：

| 组件 | 路径 |
|------|------|
| Zephyr 工作区 | `/Users/guoweifeng/esp32-can-dongle` |
| Zephyr 源码 | `/Users/guoweifeng/zephyrproject/zephyr` |
| Python 虚拟环境 | `/Users/guoweifeng/zephyrproject/.venv` |
| West 工具 | `/Users/guoweifeng/zephyrproject/.venv/bin/west` |
| 工具链 SDK | `/Users/guoweifeng/zephyr-sdk-1.0.1` |
| Xtensa GCC | `/Users/guoweifeng/zephyr-sdk-1.0.1/gnu/xtensa-espressif_esp32s3_zephyr-elf/` |
| ESP32 RF 库 | `west blobs fetch hal_espressif` 已执行 |
| 项目固件源码 | `/Users/guoweifeng/GameBoy/dongle_firmware/can_dongle` |
| 构建输出目录 | `/Users/guoweifeng/esp32-can-dongle/build-can-dongle` |

### 4.3 环境变量 (需要加入 `~/.zshrc`)

```bash
export ZEPHYR_TOOLCHAIN_VARIANT=espressif
export ESPRESSIF_TOOLCHAIN_PATH=~/.espressif/tools/zephyr
```

### 4.4 从头搭建 Zephyr 环境 (如果换新 Mac)

```bash
# 1. 安装 west
pip3 install west

# 2. 创建工作区
mkdir -p ~/esp32-can-dongle && cd ~/esp32-can-dongle

# 3. 初始化 Zephyr 工程 (v3.6.0)
west init -m https://github.com/zephyrproject-rtos/zephyr --mr v3.6.0
west update

# 4. 安装 Python 依赖
pip3 install -r zephyr/scripts/requirements.txt

# 5. 安装 ESP32 交叉编译工具链
west espressif install

# 6. 获取 ESP32 RF/Wi-Fi 闭源库
west blobs fetch hal_espressif

# 7. 设置环境变量
export ZEPHYR_TOOLCHAIN_VARIANT=espressif
export ESPRESSIF_TOOLCHAIN_PATH=~/.espressif/tools/zephyr
```

---

## 5. 工具链与版本清单

| 工具/组件 | 版本 | 说明 |
|-----------|------|------|
| **Zephyr RTOS** | v3.6.0 | 实时操作系统内核 + 驱动框架 |
| **West** | (随 Zephyr) | Zephyr 构建管理工具 |
| **CMake** | ≥ 3.20.0 | 构建系统 (Homebrew 安装) |
| **Ninja** | (Homebrew) | 构建执行器 |
| **Python** | 3.12+ | 构建脚本环境 |
| **Zephyr SDK** | 1.0.1 | 交叉编译工具链 |
| **Xtensa GCC** | xtensa-espressif_esp32s3_zephyr-elf | ESP32-S3 交叉编译器 |
| **esptool** | (Zephyr SDK 自带) | ESP32 烧录工具 |
| **macOS** | ≥ 13 (Ventura) | 开发主机系统 |
| **ccache** | (Homebrew) | 编译缓存加速 |
| **dtc** | (Homebrew) | 设备树编译器 |

> **Zephyr 3.6.0 API 关键注意事项:**
> 1. CAN 接收使用 `CAN_MSGQ_DEFINE` + `can_add_rx_filter_msgq()` + `k_msgq_get()`，不再使用旧的 `can_receive()`
> 2. Wi-Fi AP 使用 `NET_REQUEST_WIFI_AP_ENABLE` + `wifi_connect_req_params`
> 3. ESP32 Wi-Fi 驱动不会触发 `NET_EVENT_WIFI_AP_ENABLE_RESULT` 事件
> 4. 控制台必须使用 `&usb_serial`，禁用 `&uart0`
> 5. 需要 `CONFIG_EARLY_CONSOLE=y` 才能在启动早期看到日志
> 6. JSON 解析函数命名为 `cmd_json_parse` 以避免与 ESP supplicant 库的 `json_parse` 冲突
> 7. `CONFIG_CAN_AUTO_BUS_OFF_RECOVERY` 在 Zephyr 4.4 已移除

---

## 6. 固件源码结构

```
/Users/guoweifeng/GameBoy/dongle_firmware/
├── README.md                       # 固件开发总体说明
├── 零基础操作教程.md                 # 零基础入门教程
└── can_dongle/                     # 【固件工程根目录】
    ├── .gitignore
    ├── CMakeLists.txt              # CMake 构建脚本
    ├── prj.conf                    # Zephyr Kconfig 配置
    ├── boards/
    │   ├── esp32s3_devkitm.overlay # 设备树 overlay (通用, CAN 使用默认引脚)
    │   └── esp32s3_devkitc.overlay # 设备树 overlay (当前使用, TX=GPIO15 RX=GPIO16)
    └── src/
        ├── main.c                  # 主程序入口 + 主循环 + 命令分发
        ├── udp_comm.c / .h         # Wi-Fi AP + UDP 通信模块
        ├── can_raw.c / .h          # CAN 原始帧收发 (TWAI 驱动)
        ├── canopen_basic.c / .h    # CiA 402 CANopen 电机控制
        ├── json_protocol.c / .h    # JSON 协议解析与构建 (轻量级自实现)
        ├── watchdog.c / .h         # 心跳看门狗 (500ms 超时保护)
        ├── wifi_config.h           # Wi-Fi 模式配置 (AP/STA)
        ├── wifi_secrets.h          # 本地 Wi-Fi 密码 (gitignored)
        └── wifi_secrets.example.h  # Wi-Fi 密码配置模板
```

---

## 7. 构建配置文件详解

### 7.1 CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(can_dongle)

# 如果存在本地 Wi-Fi 密码文件，定义编译宏
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/wifi_secrets.h")
  target_compile_definitions(app PRIVATE DONGLE_USE_LOCAL_WIFI_SECRETS=1)
endif()

# 所有固件源码文件
target_sources(app PRIVATE
  src/main.c
  src/udp_comm.c
  src/can_raw.c
  src/canopen_basic.c
  src/json_protocol.c
  src/watchdog.c
)
```

### 7.2 prj.conf (Kconfig 配置)

```ini
# ---- Early Console (调试必需) ----
CONFIG_EARLY_CONSOLE=y
CONFIG_CONSOLE=y
CONFIG_UART_CONSOLE=y

# ---- Wi-Fi + Networking ----
CONFIG_WIFI=y
CONFIG_WIFI_LOG_LEVEL_DBG=y
CONFIG_NETWORKING=y
CONFIG_NET_L2_ETHERNET=y
CONFIG_NET_UDP=y
CONFIG_NET_SOCKETS=y
CONFIG_NET_IPV4=y
CONFIG_NET_IPV6=n
CONFIG_NET_CONFIG_AUTO_INIT=n

# ---- DHCP Server (AP 模式下给客户端分配 IP) ----
CONFIG_NET_DHCPV4_SERVER=y
CONFIG_NET_DHCPV4_SERVER_LOG_LEVEL_DBG=n

# ---- CAN ----
CONFIG_CAN=y

# ---- Logging ----
CONFIG_LOG=y
CONFIG_LOG_DEFAULT_LEVEL=3        # 0=OFF, 1=ERR, 2=WRN, 3=INF, 4=DBG
CONFIG_LOG_PRINTK=y

# ---- JSON support ----
CONFIG_JSON_LIBRARY=y

# ---- Memory ----
CONFIG_MAIN_STACK_SIZE=8192
CONFIG_HEAP_MEM_POOL_SIZE=65536

# ---- Shell (debug only, disable for production) ----
CONFIG_SHELL=n

# ---- Assert ----
CONFIG_ASSERT=y
```

### 7.3 设备树 Overlay

**esp32s3_devkitc.overlay (当前使用):**

```dts
/ {
    aliases {
        can0 = &twai;
    };
    chosen {
        zephyr,console = &usb_serial;
        zephyr,shell-uart = &usb_serial;
    };
};

&wifi {
    status = "okay";
};

&usb_serial {
    status = "okay";
};

&uart0 {
    status = "disabled";     /* 必须禁用, 否则影响 USB-Serial 日志 */
};

&twai {
    status = "okay";
    bus-speed = <1000000>;   /* CAN 1 Mbps */
    pinctrl-0 = <&twai_custom>;
    pinctrl-names = "default";
};

&pinctrl {
    twai_custom: twai_custom {
        group1 {
            pinmux = <TWAI_TX_GPIO15>,
                     <TWAI_RX_GPIO16>;
            bias-pull-up;    /* RX 内部上拉, 提高抗干扰能力 */
        };
    };
};
```

### 7.4 Wi-Fi 配置

**wifi_config.h (默认 AP 模式):**

```c
#define DONGLE_WIFI_MODE_AP  0
#define DONGLE_WIFI_MODE_STA 1

#define DONGLE_WIFI_MODE     DONGLE_WIFI_MODE_AP  /* 默认自建热点 */

#define DONGLE_AP_SSID       "CAN_Dongle_01"
#define DONGLE_AP_IP         "192.168.4.1"
#define DONGLE_AP_NETMASK    "255.255.255.0"
#define DONGLE_AP_GATEWAY    "192.168.4.1"

/* STA 模式默认值 (在 wifi_secrets.h 中覆盖) */
#define DONGLE_STA_SSID      ""
#define DONGLE_STA_PASSWORD  ""
#define DONGLE_STA_IP        "192.168.31.126"
#define DONGLE_STA_NETMASK   "255.255.255.0"
#define DONGLE_STA_GATEWAY   "192.168.31.1"
```

**wifi_secrets.example.h (切换到 STA 模式的模板):**

```c
#pragma once

#undef DONGLE_WIFI_MODE
#define DONGLE_WIFI_MODE     DONGLE_WIFI_MODE_STA

#undef DONGLE_STA_SSID
#define DONGLE_STA_SSID      "HC_PRODUCTS_TEST_ANT"

#undef DONGLE_STA_PASSWORD
#define DONGLE_STA_PASSWORD  "PUT_WIFI_PASSWORD_HERE"

#undef DONGLE_STA_IP
#define DONGLE_STA_IP        "192.168.31.126"

#undef DONGLE_STA_GATEWAY
#define DONGLE_STA_GATEWAY   "192.168.31.1"
```

---

## 8. 软件模块架构

### 8.1 模块依赖关系

```
main.c (主程序)
├── udp_comm.c/h      ← wifi_config.h, wifi_secrets.h
├── can_raw.c/h       ← Zephyr CAN driver (TWAI)
├── canopen_basic.c/h ← can_raw.c/h (SDO over CAN raw)
├── json_protocol.c/h ← 独立 (纯 C 字符串解析)
└── watchdog.c/h      ← 独立 (Zephyr k_uptime_get)
```

### 8.2 main.c — 主程序

**启动流程:**
1. `wdg_init()` — 初始化看门狗
2. `udp_init()` — 启动 Wi-Fi AP + UDP :5000
3. `can_init()` — 初始化 CAN 1 Mbps (非致命, CAN 未连接时可继续运行)
4. `can_diag()` — 打印 CAN 控制器状态诊断
5. 进入主循环

**主循环 (10ms 周期):**
- A. `udp_recv()` → `cmd_json_parse()` → `handle_command()` — 接收并处理 UDP 命令
- B. `process_can_frames()` — 收取 CAN 帧, 转发 can_log 给 RGB30, 检测心跳帧
- C. 每 100ms: `send_motor_status()` — 周期性上报电机状态 (轮询 SDO)
- D. `wdg_check()` — 检查心跳超时
- E. `k_msleep(10)` — 微小延迟

**命令处理 handle_command():**
- `estop` — 最高优先级, 不受安全状态限制
- `heartbeat` — 喂狗 + 回复 ack, 不受安全状态限制
- 其他电机控制命令 — 在看门狗安全状态下被拦截

### 8.3 udp_comm.c — Wi-Fi + UDP 通信

**两种工作模式:**
- **AP 模式 (默认):** ESP32 创建 `CAN_Dongle_01` 热点 (开放, 无密码), IP `192.168.4.1`, 频道 6, DHCP 池从 `192.168.4.100` 开始
- **STA 模式:** ESP32 连接到已有路由器 Wi-Fi, 固定 IP `192.168.31.126`

**UDP Socket:**
- 绑定端口 5000, `INADDR_ANY`
- 接收超时 100ms (非阻塞轮询)
- 回复发送给最近通信的客户端地址 (RGB30)
- 支持 `udp_sendto()` 发送给任意地址

**API:**
```c
int udp_init(void);                                    // 初始化 Wi-Fi + UDP
int udp_recv(char *buf, int buf_size, int timeout_ms); // 接收 UDP 报文
int udp_send(const char *data, int len);               // 回复最近客户端
int udp_sendto(const char *data, int len, const char *ip, int port); // 发送到指定地址
const char *udp_client_ip(void);                       // 获取客户端 IP
```

### 8.4 can_raw.c — CAN 原始帧收发

**功能:**
- 初始化 ESP32 TWAI 控制器, 波特率 1 Mbps
- 使用 Zephyr 消息队列 (`CAN_MSGQ_DEFINE`) 缓冲接收帧 (队列深度 16)
- 接收滤波器设为"接收所有帧" (`id=0, mask=0`)
- 发送时支持自动恢复: 检测到 Error-Passive/Bus-Off 后自动重启控制器
- 提供 `can_diag()` 诊断函数打印控制器状态和错误计数

**帧结构:**
```c
typedef struct {
    uint32_t id;       // 标准帧 11 位 或 扩展帧 29 位
    uint8_t  data[8];  // 数据字节
    uint8_t  dlc;      // 数据长度 (0-8)
    bool     ext;      // true = 扩展帧
    bool     rtr;      // true = 远程帧
} can_frame_t;
```

### 8.5 canopen_basic.c — CiA 402 电机控制

**实现方式:** 基于 CAN 原始帧手动构建 SDO 报文, 不依赖外部 CANopen 协议栈。

**SDO 通信参数:**
- SDO TX COB-ID: `0x600 + node_id`
- SDO RX COB-ID: `0x580 + node_id`
- SDO 响应超时: 500ms

**SDO 写入 (co_sdo_write):**
```
发送: 0x600+node | cmd_spec | index(LE) | sub | data(LE)
等待: 0x580+node 响应 (0x60 = OK, 0x80 = Abort)
```

**SDO 读取 (co_sdo_read):**
```
发送: 0x600+node | 0x40 | index(LE) | sub | 0x00000000
等待: 0x580+node 响应 (0x43=32bit, 0x4B=16bit, 0x4F=8bit, 0x80=Abort)
```

**CiA 402 使能流程 (co_basic_enable):**
1. 选择工作模式: Profile Velocity (0x6060 = 3)
2. Fault Reset: 控制字 0x6040 ← 0x0080
3. Shutdown: 控制字 ← 0x0006
4. Switch On: 控制字 ← 0x0007
5. Enable Operation: 控制字 ← 0x000F
6. 验证状态字 (0x6041 & 0x006F) == 0x0027

**运动控制 (co_basic_jog):**
- 使用 Profile Velocity 模式
- 目标速度: UI rpm × 100 → 脉冲/秒
- 正转 (cw) = 正速度, 反转 (ccw) = 负速度

**对象字典 (OD) 索引表:**

| 索引 | 名称 | 说明 | 数据类型 |
|------|------|------|----------|
| 0x6040 | Control Word | CiA 402 控制字 | UINT16 |
| 0x6041 | Status Word | CiA 402 状态字 | UINT16 |
| 0x6060 | Modes of Operation | 工作模式 (3=PV) | INT8 |
| 0x6061 | Modes of Operation Display | 当前工作模式 | INT8 |
| 0x6064 | Actual Position | 实际位置 | INT32 |
| 0x606C | Actual Velocity | 实际速度 | INT32 |
| 0x6077 | Actual Torque | 实际转矩 | INT16 |
| 0x6079 | DC Link Voltage | 母线电压 | INT32 |
| 0x607A | Target Position | 目标位置 | INT32 |
| 0x6081 | Profile Velocity | 轮廓速度 | UINT32 |
| 0x6083 | Profile Acceleration | 轮廓加速度 | UINT32 |
| 0x6084 | Profile Deceleration | 轮廓减速度 | UINT32 |
| 0x60FF | Target Velocity | 目标速度 | INT32 |
| 0x3001 | Current Actual | 实际电流 | INT32 |

**运动参数默认值 (co_init_profile):**
- Profile Velocity: 100000 pulse/s
- Profile Acceleration: 100000 pulse/s²
- Profile Deceleration: 100000 pulse/s²

### 8.6 json_protocol.c — JSON 协议解析

**设计选择:** 使用轻量级 C 字符串扫描, 不依赖外部 JSON 库。Phase 0 适合快速验证, Phase 1 可替换为 cJSON。

**解析方式:** `strstr()` 查找 key → 跳过空白和冒号 → 提取 value

**支持的命令解析:**

| 命令 | 解析的 payload 字段 |
|------|-------------------|
| heartbeat | node |
| enable / disable / jog_stop | node |
| jog_start | node, direction, speed |
| sdo_read | node, index, sub |
| sdo_write | node, index, sub, data |
| ota_start | size, md5 |
| ota_chunk | offset |
| ota_verify / ota_flash | — |

**构建的消息类型:**
- `json_build_ack()` — ack 响应 `{"cmd":"ack","seq":N,"payload":{"status":"ok/error","msg":"...","node":N}}`
- `json_build_motor_status()` — 电机状态上报 (current, voltage, speed, position, torque, status_word, fault, mode, alive, wdg_ms)
- `json_build_can_log()` — CAN 日志 `{"cmd":"can_log","payload":{"id":"0x...","data":"XX XX ...","dlc":N}}`

### 8.7 watchdog.c — 心跳看门狗

**参数:**
- 超时阈值: **500 ms**
- 喂狗方式: 收到 `heartbeat` 命令时调用 `wdg_feed()`
- 安全状态: 超时后自动进入, 拦截所有电机控制命令 (enable/disable/jog)
- estop 和 heartbeat 命令不受安全状态限制
- `wdg_remaining_ms()` 返回距超时的剩余毫秒数, 上报给 RGB30

---

## 9. 通信协议规范 (UDP JSON)

### 9.1 通用消息格式

**请求 (RGB30 → Dongle):**
```json
{
  "cmd": "<命令名>",
  "seq": 123,
  "ts": 1718000000,
  "payload": { ... }
}
```

**响应 (Dongle → RGB30):**
```json
{
  "cmd": "ack",
  "seq": 123,
  "ts": 0,
  "payload": {
    "status": "ok",
    "msg": "操作成功",
    "node": 1
  }
}
```

### 9.2 命令列表

#### heartbeat — 心跳保持
```json
{"cmd":"heartbeat","seq":1,"ts":0}
```
→ 回复 `ack`, 喂看门狗

#### enable — 电机使能
```json
{"cmd":"enable","seq":2,"ts":0,"payload":{"node":1}}
```
→ CiA 402 使能流程: Shutdown → Switch On → Enable Operation

#### disable — 电机失能
```json
{"cmd":"disable","seq":3,"ts":0,"payload":{"node":1}}
```
→ Quick Stop → Disable Voltage

#### estop — 急停
```json
{"cmd":"estop","seq":4,"ts":0}
```
→ 立即 Quick Stop + Disable Voltage, 不检查安全状态

#### jog_start — 点动开始
```json
{"cmd":"jog_start","seq":5,"ts":0,"payload":{"node":1,"direction":"cw","speed":500}}
```
→ 写入目标速度到 0x60FF, 自动配置运动参数 (首次调用时)

#### jog_stop — 点动停止
```json
{"cmd":"jog_stop","seq":6,"ts":0,"payload":{"node":1}}
```
→ 目标速度置 0 + Quick Stop

#### sdo_read — 读取对象字典
```json
{"cmd":"sdo_read","seq":7,"ts":0,"payload":{"node":1,"index":24672,"sub":0}}
```
→ 回复 `sdo_read_result` 消息

#### sdo_write — 写入对象字典
```json
{"cmd":"sdo_write","seq":8,"ts":0,"payload":{"node":1,"index":24672,"sub":0,"data":8}}
```
→ 回复 `ack`

### 9.3 Dongle 上报消息

#### motor_status (每 100ms)
```json
{
  "cmd": "motor_status",
  "seq": 0,
  "ts": 0,
  "payload": {
    "current": 1.25,
    "voltage": 24.5,
    "speed": 1500,
    "position": 180.5,
    "torque": 0.75,
    "status_word": 39,
    "fault": 0,
    "mode": 3,
    "alive": true,
    "wdg_ms": 450
  }
}
```

#### can_log (有 CAN 帧时, 间隔 ≥20ms)
```json
{
  "cmd": "can_log",
  "payload": {
    "id": "0x701",
    "data": "05 A1 B2 C3 D4 E5 F6 07",
    "dlc": 8
  }
}
```

---

## 10. CAN / CANopen 协议细节

### 10.1 CAN 总线参数

| 参数 | 值 |
|------|-----|
| 协议 | CAN 2.0B |
| 波特率 | **1,000,000 bps (1 Mbps)** |
| 终端电阻 | 120Ω (仅总线两端开启) |
| CAN 收发器 | TJA1050 (高速模式, Rs 接 GND) |
| 采样点 | Zephyr 默认 (约 75%) |

### 10.2 CANopen 参数

| 参数 | 值 |
|------|-----|
| 协议栈 | 自实现轻量级 SDO 通信 |
| NMT 主站 | Dongle (节点 ID = 0) |
| 从站节点 ID | 1 .. 127 |
| 默认节点 | 2 (可通过命令切换) |
| SDO 超时 | 500 ms |
| NMT 启动超时 | 5000 ms |
| 心跳检测 (CAN 层) | 监听 0x700 + node_id 的心跳帧 |
| 控制模式 | Profile Velocity (CiA 402 模式 3) |

### 10.3 CiA 402 状态机

```
         ┌─────────┐
         │ Not Ready│ (0x0000)
         └────┬─────┘
              ▼
         ┌─────────┐
         │ Switch On│ (0x0040)
         │ Disabled │
         └────┬─────┘
              │ Shutdown (0x0006)
              ▼
         ┌─────────┐
         │  Ready   │ (0x0021)
         └────┬─────┘
              │ Switch On (0x0007)
              ▼
         ┌─────────┐
         │ Switched │ (0x0023)
         │   On     │
         └────┬─────┘
              │ Enable Operation (0x000F)
              ▼
         ┌─────────┐
         │ Enabled  │ (0x0027)
         └─────────┘
              │ Fault → 0x0008
              ▼
         ┌─────────┐
         │  FAULT   │ (0x0008)
         └─────────┘
```

---

## 11. 编译与烧录流程

### 11.1 编译

```bash
# 1. 进入 Zephyr 工作区
cd /Users/guoweifeng/esp32-can-dongle

# 2. 激活 Python 虚拟环境
source /Users/guoweifeng/zephyrproject/.venv/bin/activate

# 3. 编译固件 (使用 esp32s3_devkitc overlay 配置)
west build -b esp32s3_devkitm \
    /Users/guoweifeng/GameBoy/dongle_firmware/can_dongle \
    -d build-can-dongle

# 或者清理后重新编译
west build -b esp32s3_devkitm \
    /Users/guoweifeng/GameBoy/dongle_firmware/can_dongle \
    -d build-can-dongle --pristine
```

**编译输出:**
- 固件二进制: `build-can-dongle/zephyr/zephyr.bin` (~409 KB)
- ELF 文件: `build-can-dongle/zephyr/zephyr.elf`
- 编译数据库: `build-can-dongle/compile_commands.json`

### 11.2 烧录

```bash
# 方法 1: west flash (自动检测串口)
cd /Users/guoweifeng/esp32-can-dongle
source /Users/guoweifeng/zephyrproject/.venv/bin/activate
west flash -d build-can-dongle

# 方法 2: 手动指定 USB 设备
west flash -d build-can-dongle \
    --runner esp32 \
    --esp-device=/dev/tty.usbmodem114401

# 方法 3: 如果自动进入下载模式失败
# 1. 按住 BOOT 按钮
# 2. 按一下 RESET 按钮
# 3. 松开 BOOT 按钮
# 4. 立即执行 west flash
```

### 11.3 查看 USB 设备

```bash
# 查看可用串口
ls /dev/cu.*
# 通常输出: /dev/cu.usbmodem114401 或 /dev/cu.usbserial-*

# 查看 USB 设备详情
system_profiler SPUSBDataType | grep -A5 -i "serial\|uart"
```

---

## 12. 调试与监控

### 12.1 查看串口日志

```bash
# 方法 1: 使用 Python pyserial (最可靠)
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

# 方法 2: west espressif monitor (如果可用)
cd /Users/guoweifeng/esp32-can-dongle
source /Users/guoweifeng/zephyrproject/.venv/bin/activate
west espressif monitor

# 方法 3: screen (退出: Ctrl+A → K → Y)
screen /dev/tty.usbmodem114401 115200
```

### 12.2 网络调试

```bash
# Mac 连接 CAN_Dongle_01 热点后:

# 测试连通性
ping 192.168.4.1

# 发送 UDP 测试包 (心跳)
echo '{"cmd":"heartbeat","seq":1,"ts":0}' | nc -u -w1 192.168.4.1 5000

# 发送 UDP 测试包 (使能电机)
echo '{"cmd":"enable","seq":2,"ts":0,"payload":{"node":2}}' | nc -u -w1 192.168.4.1 5000

# 抓包分析
sudo tcpdump -i en0 udp port 5000 -v
```

### 12.3 日志输出示例

正常启动后的日志:

```
========================================
ESP32 CAN Dongle Firmware
Phase 0: UDP + CAN Raw Gateway
========================================
[00:00:02.123] <inf> udp_comm: Wi-Fi interface: 0x3fc9xxxx
[00:00:07.456] <inf> udp_comm: Wi-Fi AP 'CAN_Dongle_01' started, IP: 192.168.4.1
[00:00:07.789] <inf> udp_comm: DHCP server started, pool from 192.168.4.100
[00:00:07.890] <inf> udp_comm: UDP socket listening on port 5000
[00:00:08.012] <inf> can_raw: CAN device: twai
[00:00:08.123] <inf> can_raw: CAN initialized at 1000 kbps
[00:00:08.123] <inf> can_raw: === CAN Diagnostics ===
[00:00:08.123] <inf> can_raw:   State: Error-Active (OK)
[00:00:08.123] <inf> can_raw:   TX errors: 0, RX errors: 0
[00:00:08.123] <inf> can_raw: ========================
[00:00:08.123] <inf> main: Dongle ready. Waiting for RGB30 heartbeat...
[00:00:08.123] <inf> main: SSID: CAN_Dongle_01  IP: 192.168.4.1  UDP: 5000
[00:00:08.500] <inf> watchdog: First heartbeat received — watchdog armed
[00:00:08.500] <inf> watchdog: Watchdog: safe state cleared
```

### 12.4 日志级别调整

在 `prj.conf` 中修改:

```ini
CONFIG_LOG_DEFAULT_LEVEL=4   # 0=OFF, 1=ERR, 2=WRN, 3=INF, 4=DBG
```

单个模块代码中覆盖日志级别 (如 `main.c` 中):
```c
LOG_MODULE_REGISTER(main, LOG_LEVEL_DBG);  // 强制 DEBUG 级别
```

---

## 13. 安全机制

### 13.1 心跳看门狗

| 参数 | 值 |
|------|-----|
| 超时阈值 | **500 ms** |
| 触发条件 | RGB30 停止发送 heartbeat 超过 500ms |
| 安全状态行为 | 拦截所有 enable/disable/jog_start/jog_stop 命令 |
| 不受限制的命令 | heartbeat (可喂狗恢复), estop (始终可执行), sdo_read/write |
| 上报方式 | motor_status.wdg_ms 字段 (剩余毫秒数) |
| 恢复方式 | RGB30 重新发送 heartbeat → 自动清除安全状态 |

### 13.2 急停 (estop)

- estop 是**最高优先级**命令
- 无论看门狗是否在安全状态, estop 都立即执行
- 执行流程: Quick Stop → Disable Voltage
- 电机状态立即标记为 Fault (status_word = 0x0008)

### 13.3 未知命令处理

- 未知命令**必须返回错误**, 不能静默忽略
- 返回 `{"cmd":"ack","payload":{"status":"error","msg":"unknown command"}}`

### 13.4 节点 ID 校验

- 有效范围: 1 .. 127
- 超出范围的节点 ID 在 SDO 操作时返回 -EINVAL

### 13.5 CAN 总线错误恢复

- 检测 Error-Passive / Bus-Off 状态
- 自动重启 CAN 控制器
- 诊断日志中输出 TX/RX 错误计数

---

## 14. 测试清单

### Phase 0 已验证通过项

- [x] ESP32-S3 上电, 串口日志正常输出
- [x] Wi-Fi 热点 `CAN_Dongle_01` 出现, 手机/Mac 可连接
- [x] `ping 192.168.4.1` 通
- [x] DHCP 服务器工作 (但建议客户端也设静态 IP)
- [x] UDP :5000 监听正常
- [x] CAN 1 Mbps 初始化成功, 状态 Error-Active
- [x] 看门狗 500ms 就绪
- [x] 固件编译成功 (ROM 4.6%, DRAM 61.9%, IRAM 14.5%)

### 待测项目 (Phase 1)

- [ ] RGB30 连接 `CAN_Dongle_01`
- [ ] Godot UI 右上角 `UDP` 变绿
- [ ] Godot UI 右上角 `LINK` 变绿 (收到 motor_status)
- [ ] Monitor 页面能看到电流、电压、速度等实时数据
- [ ] CAN 页面能看到真实 CAN 帧
- [ ] enable/disable 电机正常
- [ ] jog_start/jog_stop 控制正常
- [ ] 切换节点 1 / 节点 2, 控制正确节点
- [ ] sdo_read/sdo_write 读写对象字典成功
- [ ] 断开 RGB30 通信, 500ms 后看门狗进入安全状态, 电机停止
- [ ] estop 急停功能正常
- [ ] CAN 总线断开后, 诊断日志显示 Error-Passive → Bus-Off
- [ ] CAN 总线恢复后, 控制器自动恢复到 Error-Active

---

## 15. 常见问题排查

### 编译问题

| 症状 | 可能原因 | 解决方法 |
|------|----------|----------|
| `west: command not found` | 未激活 Python 虚拟环境 | `source /Users/guoweifeng/zephyrproject/.venv/bin/activate` |
| `Board esp32s3_devkitm not found` | Zephyr 版本不匹配或未 `west update` | 确认 Zephyr 3.6.0, 重新 `west update` |
| Wi-Fi 驱动编译错误 | 缺少 ESP32 RF 库 | `west blobs fetch hal_espressif` |
| CMake 找不到 Zephyr | ZEPHYR_BASE 未设置 | 在 Zephyr 工作区目录内执行, 或设置环境变量 |
| `json_parse` 重定义冲突 | ESP supplicant 库冲突 | 代码中已使用 `cmd_json_parse` 避免 (注意不要改名) |

### 烧录问题

| 症状 | 可能原因 | 解决方法 |
|------|----------|----------|
| 找不到 `/dev/tty.usbmodem*` | USB 线只能充电无数据线芯 | 换一条 USB 数据线 |
| 找不到 `/dev/cu.*` | 缺少 USB 驱动 | 安装相应驱动 (CP2102/CH340) |
| 烧录时一直等待同步 | ESP32 未进入下载模式 | 手动: 按住 BOOT → 按 RESET → 松开 BOOT → 执行烧录 |
| `west flash` 串口权限不足 | macOS 串口权限 | 检查 `/dev/cu.*` 是否存在, 尝试 `sudo` |

### 运行时问题

| 症状 | 可能原因 | 解决方法 |
|------|----------|----------|
| 串口无日志输出 | 控制台配置错误 | 确认 overlay 中 `zephyr,console = &usb_serial` 且 `&uart0 { disabled }` |
| Wi-Fi AP 不可见 | Wi-Fi 初始化失败 | 检查日志, 确认 `CONFIG_WIFI=y`, `west blobs fetch` 已执行 |
| 客户端连不上 AP | DHCP 未启动或不稳定 | 客户端手动设置静态 IP: `192.168.4.x`, 子网 `255.255.255.0`, 网关 `192.168.4.1` |
| CAN 一直 Bus-Off | CAN 总线布线问题 | 检查 CANH/CANL 接线, 确认终端电阻 120Ω, 检查收发器供电 |
| CAN TX 错误计数增长 | 总线只有一台设备 | CAN 需要至少 2 个节点才能正常仲裁, 单节点 ACK 会失败 → TX 错误计数上升至 Error-Passive |
| 电机不响应使能 | 节点 ID 不对或 SDO 超时 | 检查电机节点 ID, 确认 CAN 接线正确, 检查日志中的 SDO abort code |
| 看门狗频繁触发 | RGB30 心跳间隔太大或不稳定 | 心跳间隔应 150ms, 确保 Wi-Fi 信号稳定 |

---

## 16. 附录：快速参考卡

### A. 路径速查

```
项目源码:    /Users/guoweifeng/GameBoy/dongle_firmware/can_dongle/
Zephyr 工作区: /Users/guoweifeng/esp32-can-dongle/
构建输出:    /Users/guoweifeng/esp32-can-dongle/build-can-dongle/
固件二进制:  build-can-dongle/zephyr/zephyr.bin
USB 设备:    /dev/tty.usbmodem114401 (可能变化, 用 ls /dev/cu.* 确认)
Python venv: /Users/guoweifeng/zephyrproject/.venv/bin/activate
```

### B. 常用命令速查

```bash
# === 激活环境 ===
source /Users/guoweifeng/zephyrproject/.venv/bin/activate

# === 编译 ===
cd /Users/guoweifeng/esp32-can-dongle
west build -b esp32s3_devkitm /Users/guoweifeng/GameBoy/dongle_firmware/can_dongle -d build-can-dongle

# === 烧录 ===
west flash -d build-can-dongle --runner esp32 --esp-device=/dev/tty.usbmodem114401

# === 查看日志 ===
# 用 Python pyserial (最可靠):
python3 -c "import serial,time;ser=serial.Serial('/dev/tty.usbmodem114401',115200,timeout=1);ser.setDTR(False);ser.setRTS(True);time.sleep(0.1);ser.setRTS(False);time.sleep(1.5);ser.reset_input_buffer();exec('while True:\n l=ser.readline()\n if l:print(l.decode(errors=\"replace\"),end=\"\",flush=True)')"

# === 网络测试 ===
ping 192.168.4.1
echo '{"cmd":"heartbeat","seq":1,"ts":0}' | nc -u -w1 192.168.4.1 5000
```

### C. 关键参数速查

| 参数 | 值 |
|------|-----|
| Dongle SSID | `CAN_Dongle_01` |
| Dongle IP (AP) | `192.168.4.1` |
| Dongle IP (STA) | `192.168.31.126` |
| Dongle UDP Port | `5000` |
| RGB30 UDP Port | `5001` |
| CAN Baudrate | `1,000,000` |
| CAN TX Pin | `GPIO15` |
| CAN RX Pin | `GPIO16` |
| Heartbeat Interval | `150 ms` |
| Watchdog Timeout | `500 ms` |
| Motor Status Interval | `100 ms` |
| Default Motor Node | `2` |
| Serial Baudrate | `115200` |
| Zephyr Version | `3.6.0` |
| Board Target | `esp32s3_devkitm` |

### D. 存储目录结构

项目中与 ESP32 相关的所有文件:

```
/Users/guoweifeng/GameBoy/
├── dongle_firmware/              ← ESP32 固件 (本文件范围)
│   ├── README.md
│   ├── 零基础操作教程.md
│   └── can_dongle/
│       ├── CMakeLists.txt
│       ├── prj.conf
│       ├── boards/
│       │   ├── esp32s3_devkitm.overlay
│       │   └── esp32s3_devkitc.overlay
│       └── src/
│           ├── main.c
│           ├── udp_comm.c / .h
│           ├── can_raw.c / .h
│           ├── canopen_basic.c / .h
│           ├── json_protocol.c / .h
│           ├── watchdog.c / .h
│           ├── wifi_config.h
│           ├── wifi_secrets.h
│           └── wifi_secrets.example.h
├── godot_terminal/               ← Godot UI (ESP32 的对端)
│   ├── scripts/settings.gd       ← DONGLE_IP 配置
│   ├── scripts/protocol.gd       ← UDP 协议构建器
│   └── API接口文档.md            ← 完整 API 文档
├── mock_server/                  ← Mock Dongle (开发调试用)
│   └── mock_dongle.py
├── memory/                       ← 项目记忆文件
│   └── project_dongle_phase0.md
└── Zephyr_ESP32_Mac学习指南.md    ← Zephyr 学习指南
```

---

> **文档维护:** 本文件随固件开发持续更新。如有硬件变更（如更换开发板、修改引脚），请同步更新第 2-3 节和对应的 overlay 文件。如有协议变更，请同步更新第 9-10 节和 `API接口文档.md`。
>
> **参考文件:**
> - [dongle_firmware/README.md](computer:///Users/guoweifeng/GameBoy/dongle_firmware/README.md) — 固件开发总体说明
> - [godot_terminal/API接口文档.md](computer:///Users/guoweifeng/GameBoy/godot_terminal/API接口文档.md) — 完整 UDP API 规范
> - [Zephyr_ESP32_Mac学习指南.md](computer:///Users/guoweifeng/GameBoy/Zephyr_ESP32_Mac学习指南.md) — Zephyr 环境搭建详解
