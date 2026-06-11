---
name: godot-rgb30-test
description: Godot 4.6.3 ARM64 export test results on PowKiddy RGB30 / ROCKNIX + Mock Server 集成验证
metadata: 
  node_type: memory
  type: project
  date: 2026-06-11
  originSessionId: f49ec00f-e03c-4fe6-8908-14dc696d670d
---

Godot 4.6.3 ARM64 export was built and copied to RGB30:

```text
/storage/handheld_terminal_godot/rgb30_diag_terminal_arm64
```

The binary runs on RGB30 and `--version` succeeds:

```text
4.6.3.stable.official.7d41c59c4
```

## 2026-06-11 Mock Server 集成验证

### Mock Server 连接成功
- Mock server 运行在 Mac (192.168.31.128:5000 UDP, :8080 Web)
- DONGLE_IP 改为 192.168.31.128 后 Godot 终端成功连接
- LINK 指示灯变绿 = motor_status 数据包正常接收
- UDP 指示灯变绿 = 本机 5001 端口绑定成功

### 修复的关键 Bug
1. **motor_status 从未发送**: udp_loop 中 update_motor() 更新 last_status 后，第二个 if 判断永远不触发 → 合并为一个代码块
2. **DONGLE_IP 错误**: 原指向 ESP32 AP 192.168.4.1 → 开发调试改为 Mac IP 192.168.31.128
3. **Web Dashboard 自动刷新**: JS setInterval 为空操作 → 改为 500ms fetch + DOM 更新

### 数据流向
```
Godot :5001 ──heartbeat──> mock :5000
Godot :5001 <──motor_status── mock :5000  (10Hz)
浏览器 ──HTTP──> mock :8080 (Web Dashboard, 500ms 自动刷新)
```

### 启动流程
```bash
cd "/Users/guoweifeng/Game BOY/mock_server" && ./start_mock.sh
```
自动完成: mock server 启动 → RGB30 SSH 检查 → 部署 Godot 二进制 → 重启 sway → 启动 Godot

### 显示测试结果
- Wayland + gl_compatibility: ✅ 正常渲染
- Vulkan Mobile: ❌ swapchain 创建失败 (Mali-G52 不支持)
- RGB30 屏幕: ✅ UI 可见，遥测数据实时更新
- 按键映射: ✅ /dev/input/js0 原始映射正常
- 波形面板: ✅ motor_status 数据驱动曲线

## 历史记录

2026-06-09 RGB30 UI readability pass:

- User compared the Mac Godot preview with the physical RGB30 screen and found
  that many small or dim labels were visible on Mac but missing on RGB30.
- Affected areas included telemetry values/units, HOTKEYS, INPUT/LAST values,
  the header subtitle, Config status values, SDO result, and OTA metadata.
- Selection styling also failed on RGB30: selected rows became black/invisible.
- `godot_terminal/scripts/main.gd` was adjusted for RGB30 readability:
  larger small-text sizes, brighter dim text, smaller telemetry value digits,
  taller metric cards, and high-contrast selected rows using dark fill,
  cyan border/left bar, and white text instead of cyan fill with black text.
- The fixed export was rebuilt and deployed to:
  `/storage/handheld_terminal_godot/rgb30_diag_terminal_arm64`

2026-06-09 second RGB30 readability pass:

- The first pass did not fix the physical RGB30 display. User still saw missing
  telemetry values/units, missing header subtitle, missing Config help/status
  text, missing SDO result, missing OTA metadata/log text, and invisible
  selected rows.
- The UI was changed to prioritize physical RGB30 visibility over the Mac
  preview style:
  - Critical text now uses larger 18-26 px sizes.
  - Missing secondary text was changed to pure white or high-contrast yellow.
  - Selected command/config rows no longer use cyan fill or dark selected fill.
    They now use a black base, thick white border, yellow left marker, and
    white text.
  - Telemetry labels, values, and units were enlarged and forced to
    high-contrast white/yellow.
  - OTA firmware metadata, transfer state, target address, and OTA log entries
    were enlarged and forced to high-contrast colors.
- Rebuilt and redeployed the export to RGB30.
- The new RGB30 process started successfully as PID 38619. Logs only showed the
  known Wayland/OpenGL fallback warnings, with no immediate crash.
