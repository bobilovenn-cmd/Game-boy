---
name: rgb30-host-setup
description: PowKiddy RGB30 作为手持诊断工具母机，运行 SDL2 诊断界面，通过 WiFi UDP 与 ESP32 CAN Dongle 通信，计划迁移至 Godot
metadata:
  node_type: memory
  type: project
  originSessionId: b4c32e84-189c-4a36-8d47-8a901e9505d7
---

RGB30 作为手持诊断工具母机，运行 SDL2 诊断界面，通过 WiFi UDP 与 ESP32 CAN Dongle 通信。

**Why:** 用户正在开发 AGV/AMR 电机诊断调试工具，需要一个便携式手持终端。

## 当前状态（2026-06-09）

### 已完成
- ROCKNIX 系统已安装，开机自启动诊断界面
- Python 3.13.9 + Entware 包管理器
- SDL2 显示（KMSDRM，720x720）
- SDL2_ttf 文字渲染（LiberationMono 22号）
- 按键映射全部验证正确
- D-pad 页面内导航（上下移动选中项，A 确认）
- 三个页面：Monitor / Config / OTA
- UDP 通信模块（JSON over UDP）
- 心跳发送（150ms 间隔）
- 开机自启动（systemd 服务）
- ext4 文件系统修复（2026-06-09）
- SDL2 颜色通道修复：ARGB8888 格式下需用 struct.pack('BBBB', a, r, g, b) 而非 (r, g, b, a)
- UI 布局调整完成（右侧数值、菜单栏、按键提示位置）
- 开机 fsck 跳过：extlinux.conf 添加 fsck.mode=skip

### 待完成
- 连接 ESP32 子机热点测试 UDP 通信
- 接电机测试 SDO 读写、点动、急停
- **迁移到 Godot**（上级要求）

### 故障记录
- 2026-06-09：SD 卡写入中途被拔出，ext4 分区损坏，设备无限重启
  - macOS 无法直接写入 ext4，需通过 dd 复制镜像 → e2fsck 修复 → dd 写回
  - macOS 的 e2fsprogs 无法直接对 /dev/rdiskXsX 执行写操作（Invalid argument）
  - 修复步骤：`dd if=/dev/rdisk6s2 of=/tmp/storage.ext4.img bs=1M` → `e2fsck -f -y /tmp/storage.ext4.img` → `dd if=/tmp/storage.ext4.img of=/dev/rdisk6s2 bs=1M`
  - 文件系统问题：未来时间戳、journal inode 残留、bitmap 差异、块计数错误
  - 注意：ext4 日志（journal）被意外移除后设备无法启动，需保持 has_journal 特性
  - macOS 上 dd 用 bs=1 会报 Invalid argument，必须用 bs=1M 或更大

## 设备信息

| 项目 | 详情 |
|------|------|
| 设备 | PowKiddy RGB30, RK3566, 720x720 |
| 系统 | ROCKNIX |
| SSH | root@192.168.31.125, 密码 rocknix |
| Python | /opt/bin/python3 (Entware) |
| 显示 | 系统 SDL2 via ctypes, KMSDRM 驱动 |
| 字体 | /usr/share/fonts/liberation/LiberationMono-Regular.ttf |

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
| Mac 端代码 | /Users/guoweifeng/Game BOY/handheld_terminal/ |
| 设备端代码 | /storage/handheld_terminal/ |
| 项目文档 | /Users/guoweifeng/Game BOY/手持诊断工具_软件开发教程.md |
| ESP32 子机 | ~/esp32-can-dongle/ |
| systemd 服务 | /storage/.config/system.d/diag-terminal.service |
| 启动脚本 | /storage/handheld_terminal/start.sh |

## 通信协议

- 子机 AP 热点：CAN_Dongle_01，密码 C@nDongle2024
- 子机 IP：192.168.4.1，端口 5000
- 母机监听端口：5001
- 心跳间隔：150ms
- 格式：JSON over UDP

## 当前技术方案（SDL2）

- 显示：系统 SDL2 (/usr/lib/libSDL2-2.0.so.0) 通过 ctypes 调用，pygame 的 bundled SDL2 没有 KMSDRM 不能用
- 文字：SDL2_ttf 渲染，字体 /usr/share/fonts/liberation/LiberationMono-Regular.ttf
- 按键：直接读取 /dev/input/js0（evdev 格式）
- 颜色：像素格式 ARGB8888，struct.pack 顺序为 (a, r, g, b)
- 启动时停止 EmulationStation/Sway，退出时恢复
- 开机 fsck 已跳过（extlinux.conf: fsck.mode=skip）
- 自启动已关闭（disabled），手动启动命令：`sshpass -p "rocknix" ssh root@192.168.31.125 "/storage/handheld_terminal/start.sh"`

## Godot 迁移计划（待执行）

上级要求迁移到 Godot。需要改动：
- 显示层：SDL2 → Godot 渲染引擎，需验证 RK3566 Mali-G52 兼容性
- 输入：/dev/input/js0 → Godot Input 系统
- 网络：Python socket → PacketPeerUDP
- UI：代码绘制 → Control 节点 + Theme
- 系统集成：systemd 服务改为启动 Godot 可执行文件
- 保留不变：UDP 协议、ESP32 子机端、按键功能逻辑
- 风险：Godot 4 对 Mali-G52 兼容性，可能需回退 Godot 3
