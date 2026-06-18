# Zephyr + ESP32 学习指南（macOS 开发）

> 基于你的手持诊断工具项目整理，帮助你从零理解 Zephyr、ESP32 组件、以及在 Mac 上如何烧录和调试。

---

## 一、ESP32-S3 的硬件组成

你项目选用的是 **ESP32-S3**（微雪开发板），先搞清楚它里面有什么：

```
┌─────────────────────────────────────────────────┐
│                  ESP32-S3 SoC                    │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Xtensa   │  │ 512KB   │  │  Wi-Fi        │  │
│  │ LX7 双核 │  │ SRAM    │  │  802.11 b/g/n │  │
│  │ CPU      │  │         │  │  2.4GHz       │  │
│  │ 240MHz   │  │         │  └───────────────┘  │
│  └──────────┘  └──────────┘                     │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ TWAI     │  │ USB-OTG │  │ SPI / I2C /   │  │
│  │ (CAN     │  │ 原生USB │  │ UART 外设     │  │
│  │ 控制器)  │  │         │  │               │  │
│  └──────────┘  └──────────┘  └───────────────┘  │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ ADC      │  │ PWM/LEDC│  │ GPIO (45个)   │  │
│  │ 模数转换 │  │ 脉宽调制│  │               │  │
│  └──────────┘  └──────────┘  └───────────────┘  │
└─────────────────────────────────────────────────┘
         │ 外接
         ▼
┌─────────────────────────────────────────────────┐
│               微雪开发板板载                      │
│                                                  │
│  ┌──────────────┐  ┌─────────────────────────┐  │
│  │ SPI Flash    │  │ CAN 收发器              │  │
│  │ (16MB)       │  │ (如 SN65HVD230/ISO1042)│  │
│  │ 存固件+OTA   │  │ TWAI TX→CAN_H          │  │
│  │              │  │ TWAI RX→CAN_L          │  │
│  └──────────────┘  └─────────────────────────┘  │
│                                                  │
│  ┌──────────────┐  ┌─────────────────────────┐  │
│  │ USB-UART     │  │ 天线（PCB/陶瓷）        │  │
│  │ 桥接芯片     │  │                         │  │
│  │ (CP2102/     │  │                         │  │
│  │  CH340)      │  │                         │  │
│  └──────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### 关键组件解释

**CPU 核心**：Xtensa LX7 双核 240MHz，一个核跑协议栈（Wi-Fi + BLE），另一个核跑你的应用代码。Zephyr 默认只用一个核（PRO CPU），另一个留给 Wi-Fi 驱动。

**TWAI（Two-Wire Automotive Interface）**：这是 ESP32 内置的 CAN 2.0B 控制器，不是外挂芯片。它处理 CAN 协议的帧格式和仲裁，但需要外接一个 CAN **收发器**（物理层芯片）才能挂到总线上。你项目里的 Zephyr CAN 驱动就是操作这个 TWAI 硬件。

**USB-OTG**：ESP32-S3 有原生 USB 外设，可以做 USB Device 或 Host，烧录时也可以走 USB DFU 模式（比传统串口更快）。

**SPI Flash**：外部挂载的 Flash 芯片，用于存放固件（你的代码）、文件系统（OTA 缓存）、NVS（非易失存储）。开发板上通常是 4MB 或 16MB。

---

## 二、Zephyr RTOS 核心概念

### 2.1 Zephyr 是什么

Zephyr 不是一个传统操作系统，它是一个**可配置的实时操作系统内核 + 驱动框架 + 中间件集合**。你可以把它理解为：

```
你的应用代码 (main.c, wifi_ap.c, canopen_stack.c ...)
        │
        ▼
┌─────────────────────────────────┐
│         Zephyr 内核              │
│  线程调度 | 信号量 | 定时器       │
│  内存管理 | 工作队列             │
├─────────────────────────────────┤
│         Zephyr 驱动模型          │
│  CAN | UART | SPI | GPIO | Wi-Fi│
├─────────────────────────────────┤
│         Zephyr 网络子系统        │
│  L2(Wi-Fi/Ethernet) | IPv4/IPv6 │
│  UDP/TCP | Socket API           │
├─────────────────────────────────┤
│         Zephyr 文件系统/存储      │
│  Flash Map | NVS | FAT           │
├─────────────────────────────────┤
│         板级支持包 (BSP)          │
│  esp32s3_devkitm 设备树 + 配置   │
└─────────────────────────────────┘
        │
        ▼
   ESP32-S3 硬件
```

### 2.2 三个核心文件

你项目里最关键的三个配置文件，理解它们就理解了 Zephyr 的构建方式：

**1) prj.conf — Kconfig 配置**

这是 Zephyr 的"菜单系统"，通过 `CONFIG_XXX=y` 或 `CONFIG_XXX=数值` 来启用/禁用功能模块。例如：

```ini
CONFIG_CAN=y          # 启用 CAN 子系统 → 编译进 CAN 驱动代码
CONFIG_WIFI=y         # 启用 Wi-Fi → 编译进 Wi-Fi 驱动和协议栈
CONFIG_CJSON_LIB=y    # 启用 cJSON 库 → 可以在代码中 #include <cJSON.h>
CONFIG_LOG=y          # 启用日志系统 → 可以用 LOG_INF() 等宏
```

**Zephyr 的哲学是：不用的功能不编译**，所以 prj.conf 直接决定了最终固件的大小和功能边界。

**2) CMakeLists.txt — 构建脚本**

```cmake
cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})  # 找到 Zephyr
project(can_dongle VERSION 1.0.0)

target_sources(app PRIVATE      # 把你的源码加入编译
    src/main.c
    src/wifi_ap.c
    ...
)
```

`find_package(Zephyr)` 这行会把 Zephyr 的整个构建系统拉进来，之后 `west build` 就知道怎么编译了。

**3) 设备树覆盖 (overlay) — 硬件引脚配置**

```dts
&twai {
    status = "okay";    // 启用 TWAI 外设
};

&pinctrl {
    twai_default: twai_default {
        group1 { pins = <4>; };  // CAN TX = GPIO4
        group2 { pins = <5>; };  // CAN RX = GPIO5
    };
};
```

设备树描述硬件布局。`overlay` 文件允许你在不修改 Zephyr 源码的情况下覆盖默认引脚配置。**换硬件只需改 overlay，不改代码。**

### 2.3 Zephyr 的线程模型

你的项目用到了多个线程，理解优先级很关键：

```
优先级数值越小 = 优先级越高

优先级 1  ──► watchdog 线程（看门狗，必须最高，保证急停实时性）
优先级 5  ──► udp_recv 线程（UDP 接收，确保心跳及时处理）
优先级 10 ──► status_report 线程（状态上报，非紧急）
优先级 10 ──► ota_flash 线程（OTA 刷写，非紧急）
默认优先级 ──► main 线程（CANopen 周期任务）
```

Zephyr 使用**抢占式调度**，高优先级线程可以随时打断低优先级线程。这就是为什么看门狗线程能保证 500ms 内急停——它的优先级仅次于系统保留级别。

### 2.4 Zephyr 的构建流程

```
    west init + west update
         │
         ▼
    你写的源码 + prj.conf + overlay
         │
         ▼  west build -b esp32s3_devkitm
    ┌────────────────────────┐
    │   CMake 配置阶段        │  读取 prj.conf，决定编译哪些模块
    │   → 生成 build 目录     │  读取设备树，生成硬件头文件
    ├────────────────────────┤
    │   Ninja 编译阶段        │  交叉编译（主机是 Mac，目标是 ESP32-S3）
    │   → 生成 .elf / .bin   │  工具链是 west espressif install 装的
    └────────────────────────┘
         │
         ▼  west flash
    ESP32-S3 芯片（通过 USB 串口烧写）
```

---

## 三、Mac 上的开发环境搭建（实操步骤）

### 3.1 安装系统依赖

```bash
# 确保 Homebrew 已安装
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装编译工具链
brew install cmake ninja gperf python3 ccache dtc wget

# 安装 west（Zephyr 的官方构建管理工具，类似 npm/cargo 的角色）
pip3 install west
```

如果 `pip3 install west` 报错 `externally-managed-environment`（macOS 新版 Python 的限制），用虚拟环境：

```bash
python3 -m venv ~/zephyr-env
source ~/zephyr-env/bin/activate
pip install west
# 后续所有 pip install 都在这个虚拟环境里执行
```

### 3.2 获取 Zephyr 源码 + ESP32 工具链

```bash
# 创建工作目录
mkdir -p ~/esp32-can-dongle && cd ~/esp32-can-dongle

# 初始化 west 工程
# -m 指定 manifest 仓库，--mr 指定版本
# 这个命令会下载 Zephyr 源码 + 所有依赖模块（几百个仓库）
west init -m https://github.com/zephyrproject-rtos/zephyr --mr v3.6.0
west update

# 安装 Zephyr 的 Python 依赖
pip3 install -r zephyr/scripts/requirements.txt

# 安装 ESP32 专用的交叉编译工具链
# 这会下载 Xtensa GCC、OpenOCD（调试器）、ESP-IDF 组件等
west espressif install
```

设置环境变量（加到 `~/.zshrc`）：

```bash
echo 'export ZEPHYR_TOOLCHAIN_VARIANT=espressif' >> ~/.zshrc
echo 'export ESPRESSIF_TOOLCHAIN_PATH=~/.espressif/tools/zephyr' >> ~/.zshrc
source ~/.zshrc
```

### 3.3 验证环境是否正常

```bash
cd ~/esp32-can-dongle

# 编译 Zephyr 自带的 hello_world 示例
west build -b esp32s3_devkitm zephyr/samples/hello_world

# 如果看到 "PROJECT EXECUTION SUCCESSFUL" 就说明环境OK
```

---

## 四、在 Mac 上编译、烧录、调试 ESP32（完整流程）

### 4.1 连接硬件

把微雪 ESP32-S3 开发板用 USB 线接到 Mac。macOS 会自动识别串口设备：

```bash
# 查看可用的串口设备
ls /dev/cu.*
# 常见输出:
# /dev/cu.usbserial-0001
# /dev/cu.SLAB_USBtoUART
# /dev/cu.usbmodem1101    (如果是原生 USB)
```

> **注意：** 用 `/dev/cu.*` 而不是 `/dev/tty.*`。`cu`（callout）设备在 macOS 上更稳定，`tty` 设备可能会被系统守护进程干扰。

### 4.2 编译固件

```bash
cd ~/esp32-can-dongle/can_dongle  # 你的应用目录

# 编译（--pristine 表示清理后重新编译，避免缓存问题）
west build -b esp32s3_devkitm . --pristine
```

编译过程会：
1. 读取 `prj.conf`，决定启用哪些 Zephyr 子系统
2. 读取设备树（包括 overlay），生成硬件配置头文件
3. 用 Xtensa GCC 交叉编译所有代码
4. 输出 `build/zephyr/zephyr.bin`（烧录用的二进制文件）

如果只想修改代码后增量编译（不清理）：

```bash
west build   # 直接执行，不加 --pristine
```

### 4.3 烧录固件

```bash
west flash
```

`west flash` 内部做的事情：

```
west flash
    │
    ├─ 自动检测 USB 串口（/dev/cu.usbserial-*）
    │
    ├─ 让 ESP32 进入下载模式（拉低 GPIO0 + 复位）
    │  （Zephyr 的 esptool 会自动处理这个流程）
    │
    ├─ 使用 esptool.py 写入固件到 Flash
    │  → build/zephyr/zephyr.bin 写到 Flash 的 app 分区
    │
    └─ 复位 ESP32，开始运行新固件
```

**如果自动检测串口失败**，可以手动指定：

```bash
# 查看当前配置的串口
west flash --sn <serial-number>

# 或者直接指定设备路径
ESPPORT=/dev/cu.usbserial-0001 west flash
```

### 4.4 查看串口日志（调试核心手段）

烧录完成后，最重要的调试方式就是看串口日志：

```bash
# 方法一：使用 Zephyr 自带的 monitor（推荐，支持自动复位+日志过滤）
west espressif monitor

# 方法二：使用 macOS 自带的 screen
screen /dev/cu.usbserial-0001 115200
# 退出 screen: 按 Ctrl+A，然后按 K，再按 Y 确认

# 方法三：使用 minicom（需要 brew install minicom）
minicom -D /dev/cu.usbserial-0001 -b 115200
```

预期看到的日志输出（以你的项目为例）：

```
========================================
CAN Dongle 固件启动
========================================
[00:00:00.123] <inf> wifi_ap: Wi-Fi AP 正在启动...
[00:00:01.456] <inf> wifi_ap: Wi-Fi AP 启动成功，SSID: CAN_Dongle_01
[00:00:01.789] <inf> udp_comm: UDP 通信初始化完成
[00:00:02.012] <inf> canopen: CANopen 栈初始化完成，节点 ID=0
[00:00:02.234] <inf> watchdog: 心跳看门狗已初始化
[00:00:02.456] <inf> ota: OTA 管理器初始化完成
[00:00:02.678] <inf> main: 所有模块初始化完成，系统就绪
```

### 4.5 日志级别控制

在 `prj.conf` 中调整：

```ini
CONFIG_LOG_DEFAULT_LEVEL=3  # 0=off, 1=err, 2=warn, 3=info, 4=debug
```

在代码中每个模块独立控制：

```c
LOG_MODULE_REGISTER(wifi_ap, CONFIG_LOG_DEFAULT_LEVEL);
// 或者模块级别覆盖：
LOG_MODULE_REGISTER(wifi_ap, 4);  // 这个模块强制 debug 级别
```

### 4.6 一键编译+烧录+监控

```bash
# 编译 + 烧录 + 自动打开串口监控，一条命令搞定
west flash && west espressif monitor

# 或者分步执行时，用 --skip-rebuild 跳过重复编译
west flash --skip-rebuild
```

---

## 五、调试技巧与常见问题

### 5.1 编译错误排查

**问题：找不到头文件或 Kconfig 选项**

```bash
# 查看当前启用了哪些 Kconfig 选项
west build -t menuconfig
# 这会打开一个文本菜单界面，可以搜索配置项
# 修改后保存会自动更新 build/zephyr/.config

# 如果想回到 prj.conf 的设置
west build -t pristine
```

**问题：ESP32 Wi-Fi 相关编译错误**

ESP32 的 Wi-Fi 驱动依赖 ESP-IDF 组件，需要确保：
- `ZEPHYR_TOOLCHAIN_VARIANT=espressif` 已设置
- `ESPRESSIF_TOOLCHAIN_PATH` 指向正确路径
- Zephyr 版本和 ESP-IDF 组件版本兼容

### 5.2 烧录失败排查

**问题：无法检测到串口**

```bash
# 检查 USB 设备是否被系统识别
system_profiler SPUSBDataType | grep -A5 -i "serial\|uart\|cp210\|ch340"

# 如果没看到设备：
# 1. 换一根 USB 数据线（有些线只能充电，没有数据线芯）
# 2. 安装 USB-UART 驱动：
#    CP2102: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
#    CH340:  brew install --cask wch-ch34x-usb-serial-driver
```

**问题：烧录时一直等待同步**

ESP32 需要进入下载模式才能烧录。如果自动进入失败：

```bash
# 手动进入下载模式：
# 1. 按住开发板上的 BOOT/IO0 按钮
# 2. 按一下 RESET/EN 按钮
# 3. 松开 BOOT 按钮
# 4. 立即执行 west flash
```

### 5.3 运行时调试

**问题：固件烧进去但没有日志输出**

```bash
# 1. 确认波特率匹配（默认 115200）
# 2. 确认日志后端已启用
#    prj.conf 中 CONFIG_LOG_BACKEND_UART=y

# 3. 如果怀疑固件根本没启动，尝试：
west debug    # 启动 GDB 调试（需要 OpenOCD）
# 这会：
# - 启动 OpenOCD（通过 USB 连接 ESP32 的 JTAG）
# - 启动 GDB
# - 你可以设置断点、单步执行、查看变量
```

**使用 GDB 调试（高级）**

```bash
# 启动调试会话
west debug

# GDB 常用命令：
(gdb) break main         # 在 main 函数设断点
(gdb) break src/main.c:42  # 在第 42 行设断点
(gdb) continue           # 继续运行
(gdb) next               # 单步（不进入函数）
(gdb) step               # 单步（进入函数）
(gdb) print my_variable  # 打印变量值
(gdb) backtrace          # 查看调用栈（崩溃时非常有用）
(gdb) info threads       # 查看所有 Zephyr 线程
```

> **注意：** ESP32-S3 的 JTAG 调试需要开发板有 USB-JTAG 支持（S3 原生 USB 可以直接用），或者外接 JTAG 调试器。

### 5.4 网络调试

ESP32 启动 Wi-Fi AP 后，在 Mac 上验证连接：

```bash
# 1. Mac 连接到 CAN_Dongle_01 热点（密码：C@nDongle2024）

# 2. 测试连通性
ping 192.168.4.1

# 3. 发送 UDP 测试包
echo '{"cmd":"heartbeat","seq":1,"ts":0}' | nc -u -w1 192.168.4.1 5000

# 4. 抓包分析（en0 通常是 Mac 的 Wi-Fi 接口）
sudo tcpdump -i en0 udp port 5000 -v
```

---

## 六、常用命令速查表

```bash
# ===== West 构建命令 =====
west build -b esp32s3_devkitm .            # 编译
west build -b esp32s3_devkitm . --pristine # 清理后重新编译
west flash                                  # 烧录
west espressif monitor                      # 查看串口日志
west debug                                  # GDB 调试
west build -t menuconfig                    # 图形化配置菜单

# ===== macOS 串口 =====
ls /dev/cu.*                                # 查看串口设备
screen /dev/cu.usbserial-0001 115200       # 连接串口
# 退出 screen: Ctrl+A → K → Y

# ===== 网络调试 =====
ping 192.168.4.1
nc -u 192.168.4.1 5000                     # UDP 发送
sudo tcpdump -i en0 udp port 5000 -v       # 抓 UDP 包

# ===== 环境变量（加入 ~/.zshrc）=====
export ZEPHYR_TOOLCHAIN_VARIANT=espressif
export ESPRESSIF_TOOLCHAIN_PATH=~/.espressif/tools/zephyr
```

---

## 七、学习路径建议

按你项目的开发路线，建议按这个顺序逐步推进：

**第 1 步：环境搭建 + Hello World（1-2天）**
- 按第三节安装所有依赖
- 编译并烧录 `zephyr/samples/hello_world`
- 在串口看到 "Hello World" 输出，环境就算通了

**第 2 步：跑通 Wi-Fi AP 示例（2-3天）**
- 研究 `zephyr/samples/net/wifi` 相关示例
- 在 ESP32 上启动 AP 热点，用手机连上
- 理解 Zephyr 网络子系统的初始化流程

**第 3 步：UDP 通信（2天）**
- 用 Zephyr Socket API 写一个简单的 UDP echo server
- 在 Mac 上用 `nc` 发 UDP 包，ESP32 回复
- 把你的 `udp_comm.c` 模块跑通

**第 4 步：CAN/TWAI 驱动（3-5天）**
- 跑通 `zephyr/samples/drivers/can` 示例
- 用 `prj.conf` 里的 `CONFIG_CAN=y` 启用 TWAI
- 在 overlay 里配好 TX/RX 引脚
- 接上 CAN 分析仪或另一个 CAN 设备，互相收发帧

**第 5 步：集成 CANopenNode（5天）**
- 这是最复杂的部分，把开源 CANopen 栈移植到 Zephyr
- 先实现 SDO 读写，再做 PDO，最后做 NMT

**第 6 步：组装完整固件 + 联调**
- 把所有模块集成在一起
- 跟母机 Python UI 联调
- 逐步测试安全机制（心跳急停等）

---

> **文档版本：** v1.0 | **编写日期：** 2026-06-04
> **适用阶段：** Phase 1 原型期开发学习
