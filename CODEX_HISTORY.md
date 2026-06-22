# Codex 历史恢复文件

更新时间：2026-06-18（Asia/Shanghai）

## 原线程

- 标题：`Game Boy Project`
- Thread ID：`019ea9d9-5a8f-72e1-a92e-7d1bc0911985`
- 状态：`systemError`
- 原线程记录的 cwd：`/Users/guoweifeng/Documents/Game Boy`
- 实际项目目录：`/Users/guoweifeng/GameBoy`
- 恢复接口按“最新到最旧”分页读取；超长工具输出可能被截断，但关键决策、提交、未提交现场和后续任务已整理在本文件。

## 项目目标

项目是运行在 PowKiddy RGB30（ROCKNIX）上的 AGV/AMR 电机诊断终端：

1. Godot 4.6.3 UI 在 RGB30 上运行。
2. RGB30 通过 JSON/UDP 与 ESP32-S3 CAN Dongle 通信。
3. ESP32 通过 CANopen/CiA 402 控制电机。
4. ESP32 后续可能交给协作者开发，因此协议、编码规范和模块边界必须清晰。
5. 未来可能扩展左右轮双节点“小车模式”。

GitHub：`https://github.com/bobilovenn-cmd/Game-boy`

## 已确认的关键硬件与协议事实

- RGB30 已验证原始按键：
  - B=0/back
  - A=1/confirm
  - X=2/enable
  - Y=3/disable
  - L1=4/jog CCW
  - R1=5/jog CW
  - L2=6/estop
  - Select=8/language select
  - Start=9/menu
  - D-pad=13/14/15/16
- A/B 的 `/dev/input/js0` 编号会随 ROCKNIX 重启变化，禁止作为可信来源。
- 2026-06-19 再次确认：`js0` 的 0/1 会随重启变化，不能作为长期来源。
  稳定来源为 Linux event code：A=`BTN_EAST(305)`、B=`BTN_SOUTH(304)`、
  L2=`BTN_TL2(312)`/E-STOP、Select=`BTN_SELECT(314)`/language select；
  `rgb30-input-bridge.service` 读取 event 设备并把规范化按键通过本机 UDP
  5010 交给 Godot；2026-06-19 已真实重启验证服务自动恢复。
- 当前电机节点测试主要使用 node 2，但恢复/NMT 操作必须使用命令中的节点，不能写死 node 2。
- heartbeat 不应修改 ESP32 的 active node，否则会把节点覆盖回默认值。
- 速度设定使用与电机/界面一致的原始速度值，例如 `50000`，不是 `500 rpm` 后再乘 100。
- 当前 UI 速度单位已朝 `pulse/s` 统一；历史文档中仍有 rpm 与 pulse/s 不一致，协议层必须最终统一。
- JSON 协议方向：统一外层 `{cmd, seq, ts, payload}`；线上保持紧凑 payload，兼容现有 ESP32。

## 重要历史修复

- ESP32 重启后 node 2 SDO 超时：
  - 增加 CAN 控制器恢复；
  - 首次写失败后执行 NMT reset communication；
  - 等待后 NMT start 并重试；
  - heartbeat 不再覆盖 active node。
- 反转时电流不显示：原固件过滤了负电流，已改为接受合理范围的有符号电流。
- 位置模式：补充 Profile Position/CiA 402 执行序列。
- UI 字体：CJK 子集必须同时包含 ASCII、数字和符号，否则遥测、快捷键、LAST、单位等会消失。
- 监控波形已从电流波形改为速度波形。

## Godot 解耦进度

工作分支：`codex/refactor-godot-ui`

旧线程已完成并多次通过 Godot Linux ARM64 headless export 的拆分包括：

- UI 主题与配置
- 输入映射、原始输入读取、统一输入路由
- CAN 日志状态与格式化
- UDP client、连接状态、消息分发
- 电机控制器、OTA 状态、状态提示
- 节点选择、数字输入、上传模式等控制器
- Language/Node/Monitor/Config/OTA/CAN/数字输入/过滤键盘等 screen
- app bootstrap、session controller
- page command、firmware、global action controller
- `app/app_modules.gd` 集中依赖
- `protocol/command_schema.gd` 统一命令 schema

`main.gd` 已从约 1588 行降到 500 行，并只保留一个模块 preload。

最近已推送提交：

```text
0e8eb0d 增加统一命令协议表单
1ec467d 集中管理Godot模块依赖
6145102 拆分全局动作控制器
26d3362 拆分固件加载控制器
fb7ca39 拆分页面命令控制器
ffbbf7d 拆分统一输入路由器
9c875ea 拆分UDP连接状态模型
d58f11b 集中键盘和摇杆轴映射
```

## 编码规范决策

用户明确要求以后规范书写代码，尤其是 Zephyr 线程优先级。

已新增但尚未提交：

- `memory/coding_standards.md`
- `AGENTS.md` 中的强制规范摘要
- `memory/MEMORY.md` 索引

核心要求：

- Zephyr 线程必须明确优先级、栈、周期/阻塞条件、同步方式、超时和 watchdog 职责。
- 安全/急停优先于 CAN 控制，CAN 控制优先于 UDP，UDP 优先于遥测和日志。
- 不允许未来小车控制继续依赖默认 main 线程。
- Godot 页面、控制器、模型、协议、输入和平台代码保持分层。
- 每个检查点必须运行相关 build/export。

## 当前真实工作区现场

实际仓库：`/Users/guoweifeng/GameBoy`

当前分支与远端一致于 `0e8eb0d`，但存在大量未提交修改。不要重置、覆盖或把不相关文件混入提交。

当前未提交内容：

- 编码规范：
  - `AGENTS.md`
  - `memory/MEMORY.md`
  - `memory/coding_standards.md`
- 用户/独立改动：
  - `godot_terminal/export_presets.cfg`
  - `memory/project_rgb30_host.md`
  - `统一命令表单设计.md`
  - `godot_terminal/scripts/screens/monitor_screen.gd`（速度单位改为 pulse/s）
- 正在进行、尚未验证提交的 ESP32/Zephyr 解耦：
  - `command_handler.c/.h`
  - `telemetry.c/.h`
  - `sdo_transport.c/.h`
  - `motor_state.h`
  - `main.c`
  - `canopen_basic.c/.h`
  - `CMakeLists.txt`
  - `prj.conf`

ESP32 解耦现场概述：

- `main.c` 已从约 500 行的命令/遥测混合入口缩为初始化、CAN 转发、循环调度。
- UDP 命令分发移到 `command_handler.c`。
- 周期遥测移到 `telemetry.c`。
- SDO/NMT 传输移到 `sdo_transport.c`。
- 共享电机状态移到 `motor_state.h`，定义仍在 `main.c`。
- `canopen_basic.c` 保留 CiA 402 运动控制。
- `CMakeLists.txt` 已加入新模块。
- `prj.conf` 暂时设置 `CONFIG_MAIN_THREAD_PRIORITY=5`、`CONFIG_SYSTEM_WORKQUEUE_PRIORITY=1`，但尚未完成真正的线程化设计。

## 2026-06-19 优化状态（历史快照，已被后续回退与正式 UI 迁移取代）

固件分支 `codex/sdo-stability` 已完成并暂存：

- `command_handler`、`telemetry`、`sdo_transport`、`motor_state` 正式进入构建。
- 活动节点统一由命令策略解析，heartbeat/estop 不更新活动节点。
- 真实驱动 Fault、软件急停锁存和展示状态分离。
- SDO 类型化读取、错误/值分离、字段新鲜度和字段级独立退避。
- heartbeat 超时只触发一次主动安全失能，SDO 等待不喂通信看门狗。
- 主机策略测试和 Zephyr 4.4.99 ESP32-S3 构建通过。

UI 分支 `codex/refactor-godot-ui` 的独立 worktree
`/Users/guoweifeng/GameBoy/.worktrees/ui-stale` 已完成并暂存：

- 从未有效的字段显示 `--`；已有有效值短暂 stale 时保留最后值并灰显。
  E-STOP、真实 Fault、OFFLINE 分开显示。
- 新增稳定 Linux event 输入桥和开机自启服务；实体机重启后已验证
  `enabled/active` 且 Godot 收到 `ready`。
- motor_data 自动测试和原 CAN 日志测试通过。
- monitor/CAN/OTA/config 页面级布局统一集中到 `ui_config.gd`。
- Godot 4.6.3 Linux ARM64 headless export通过。

尚未完成：

1. 按 `dongle_firmware/can_dongle/tests/HARDWARE_REGRESSION.md` 执行实机回归。
2. 由用户按实体 A/B 做最终交互确认；自动检查已确认输入桥重启后自启。
3. 实机通过后分别提交固件和 UI 检查点；未经用户批准不推送 Azure。
4. Mac 端持久日志需先设计独立日志目标或多客户端协议，避免抢占 RGB30 回包。

## 继续工作时必须注意

- 当前 Codex 可写工作区 `/Users/guoweifeng/Documents/Game Boy` 是一个空仓库，不是真实项目。
- 真正项目是 `/Users/guoweifeng/GameBoy`；修改它需要获得对应文件系统授权。
- 不要使用 destructive git 操作。
- 不要自动恢复或删除用户的未提交文件。
- 不要在没有安全确认时发送 enable/jog/move_position 等会让电机动作的命令。

## 2026-06-19 遥测优化回退记录

- 模块化 ESP32 遥测/SDO 优化未通过实体六字段新鲜度验收，已按用户要求将
  `dongle_firmware/can_dongle` 完整恢复到 Git 优化前基线并重新烧录。
- 回退后只发送 heartbeat 的 20 秒实测收到 23 个 `motor_status`，23 包均包含
  current/voltage/speed/position/torque/status_word 六字段。
- CAN 日志观察到 node 2 的六个 SDO 对象均有响应：
  `0x3001/0x6041/0x6064/0x606C/0x6077/0x6079`，本次 DLC 均为 8。
- 失败的 ESP32 解耦版本已保存为
  `memory/backups/can-dongle-decoupled-unverified-2026-06-19.patch`，
  SHA-256:
  `723cae06903af3777cdd4387274be316fd97399af3623b78db8ac668b7aa7557`。
  该补丁仅供审计和后续逐步重做，禁止作为稳定固件发布。
- UI 解耦正式版本已迁移到唯一目录
  `/Users/guoweifeng/GameBoy/godot_terminal`；旧 `ui-stale` worktree 已删除。
- 2026-06-22 已修正并锁定实体按键：
  L2=`BTN_TL2(312)`/E-STOP，Select=`BTN_SELECT(314)`/language select。
- UI 检查点 `6c04ac1` 当时通过三个 Godot 测试、ARM64 导出和 RGB30 启动
  验证；当时的纯 UI 发布提交为 `195d8bf`。当前 Azure 检查点见后续记录。
- 2026-06-22 后续范围限定为 RGB30/Godot UI；当前正常运行的 ESP32 不再由本
  UI 工作流修改，未来由其他开发者完整重做。
- UI 已增加危险操作二次确认（关机、EEPROM 持久化、OTA flash），E-STOP
  始终绕过确认框；畸形/未知 UDP 包不再刷新在线时间。
- OTA 已明确标记为实验功能；未来 ESP32 接口要求记录在
  `godot_terminal/docs/ESP32_UI_CONTRACT.md`。

## 2026-06-22 UI 命令关联与生产自启

- 新增 `command_tracker.gd`，按 `seq` 关联请求与 ACK/SDO 结果，限制最多
  128 个待处理请求，并过滤重复或迟到的带序号响应。
- SDO read 的 ACK 仅作为中间响应，最终由 `sdo_read_result` 结束跟踪；
  无序号旧固件继续兼容并执行节点过滤。
- 对带序号 ACK 使用请求关联作为节点可信来源，修复旧固件 ACK 默认
  `node=1` 导致 node 2 命令被 UI 忽略的问题。
- 新增 `app_event_executor.gd`，将 UDP 发送与系统关机从 `main.gd`
  的协调职责中分离。
- 新增生产 systemd service/timer 和安装脚本。定时器在开机 20 秒后启动
  Godot，启动脚本重启并等待 Sway/Wayland/EGL 就绪；实体重启验证
  Godot、输入桥、timer 均 active 且 `NRestarts=0`。
- 8 项自动测试通过，Godot 4.6.3 Linux ARM64 导出通过。最终二进制
  SHA-256 为
  `379b0f39f31c0cbd2c2288fe7900f422e6d440ebf5227a8e58cdec1b7d12d514`。
- 最终二进制部署后设备返回 `ui_pid=3363`、Godot service active、
  timer active。本轮没有修改 ESP32。

## 2026-06-22 RGB30 模态弹出界面

- 关机确认框从主界面 `_draw()` 中分离为独立 `CanvasLayer`，不再跳转页面，
  底层语言界面的状态和选择位置保持不变。
- RGB30 的 Mali/Wayland Compatibility 路径无法可靠呈现原全屏半透明遮罩，
  且同一绘制批次曾出现背景覆盖顺序异常和部分文字缺失。
- 最终方案保留原页面内容，在模态显示期间关闭背景网格，并使用不透明 Panel
  及单个多行 Label 显示标题、正文和操作提示。
- 9 项自动测试、Linux ARM64 导出和 RGB30 实机验证通过，服务
  `NRestarts=0`。本地提交经备注修正后为 `ad4b81e`，Azure 对应代码提交为
  `cde8796`。
- 后续临时确认、警告和操作提示应复用该方式，除非交互本身确实需要进入一个
  独立、长期存在的工作页面。

## 2026-06-22 Azure UI 文档纠错

- Azure MotorBoy-UI `stage` 已更新到 `4bdb7cb`。
- README 将错误的 current waveform 修正为 speed waveform，并记录独立
  `CanvasLayer` 模态实现约束。
- API 示例统一使用当前默认 node 2，但明确禁止实现写死节点；点动速度示例从
  错误的 `500` 修正为 `50000 pulse/s`。
- `motor_status` 文档已区分当前旧固件兼容格式与未来扩展格式，不再把
  `valid_mask`、`fresh_mask` 等未来字段描述成当前固件既有事实。
- Select 的可信功能统一为返回语言选择，L2 为专用 E-STOP。
