# ESP32 CAN Dongle 固件开发说明

这个文件夹用于保存真实 ESP32 CAN Dongle 的固件源码。

你的整个系统可以理解成三层：

```text
RGB30 掌机 Godot UI
        |
        | Wi-Fi + UDP JSON
        v
ESP32-S3 CAN Dongle
        |
        | CAN / CANopen
        v
电机驱动器
```

## 这个 Dongle 要做什么

RGB30 现在已经有 Godot UI。之前我们用 `mock_server/mock_dongle.py` 在 Mac 上模拟电机数据，所以 UI 里能看到电流、电压、转速、CAN 日志等内容。

真实 dongle 的目标就是把这个 mock server 替换成真实硬件：

- RGB30 向 dongle 发送 UDP JSON 命令。
- dongle 接收命令。
- dongle 把命令转换成 CAN/CANopen 报文。
- dongle 从 CAN 总线接收真实电机数据。
- dongle 把电机状态和 CAN 日志发回 RGB30。

## 当前建议开发顺序

不要一开始就做完整 CANopen 和电机固件烧录。第一版先做最小可运行版本。

### Phase 0：UDP + CAN 原始网关

这一阶段的目标是先验证“RGB30 能和真实 dongle 通信，dongle 能看到 CAN 总线”。

需要实现：

- ESP32-S3 启动 Wi-Fi 热点 `CAN_Dongle_01`。
- dongle IP 使用 `192.168.4.1`。
- dongle 监听 UDP `5000` 端口。
- RGB30 监听 UDP `5001` 端口。
- 收到 RGB30 的 `heartbeat` 后回复 `ack`。
- 收到 RGB30 的控制命令后回复 `ack`。
- 初始化 CAN，波特率 `1000000`。
- 接收 CAN 总线所有原始帧。
- 把 CAN 原始帧转成 Godot CAN 日志界面能显示的文本。
- 周期性发送 `motor_status`，让 Monitor 页面有数据。

### Phase 1：CANopen 电机控制

这一阶段开始真正控制电机。

需要实现：

- `enable` 转成 CiA 402 使能流程。
- `disable` 转成失能流程。
- `jog_start` 转成点动运行。
- `jog_stop` 转成停止点动。
- `sdo_read` 读取对象字典。
- `sdo_write` 写入对象字典。
- 从 CANopen 报文解析真实电流、电压、速度、位置、力矩、状态字、故障码。
- 500 ms 没收到 RGB30 心跳时，dongle 自动安全停止电机。

### Phase 2：电机固件升级

这一阶段实现后期你想要的“通过 RGB30 给电机烧固件”。

需要实现：

- RGB30 通过 `ota_start` 和 `ota_chunk` 把固件发给 dongle。
- dongle 校验 MD5。
- RGB30 发送 `ota_flash`。
- dongle 根据电机厂商的 bootloader 协议，把固件刷到指定节点的电机。

## 现有协议来源

真实 dongle 必须兼容现在 Godot UI 已经在使用的协议。

最重要的文件是：

```text
/Users/guoweifeng/GameBoy/godot_terminal/scripts/protocol.gd
/Users/guoweifeng/GameBoy/godot_terminal/API接口文档.md
/Users/guoweifeng/GameBoy/mock_server/mock_dongle.py
```

其中 `mock_server/mock_dongle.py` 最重要，因为它就是“假 dongle”。真实 dongle 第一版要尽量模仿它的输入输出。

## 通信参数

真实 dongle 默认参数：

```text
Dongle IP:       192.168.4.1
Dongle UDP:      5000
RGB30 UDP:       5001
心跳间隔:         150 ms
心跳超时保护:      500 ms
CAN 波特率:       1000000
数据格式:         UTF-8 JSON
```

当前 Godot 开发阶段为了连接 Mac mock server，可能还是：

```gdscript
const DONGLE_IP = "192.168.31.128"
```

等真实 dongle 开始测试时，需要改回：

```gdscript
const DONGLE_IP = "192.168.4.1"
```

位置：

```text
/Users/guoweifeng/GameBoy/godot_terminal/scripts/settings.gd
```

## 当前硬件假设

项目记忆里记录的计划硬件是：

```text
Waveshare ESP32-S3-RS485-CAN
CAN RX: GPIO19
CAN TX: GPIO20
CAN 收发器: TJA1050
CAN 终端电阻: 只有在总线末端才打开 120 欧姆
供电: 7-36V DC 或 USB-C 5V
```

如果以后换开发板，不应该改 Godot UI 协议，只需要改 dongle 的 Zephyr 板级配置和 CAN 引脚。

## Mac 上已有环境

你的 Mac 上已经有 Zephyr 环境：

```text
/Users/guoweifeng/esp32-can-dongle
/Users/guoweifeng/zephyrproject/.venv/bin/west
```

但是目前 `/Users/guoweifeng/esp32-can-dongle` 主要是 Zephyr 工作区，不是你的项目源码目录。

dongle 源码应该保存在你的项目里：

```text
/Users/guoweifeng/GameBoy/dongle_firmware/can_dongle
```

## 建议源码结构

```text
dongle_firmware/
├── README.md
├── 零基础操作教程.md
└── can_dongle/
    ├── CMakeLists.txt
    ├── prj.conf
    ├── boards/
    │   └── esp32s3_devkitm.overlay
    └── src/
        ├── main.c
        ├── udp_comm.c
        ├── udp_comm.h
        ├── can_raw.c
        ├── can_raw.h
        ├── json_protocol.c
        ├── json_protocol.h
        ├── watchdog.c
        ├── watchdog.h
        ├── canopen_bridge.c
        ├── canopen_bridge.h
        ├── ota_manager.c
        └── ota_manager.h
```

## 编译命令

以后源码写好后，在 Mac 终端执行：

```sh
cd /Users/guoweifeng/esp32-can-dongle
source /Users/guoweifeng/zephyrproject/.venv/bin/activate
west build -b esp32s3_devkitm /Users/guoweifeng/GameBoy/dongle_firmware/can_dongle -d build-can-dongle
```

## 烧录命令

ESP32-S3 通过 USB 接到 Mac 后，在终端执行：

```sh
cd /Users/guoweifeng/esp32-can-dongle
source /Users/guoweifeng/zephyrproject/.venv/bin/activate
west flash -d build-can-dongle
```

## 首次测试清单

第一版 dongle 做好后，要按这个顺序测试：

1. ESP32-S3 上电。
2. Mac 或 RGB30 能看到 Wi-Fi：`CAN_Dongle_01`。
3. RGB30 连接这个 Wi-Fi。
4. RGB30 能 ping 通 `192.168.4.1`。
5. Godot UI 右上角 `UDP` 变绿。
6. Godot UI 右上角 `LINK` 变绿。
7. Monitor 页面能看到电流、电压、速度等数据。
8. CAN 页面能看到真实 CAN 帧。
9. 选择节点 1，只控制节点 1。
10. 选择节点 2，只控制节点 2。
11. 拔掉或关闭 RGB30 通信，500 ms 后 dongle 自动安全停止电机。

## 安全规则

这些规则后期必须一直保留：

- `estop` 必须最高优先级。
- 心跳超时必须自动停止电机。
- OTA 时不能同时乱发电机控制命令。
- 节点 ID 只能是 `1..127`。
- 超出范围的节点 ID 必须拦截。
- 未知命令必须返回错误，不能静默忽略。

