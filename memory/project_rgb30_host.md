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

## 按键映射（2026-06-19 重启后重新验证）

`/dev/input/js0` 的按钮编号会在 ROCKNIX 重启后变化，不再作为可信映射来源。
Godot raw reader 优先读取稳定的
`/dev/input/by-path/platform-rocknix-singleadc-joypad-event-joystick`。

| 按键 | Linux event code | 功能 |
|------|------------------|------|
| B | BTN_SOUTH (304) | back |
| A | BTN_EAST (305) | confirm |
| X | BTN_NORTH (307) | enable |
| Y | BTN_WEST (308) | disable |
| L1 | BTN_TL (310) | jog_ccw |
| R1 | BTN_TR (311) | jog_cw |
| L2 | BTN_TL2 (312) | estop |
| R2 | BTN_TR2 (313) | r2 |
| Select | BTN_SELECT (314) | language_select |
| Start | BTN_START (315) | menu |
| Up/Down/Left/Right | BTN_DPAD_* (544-547) | navigation |

## 协议设计方向（2026-06-17 确认）

- **统一命令表单方案**，所有命令共用同一个 payload schema，不采用独立 payload
- 优势：加命令只需填一行表（多电机、脚本执行器），解析端不改代码；协作方只需一份文档
- 劣势：消息体积略大（本项目影响可忽略）；字段语义需查文档
- 设计文档: `/Users/guoweifeng/GameBoy/统一命令表单设计.md`
- Godot 侧负责 UI，ESP32 协议由协作者重做，两边用表单文档对齐

## 未来规划

### 小车多电机控制
- 语言选择后增加模式选择界面 → 单电机模式 / 小车模式
- 小车模式：选左轮 node + 右轮 node → 车控专用 UI
- 加 `car_move` 命令（left_speed + right_speed），ESP32 同周期内串发两条 SDO
- 硬件：两个电机挂同一 CAN 总线，不同 node ID

## 优化进度（2026-06-19）

已完成：

- `can_log_state.gd` 缓冲上限已扩展为 1000 行。
- monitor/CAN/OTA/config 的页面级布局矩形已集中到 `ui_config.gd`，共享
  `CONTENT_LEFT`、`LEFT_RAIL_WIDTH`、`MAIN_CONTENT_X` 等语义常量。
- monitor/CAN/OTA 共用 `app_chrome.gd` 的 action rail 绘制。
- motor_status 增加 `drive_status_word`、`drive_fault`、`estop_latched`、
  `display_status`、`valid_mask` 和 `fresh_mask`。
- 固件对六个遥测字段独立轮询和退避，单字段超时不会暂停其它字段；
  新鲜度窗口为 5 秒。
- RGB30 对从未有效的字段显示 `--`；已有有效值但短暂 stale 时保留最后值并
  灰显。软件急停与驱动器真实 Fault 分开显示。
- RGB30 按键通过 `rgb30-input-bridge.service` 读取稳定 Linux event code，
  经本机 UDP 5010 交给 Godot；已验证重启后服务自动恢复。

仍需硬件验证：

- node 2 不受 heartbeat/estop 包内默认 node 1 影响。
- 急停后 2 秒内重新使能。
- 正反转速度与扭矩符号。
- RGB30 心跳断联后的主动安全失能。
- 电机断电后的 SDO 退避与遥测恢复。

Mac 端约 100 MB CAN 日志持久化仍是协议级后续。当前 ESP32 只保存最后一个
UDP 客户端地址；Mac 主动发送订阅/心跳会抢走 RGB30 回包。实现前必须先增加
独立日志目标、广播或多订阅机制，不能直接增加一个竞争客户端。

### 遥测回退状态

- ESP32 模块化遥测/SDO 优化未通过实体六字段验收，当前设备已恢复并烧录 Git
  优化前固件基线。
- 回退基线已验证六字段均出现在连续 23 个状态包中，六个 SDO 对象均观察到响应。
- 未通过版本仅保存在
  `memory/backups/can-dongle-decoupled-unverified-2026-06-19.patch`，
  不得当作稳定检查点。

### UI 正式位置与发布

- 解耦 UI 的唯一正式目录是 `/Users/guoweifeng/GameBoy/godot_terminal`，
  不再使用独立 worktree 保存正式 UI。
- Select=`BTN_SELECT(314)` 返回语言界面；L2=`BTN_TL2(312)` 执行 E-STOP。
- Azure MotorBoy-UI `stage` 当前稳定检查点为 `4bdb7cb`，包含命令关联、
  Godot/按键服务开机自启、RGB30 模态确认框修复和 UI 文档纠错。
- 后续只继续开发 RGB30 UI；当前 ESP32 固件保持不变并由后续人员另行重做。
- UI 与未来 ESP32 的事实遥测、ACK 关联和可靠 OTA 契约见
  `godot_terminal/docs/ESP32_UI_CONTRACT.md`。

### UI 命令关联与生产自启（2026-06-22）

- UI 已增加基于 `seq` 的请求跟踪、重复/迟到响应过滤和命令超时报告；
  heartbeat 与 OTA chunk 的超时保持静默，避免周期命令刷屏。
- SDO 普通 ACK 不会提前结束请求，必须等到 `sdo_read_result`；无 `seq` 的旧固件
  响应继续兼容，并保留节点过滤。
- 带 `seq` 的 ACK 以请求关联为可信依据，避免旧固件 ACK 中默认 `node=1`
  错误覆盖当前 node 2 操作。
- 网络发送和系统关机副作用已从 `main.gd` 移入 `app_event_executor.gd`。
- RGB30 生产启动改为 `rgb30-godot.timer` 在开机 20 秒后触发静态
  `rgb30-godot.service`；启动脚本等待 Sway/Wayland 可用后再进入 Godot。
- 已完成真实重启验证：Godot、输入桥和 timer 均 active，启动时
  `NRestarts=0`。最终部署后 UI PID 为 3363。
- 8 项 Godot 自动测试和 Linux ARM64 导出通过；导出文件 SHA-256：
  `379b0f39f31c0cbd2c2288fe7900f422e6d440ebf5227a8e58cdec1b7d12d514`。
- 本检查点未修改、构建或发布 ESP32 固件。

### RGB30 弹出界面实现规则（2026-06-22）

- 临时确认、警告和操作提示优先使用独立 `CanvasLayer` 模态层，不直接跳转到
  新页面，避免丢失底层页面状态、选择位置和上下文。
- 模态层级必须高于主界面，并使用实体 `Panel` 和 `Label` 节点；不要依赖与
  主界面相同 `_draw()` 批次中的覆盖顺序。
- RGB30 的 Mali/Wayland `gl_compatibility` 路径对全屏半透明 CanvasItem
  遮罩表现不可靠，禁止把半透明背景作为关键可读性条件。
- 需要保留原界面时，确认框弹出期间可关闭底层背景网格，仅保留纯色底、原页面
  内容和不透明确认面板；关闭确认框后恢复网格。
- 多段关键提示在 RGB30 上优先合并到一个多行 `Label`，避免同层多个文本节点
  在实体渲染路径中出现部分缺失。
- 当前实现位于
  `godot_terminal/scripts/screens/confirmation_overlay.gd`，提交为
  本地 `ad4b81e`、Azure `cde8796`。已通过 9 项自动测试、ARM64 导出和
  RGB30 实机验证。

### 手机端
- Godot 导出 Android APK / iOS IPA，UDP 通信层零改动
- iOS 需 Apple Developer 账号 ($99/年)，Ad-hoc 分发可装 100 台
- 主要工作量：720×720 → 手机长宽比 UI 适配 + 触屏替代实体按键

### Docker 编译环境
- 基础镜像: ubuntu 22.04 + Zephyr SDK 1.0.1 + Zephyr 4.4.99
- 编译: `-DZEPHYR_TOOLCHAIN_VARIANT=zephyr` + `esp32s3_devkitc.overlay`

## Git 仓库

| Remote | URL | 分支 | 内容 |
|--------|-----|------|------|
| origin (GitHub) | https://github.com/bobilovenn-cmd/Game-boy.git | main | 全项目 |
| MotorBoy-UI (Azure) | https://dev.azure.com/hcrobots/Bootcamp/_git/MotorBoy-UI | stage | 仅 `godot_terminal/` |
| MotorBoy-Zephyr (Azure) | https://dev.azure.com/hcrobots/Bootcamp/_git/MotorBoy-Zephyr | stage | 仅 `dongle_firmware/` |

远端映射:
- UI remote：`azure`，只接收纯 `godot_terminal/` 发布分支。
- 固件 remote：`zephyr`，只接收纯 `dongle_firmware/` 发布分支。
- 实际推送前必须从对应 Azure `stage` 建立隔离 worktree，检查顶层目录后推送；
  不再使用旧的 `azure-ui` / `azure-zephyr` remote 名称。

### 发布策略（2026-06-18）

- 日常开发和未完成优化保存在本地功能分支。
- GitHub 功能分支用于较频繁的远程备份和开发历史。
- Azure 是工作仓库，只推送已经完成编译、自动测试和硬件回归的稳定检查点。
- 未经用户明确同意，不推送 Azure `stage`。
- `godot_terminal/` 对应 Azure UI 仓库；`dongle_firmware/` 对应 Azure Zephyr 仓库，禁止交叉推送。

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
| Godot systemd 服务 | /storage/.config/system.d/rgb30-godot.service |
| Godot延迟启动 timer | /storage/.config/system.d/rgb30-godot.timer |
| 输入桥服务 | /storage/.config/system.d/rgb30-input-bridge.service |
| 旧 Python 服务 | /storage/.config/system.d/diag-terminal.service（已禁用，仅供回退） |
| Godot 启动脚本 | /storage/handheld_terminal_godot/rgb30_start_godot.sh |
| Godot 部署脚本 | /Users/guoweifeng/GameBoy/godot_terminal/deploy/rgb30_start_godot.sh |
