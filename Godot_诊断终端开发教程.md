# Godot 4.x 手持诊断终端开发完整教程

> 基于 `godot_terminal` 项目的实际代码，详细讲解如何使用 Godot 4.6 引擎开发一个运行在 PowKiddy RGB30 掌机上的 AGV 电机诊断终端。

---

## 目录

- [第一章：项目概述与架构](#第一章项目概述与架构)
- [第二章：Godot 开发环境搭建](#第二章godot-开发环境搭建)
- [第三章：项目配置详解 (project.godot)](#第三章项目配置详解)
- [第四章：场景系统与节点树](#第四章场景系统与节点树)
- [第五章：GDScript 语言基础](#第五章gdscript-语言基础)
- [第六章：自定义绘制系统 (_draw)](#第六章自定义绘制系统)
- [第七章：输入处理系统](#第七章输入处理系统)
- [第八章：UDP 网络通信](#第八章udp-网络通信)
- [第九章：通信协议层设计](#第九章通信协议层设计)
- [第十章：电机数据管理](#第十章电机管理)
- [第十一章：OTA 固件升级](#第十一章ota-固件升级)
- [第十二章：导出与部署到 RGB30](#第十二章导出与部署)
- [附录：从 Python/SDL2 迁移到 Godot 的经验总结](#附录迁移经验)

---

# 第一章：项目概述与架构

## 1.1 我们要做什么

本项目的目标是用 Godot 4.6 引擎开发一个运行在 **PowKiddy RGB30** 掌机上的 **AGV 电机诊断终端**。这个终端通过 Wi-Fi 连接到一个 ESP32 CAN Dongle（子机），再由子机通过 CAN 总线控制电机控制器，实现对电机的监控、配置和固件升级。

```
┌──────────────────┐    Wi-Fi (UDP)    ┌──────────────────┐    CAN Bus    ┌──────────┐
│  手持诊断终端     │ ◄──────────────► │  CAN Dongle      │ ◄───────────► │ 电机控制器 │
│  RGB30 + Godot   │                   │  ESP32 + Zephyr  │               │ CANopen  │
│  720x720 UI      │                   │                  │               │          │
└──────────────────┘                   └──────────────────┘               └──────────┘
```

## 1.2 功能需求

终端提供三个核心页面：

| 页面 | 功能 | 说明 |
|------|------|------|
| **Monitor** | 电机监控 | 实时显示电流、电压、转速、位置、扭矩、状态；支持使能/去使能/急停/点动 |
| **Config** | 参数配置 | 通过 SDO 读写电机对象字典（CiA 402），配置模式、速度、PID 参数等 |
| **OTA** | 固件升级 | 加载固件文件，分片发送到 Dongle，校验 MD5，刷写到电机控制器 |

## 1.3 技术选型

| 项目 | 选型 | 说明 |
|------|------|------|
| 游戏引擎 | Godot 4.6.3 | 轻量级、跨平台、GDScript 易学 |
| 渲染方式 | 自定义 `_draw()` | 不用 UI 节点，直接用 CanvasItem 绘制 API |
| 渲染后端 | GL Compatibility | 兼容低端设备（RGB30 使用 Mali GPU） |
| 网络协议 | JSON over UDP | 轻量、易调试，150ms 心跳 |
| 输入方式 | 游戏手柄 + 键盘 | RGB30 的 `/dev/input/js0` 按键映射 |
| 目标平台 | Linux ARM64 | Godot 导出为单文件可执行程序 |

## 1.4 项目目录结构

```
godot_terminal/
├── project.godot           # Godot 项目配置文件
├── export_presets.cfg      # 导出预设（Linux ARM64）
├── scenes/
│   └── main.tscn           # 主场景（唯一的场景文件）
├── scripts/
│   ├── main.gd             # 主脚本：UI 绘制、输入处理、业务逻辑
│   ├── settings.gd         # 全局配置常量
│   ├── protocol.gd         # 通信协议：JSON 消息构建与解析
│   └── motor_data.gd       # 电机数据模型：状态解析、波形历史
├── deploy/
│   ├── rgb30_start_godot.sh    # 在 RGB30 上启动 Godot 终端
│   └── rgb30_restore_python.sh # 恢复 Python/SDL2 服务
└── build/
    └── rgb30_diag_terminal_arm64  # 导出的 ARM64 可执行文件
```

---

# 第二章：Godot 开发环境搭建

## 2.1 安装 Godot 4.6

### macOS（推荐，因为本项目在 Mac 上开发）

```bash
# 方法一：Homebrew 安装
brew install --cask godot

# 方法二：手动下载
# 从 https://godotengine.org/download/macos/ 下载 Godot 4.6.3
# 解压后拖入 Applications 文件夹
```

### 安装导出模板（导出到 Linux ARM64 必需）

1. 打开 Godot Editor
2. 菜单栏 → Editor → Manage Export Templates
3. 下载与 Godot 版本匹配的模板（4.6.3 stable）
4. 等待下载完成

## 2.2 打开项目

```bash
# 方法一：直接用命令行打开
open -a "Godot" /Users/guoweifeng/Game\ Boy/godot_terminal

# 方法二：在 Godot 启动器中点击 "Import"，选择项目文件夹中的 project.godot
```

## 2.3 Godot 编辑器界面介绍

打开项目后，你会看到以下核心面板：

```
┌──────────────────────────────────────────────────────┐
│  菜单栏  [Scene] [Project] [Debug] [Editor] [Help]  │
├────────────┬──────────────────────────┬──────────────┤
│            │                          │  Inspector   │
│  Scene     │      2D / 3D 视口        │  (属性检查器) │
│  (场景树)  │      (编辑器主区域)       │              │
│            │                          │  Node        │
│            │                          │  (节点面板)   │
├────────────┴──────────────────────────┴──────────────┤
│  FileSystem           │  Output / Debugger           │
│  (文件系统)            │  (输出/调试器)                │
└───────────────────────┴──────────────────────────────┘
```

**常用快捷键：**

| 快捷键 | 功能 |
|--------|------|
| `Ctrl/Cmd + S` | 保存当前场景 |
| `F5` | 运行项目 |
| `F6` | 运行当前场景 |
| `Ctrl/Cmd + Shift + F` | 全局搜索 |
| `Ctrl/Cmd + K` | 打开脚本编辑器 |

## 2.4 安装 GDScript 语法高亮插件（可选）

如果你更喜欢用 VS Code 编写 GDScript：

```bash
# 在 VS Code 中安装扩展
# 搜索 "godot-tools" 或 "GDScript"
```

---

# 第三章：项目配置详解 (project.godot)

`project.godot` 是 Godot 项目的根配置文件，相当于其他引擎中的项目设置。让我们逐行分析本项目的配置：

```ini
; Engine configuration file.
config_version=5

[application]

config/name="AGV Diagnostic Terminal"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.6", "GL Compatibility")
```

### 逐行解析：

**`config_version=5`**
- Godot 4.x 使用配置版本 5（Godot 3.x 使用版本 4）
- 这是引擎内部用来判断项目格式的标记

**`config/name="AGV Diagnostic Terminal"`**
- 项目的显示名称，会出现在窗口标题和导出的应用名称中

**`run/main_scene="res://scenes/main.tscn"`**
- 指定按下 F5 运行时加载的入口场景
- `res://` 是 Godot 的资源路径协议，指向项目根目录
- 这意味着项目的"入口"是 `scenes/main.tscn` 这个场景文件

**`config/features=PackedStringArray("4.6", "GL Compatibility")`**
- 声明项目使用的 Godot 版本和渲染特性
- `GL Compatibility` 是兼容性渲染模式，适合低端 GPU（如 RGB30 的 Mali）

```ini
[display]

window/size/viewport_width=720
window/size/viewport_height=720
window/size/resizable=false
window/stretch/mode="canvas_items"
```

### 显示配置解析：

**`viewport_width=720` 和 `viewport_height=720`**
- 设置游戏逻辑分辨率为 720×720 像素
- RGB30 的屏幕物理分辨率恰好是 720×720
- 这个分辨率也是所有 UI 坐标的基准

**`resizable=false`**
- 窗口不可调整大小
- 因为最终运行在掌机上，分辨率固定

**`stretch/mode="canvas_items"`**
- 这是 Godot 的**拉伸模式**，非常重要
- `canvas_items` 意味着：当实际窗口大小与 viewport 大小不同时，引擎会自动缩放所有 2D 绘制内容
- 好处：在不同分辨率的屏幕上，UI 会按比例缩放，不会出现错位
- 比 `viewport` 模式更清晰，因为文字不会模糊

```ini
[rendering]

textures/canvas_textures/default_texture_filter=0
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

### 渲染配置解析：

**`default_texture_filter=0`**
- 0 = Nearest（最近邻插值）
- 1 = Linear（线性插值）
- 2 = Nearest with Mipmaps
- 使用 Nearest 可以保持像素风格的清晰边缘，适合复古掌机风格

**`rendering_method="gl_compatibility"`**
- 使用 OpenGL 兼容模式，而不是 Vulkan
- RGB30 的 Mali-G52 GPU 对 Vulkan 支持有限
- 这是确保在掌机上能运行的关键配置

---

# 第四章：场景系统与节点树

## 4.1 Godot 的核心概念：场景树

Godot 采用**场景树（Scene Tree）**架构。一切游戏对象都是**节点（Node）**，节点按父子关系组织成树状结构。

```
场景树示意：
Root (Main)
├── Control          ← 我们的主节点
│   ├── (由脚本动态绘制的 UI)
│   └── ...
```

## 4.2 分析 main.tscn 场景文件

我们的项目只有一个场景文件 `scenes/main.tscn`：

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1_main"]

[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_main")
```

### 逐行解析：

**`[gd_scene load_steps=2 format=3]`**
- 声明场景文件格式版本 3（Godot 4.x）
- `load_steps=2` 表示场景加载时需要处理 2 个资源（场景节点本身 + 外部脚本）

**`[ext_resource type="Script" path="res://scripts/main.gd" id="1_main"]`**
- 声明一个外部资源：`main.gd` 脚本
- `id="1_main"` 是引用标识，后面节点通过此 ID 关联脚本

**`[node name="Main" type="Control"]`**
- 创建一个名为 "Main" 的 **Control** 节点
- Control 是 Godot 中所有 UI 节点的基类
- 它本身没有视觉表现，但支持 `_draw()` 自定义绘制

**`layout_mode = 3`**
- 3 表示使用锚点（Anchors）布局模式
- 与传统的固定位置布局不同，锚点布局让节点适应父容器大小

**`anchors_preset = 15`**
- 预设 15 = 全屏（Full Rect）
- 表示节点的四边都锚定到父容器的四边
- 效果：节点自动填满整个窗口

**`anchor_right = 1.0` 和 `anchor_bottom = 1.0`**
- 右锚点 = 1.0（父容器的右边缘）
- 下锚点 = 1.0（父容器的下边缘）
- 左锚点和上锚点默认为 0.0（父容器的左上角）
- 因此节点覆盖整个父容器

**`script = ExtResource("1_main")`**
- 将 `main.gd` 脚本附加到此节点
- 脚本中的 `_ready()`、`_process()`、`_draw()` 等方法会被自动调用

## 4.3 为什么只用一个场景？

本项目采用**极简架构**：只有一个场景、一个主节点。所有 UI 都通过 `_draw()` 自定义绘制，而不是使用 Godot 内置的 UI 节点（如 Button、Label、VBoxContainer）。

这种设计的好处：
- **完全控制**：每个像素的位置和样式都由代码决定
- **性能更好**：没有 UI 节点的布局计算开销
- **便于移植**：与原来的 Python/SDL2 版本逻辑一一对应
- **更轻量**：适合资源受限的嵌入式设备

---

# 第五章：GDScript 语言基础

在深入项目代码之前，先学习 GDScript 的核心语法。GDScript 是 Godot 的专用脚本语言，语法类似 Python。

## 5.1 基本语法

```gdscript
# 单行注释

# 变量声明（类型推断）
var health = 100          # 整数
var speed = 3.5           # 浮点数
var name = "Player"       # 字符串
var is_alive = true       # 布尔值
var items = ["sword", "shield"]  # 数组
var data = {"key": "value"}     # 字典

# 类型注解（可选但推荐）
var max_health: int = 100
var position: float = 0.0
var label_text: String = "Hello"

# 常量
const MAX_SPEED = 500
const PI = 3.14159
```

## 5.2 函数

```gdscript
# 基本函数
func greet(name: String) -> String:
    return "Hello, " + name + "!"

# 无返回值
func take_damage(amount: int) -> void:
    health -= amount

# 默认参数
func move(direction: String = "forward", speed: float = 1.0) -> void:
    pass  # pass 是空操作占位符
```

## 5.3 控制流

```gdscript
# if/elif/else
if health > 50:
    print("Healthy")
elif health > 20:
    print("Warning")
else:
    print("Critical")

# match（类似 switch，但更强大）
match current_state:
    "idle":
        start_moving()
    "running":
        continue_running()
    "jumping":
        apply_gravity()
    _:
        # 默认情况（_ 是通配符）
        reset()

# for 循环
for i in range(10):
    print(i)

for item in inventory:
    print(item)

# while 循环
while health > 0:
    process_turn()
```

## 5.4 类与继承

```gdscript
# 继承 Control 节点
extends Control

# 类变量
var score = 0
var lives = 3

# 内置生命周期方法
func _ready() -> void:
    # 节点进入场景树时调用（类似 Unity 的 Start）
    print("Ready!")

func _process(delta: float) -> void:
    # 每帧调用（delta 是帧间隔秒数）
    # 类似 Unity 的 Update
    pass

func _physics_process(delta: float) -> void:
    # 物理帧调用（固定频率，默认 60fps）
    pass
```

## 5.5 信号系统（本项目未使用，但值得了解）

```gdscript
# 声明信号
signal health_changed(new_health)
signal died

# 发射信号
emit_signal("health_changed", health)
emit_signal("died")

# 连接信号
player.health_changed.connect(_on_health_changed)

func _on_health_changed(new_health: int) -> void:
    health_bar.value = new_health
```

---

# 第六章：自定义绘制系统 (_draw)

这是本项目最核心的技术点。所有 UI 都通过 `_draw()` 方法手动绘制。

## 6.1 理解 _draw() 的工作原理

在 Godot 中，任何继承 `CanvasItem` 的节点（包括 `Control`、`Node2D` 等）都可以重写 `_draw()` 方法来进行自定义绘制。

```gdscript
extends Control

func _draw() -> void:
    # 这里的所有绘制调用都会在节点上绘制
    # 坐标系原点在节点左上角
    draw_rect(Rect2(0, 0, 100, 100), Color.RED, true)
```

**关键点：**
- `_draw()` 只在以下情况被调用：
  1. 节点第一次显示时
  2. 调用 `queue_redraw()` 时
- 如果你需要每帧更新画面，必须在 `_process()` 中调用 `queue_redraw()`

```gdscript
func _process(_delta: float) -> void:
    # 更新逻辑...
    queue_redraw()  # 请求重绘

func _draw() -> void:
    # 绘制逻辑...
```

## 6.2 颜色定义

在 `main.gd` 中，颜色被定义为常量：

```gdscript
const C_BG = Color8(26, 26, 46)         # 深蓝背景
const C_PANEL = Color8(22, 33, 62)      # 面板背景
const C_TEXT = Color8(238, 238, 244)     # 主文本（亮白）
const C_DIM = Color8(166, 170, 188)      # 次要文本（灰）
const C_ACCENT = Color8(0, 212, 170)     # 强调色（青绿）
const C_RED = Color8(231, 76, 60)        # 红色（警告/错误）
const C_YELLOW = Color8(243, 156, 18)    # 黄色（提示）
const C_BORDER = Color8(58, 58, 92)      # 边框色
const C_INPUT = Color8(10, 10, 30)       # 输入框背景
const C_SEL = Color8(15, 52, 96)         # 选中项背景
const C_BLACK = Color8(0, 0, 0)          # 黑色
```

`Color8(r, g, b)` 用 0-255 的整数创建颜色，比 `Color(r/255.0, g/255.0, b/255.0)` 更直观。

## 6.3 核心绘制 API

### 绘制矩形

```gdscript
# 绘制填充矩形
draw_rect(Rect2(x, y, width, height), color, filled)

# 示例：绘制一个面板背景
draw_rect(Rect2(10, 40, 190, 36), C_PANEL, true)

# 绘制边框（filled=false）
draw_rect(Rect2(10, 40, 190, 36), C_BORDER, false, 1.0)
# 最后一个参数是线宽
```

### 绘制文本

```gdscript
# draw_string(font, position, text, alignment, width, font_size, color)
draw_string(font, Vector2(x, y + font_size), text, align, width, font_size, color)
```

**注意**：`draw_string` 的 `position` 参数是文本的**基线**位置，所以通常需要在 y 坐标上加上 `font_size` 才能让文本出现在预期位置。

项目中封装了一个辅助方法：

```gdscript
func _draw_text(text: String, x: float, y: float, color: Color,
                font_size: int = 16,
                align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
                width: float = -1.0) -> void:
    if font == null:
        return
    draw_string(font, Vector2(x, y + font_size), text, align, width, font_size, color)
```

### 绘制折线（波形图）

```gdscript
# draw_polyline(points, color, width)
var points = PackedVector2Array()
points.append(Vector2(10, 100))
points.append(Vector2(50, 80))
points.append(Vector2(90, 120))
draw_polyline(points, C_ACCENT, 2.0)
```

## 6.4 完整的绘制层次

在 `_draw()` 中，绘制顺序就是覆盖顺序（后绘制的在上面）：

```gdscript
func _draw() -> void:
    # 第 1 层：全屏背景
    draw_rect(Rect2(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT), C_BG, true)

    # 第 2 屆：根据当前 Tab 绘制页面内容
    match current_tab:
        0: _draw_monitor()
        1: _draw_config()
        2: _draw_ota()

    # 第 3 层：底部 Tab 栏（覆盖在页面内容之上）
    _draw_tabs()

    # 第 4 层：状态消息弹窗（最上层）
    _draw_status()

    # 第 5 层：底部操作提示
    _draw_footer()
```

## 6.5 波形图绘制详解

波形图是 Monitor 页面的核心功能，展示了如何将数据可视化：

```gdscript
func _draw_waveform(rect: Rect2) -> void:
    var vals = motor.current_history    # 获取电流历史数据
    var n = min(vals.size(), 80)        # 最多显示 80 个点
    if n < 2:
        _draw_text("Waiting for motor_status packets...",
                    rect.position.x + 8, rect.position.y + 12, C_DIM, 12)
        return

    # 计算数据范围（用于归一化）
    var start = vals.size() - n
    var vmin = vals[start]
    var vmax = vals[start]
    for i in range(start, vals.size()):
        vmin = min(vmin, vals[i])
        vmax = max(vmax, vals[i])
    var vrange = vmax - vmin
    if absf(vrange) < 0.001:   # 防止除以零
        vrange = 1.0

    # 将数据点转换为屏幕坐标
    var points = PackedVector2Array()
    for i in n:
        var v: float = vals[start + i]
        # x 坐标：按比例分布
        var px = rect.position.x + float(i) * rect.size.x / float(max(n - 1, 1))
        # y 坐标：归一化到矩形高度（注意 y 轴向下）
        var py = rect.position.y + rect.size.y - ((v - vmin) / vrange * rect.size.y)
        points.append(Vector2(px, py))

    # 绘制折线
    if points.size() >= 2:
        draw_polyline(points, C_ACCENT, 2.0)
```

**关键数学原理：**
- 数据归一化：`(value - min) / (max - min)` 将数据映射到 0.0 ~ 1.0
- Y 轴翻转：`rect.size.y - normalized * rect.size.y` 因为屏幕 Y 轴向下

---

# 第七章：输入处理系统

本项目需要同时支持 RGB30 游戏手柄和 Mac 键盘两种输入方式。

## 7.1 Godot 输入事件模型

Godot 的输入处理遵循事件驱动模型：

```
用户按下按键 → 操作系统事件 → Godot 输入系统 → _input(event) 回调
```

## 7.2 键盘输入处理

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        _handle_key(event.keycode)
```

**逐行解析：**

- `event is InputEventKey`：类型检查，只处理键盘事件
- `event.pressed`：只处理按下事件（不处理释放）
- `not event.echo`：过滤掉长按产生的重复事件（按住不放时操作系统会重复触发）
- `event.keycode`：获取按键码（如 `KEY_UP`、`KEY_ENTER`）

### 键盘映射表

```gdscript
func _handle_key(keycode: int) -> void:
    match keycode:
        KEY_TAB:        _handle_action("menu")
        KEY_UP:         _handle_action("up")
        KEY_DOWN:       _handle_action("down")
        KEY_LEFT:       _handle_action("left")
        KEY_RIGHT:      _handle_action("right")
        KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
                        _handle_action("confirm")
        KEY_ESCAPE:     _handle_action("back")
        KEY_X:          _handle_action("enable")
        KEY_Y:          _handle_action("disable")
        KEY_Q:          _handle_action("jog_ccw")
        KEY_E:          _handle_action("jog_cw")
        KEY_S:          _handle_action("estop")
```

注意 `match` 语句支持多个值匹配同一分支（`KEY_ENTER, KEY_KP_ENTER, KEY_SPACE`）。

## 7.3 游戏手柄输入处理

RGB30 的按键通过 `/dev/input/js0` 设备上报，Godot 会将其识别为 `InputEventJoypadButton`。

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        _handle_key(event.keycode)
    elif event is InputEventJoypadButton:
        _handle_joy_button(event.button_index, event.pressed)
```

### 手柄按键映射

RGB30 的原始按键 ID（通过 `/dev/input/js0` 验证）：

```gdscript
const RGB30_RAW_BUTTONS = {
    0: "back",      # B 按键
    1: "confirm",   # A 按键
    2: "enable",    # X 按键
    3: "disable",   # Y 按键
    4: "jog_ccw",   # L1
    5: "jog_cw",    # R1
    6: "estop",     # L2
    8: "estop",     # Select
    9: "menu",      # Start
    13: "up",       # D-pad 上
    14: "down",     # D-pad 下
    15: "left",     # D-pad 左
    16: "right",    # D-pad 右
}
```

如果 Godot 通过 SDL 标准化了手柄按键，可以切换到 `godot_standard` 配置：

```gdscript
const GODOT_STANDARD_BUTTONS = {
    0: "confirm",   # A
    1: "back",      # B
    2: "enable",    # X
    3: "disable",   # Y
    4: "estop",     # L1
    6: "menu",      # Start
    9: "jog_ccw",   # L2
    10: "jog_cw",   # R2
    11: "up",
    12: "down",
    13: "left",
    14: "right",
}
```

通过 `settings.gd` 中的 `INPUT_PROFILE` 常量切换。

### 点动的特殊处理

按下 L1/R1 开始点动，松开时自动发送停止命令：

```gdscript
func _handle_joy_button(button_index: int, pressed: bool) -> void:
    var mapping = RGB30_RAW_BUTTONS
    if AppSettings.INPUT_PROFILE == "godot_standard":
        mapping = GODOT_STANDARD_BUTTONS

    if not mapping.has(button_index):
        return

    var action: String = mapping[button_index]
    if pressed:
        _handle_action(action)
    elif action == "jog_cw" or action == "jog_ccw":
        _handle_action("jog_stop")  # 松开点动键时自动停止
```

## 7.4 统一的动作处理

所有输入最终汇聚到 `_handle_action()` 方法。这个设计模式叫**输入抽象层**：将物理按键映射到逻辑动作，再将逻辑动作映射到业务操作。新增输入设备只需添加映射表，不需要修改业务逻辑。

```gdscript
func _handle_action(action: String) -> void:
    match action:
        "menu":
            current_tab = (current_tab + 1) % TAB_NAMES.size()
            _set_status(">> %s" % TAB_NAMES[current_tab])
        "up":
            selected[current_tab] = max(0, int(selected[current_tab]) - 1)
        "down":
            var max_idx = MONITOR_ITEMS.size() - 1
            if current_tab == 1:
                max_idx = CONFIG_ITEMS.size() - 1
            elif current_tab == 2:
                max_idx = OTA_ITEMS.size() - 1
            selected[current_tab] = min(max_idx, int(selected[current_tab]) + 1)
        "confirm":
            _confirm_current_selection()
        "back":
            _send(Protocol.jog_stop(AppSettings.DEFAULT_NODE_ID), "Jog stopped")
        "enable":
            _send(Protocol.enable(AppSettings.DEFAULT_NODE_ID), "Enable sent")
        "disable":
            _send(Protocol.disable(AppSettings.DEFAULT_NODE_ID), "Disable sent")
        "estop":
            _send(Protocol.estop(), "E-STOP sent", true)
        "jog_cw":
            _send(Protocol.jog_start(AppSettings.DEFAULT_NODE_ID, "cw", 500), "Jog CW")
        "jog_ccw":
            _send(Protocol.jog_start(AppSettings.DEFAULT_NODE_ID, "ccw", 500), "Jog CCW")
        "jog_stop":
            _send(Protocol.jog_stop(AppSettings.DEFAULT_NODE_ID), "Jog stopped")
```

---

# 第八章：UDP 网络通信

## 8.1 为什么选择 UDP

对于 150ms 的高频心跳包，UDP 的低延迟优势明显。丢一两个心跳包不会影响系统运行。

| 特性 | UDP | TCP |
|------|-----|-----|
| 延迟 | 低（无握手） | 较高（三次握手） |
| 可靠性 | 不保证 | 保证送达 |
| 适用场景 | 实时心跳、状态上报 | 文件传输 |

## 8.2 Godot 的 PacketPeerUDP

```gdscript
# 1. 创建 UDP 对象
var udp = PacketPeerUDP.new()

# 2. 绑定本地端口（接收数据）
var err = udp.bind(5001, "0.0.0.0")

# 3. 设置目标地址（发送数据）
udp.set_dest_address("192.168.4.1", 5000)

# 4. 发送数据
udp.put_packet("Hello".to_utf8_buffer())

# 5. 接收数据
while udp.get_available_packet_count() > 0:
    var raw = udp.get_packet().get_string_from_utf8()
    print("Received: ", raw)
```

## 8.3 项目中的完整网络初始化

```gdscript
func _ready() -> void:
    font = get_theme_default_font()
    if font == null:
        font = ThemeDB.fallback_font

    var err = udp.bind(AppSettings.LOCAL_UDP_PORT, "0.0.0.0")
    if err == OK:
        udp.set_dest_address(AppSettings.DONGLE_IP, AppSettings.DONGLE_UDP_PORT)
        udp_ready = true
        _set_status("UDP listening on %d" % AppSettings.LOCAL_UDP_PORT)
    else:
        _set_status("UDP bind failed: %d" % err, true)

    set_process(true)
```

## 8.4 心跳机制与连接检测

```gdscript
func _process(_delta: float) -> void:
    var now = Time.get_ticks_msec()

    # 每 150ms 发送心跳
    if udp_ready and now - last_heartbeat_msec >= AppSettings.HEARTBEAT_INTERVAL_MS:
        _send(Protocol.heartbeat())
        last_heartbeat_msec = now

    # 1.5 秒无数据则判定离线
    if last_rx_msec > 0 and now - last_rx_msec > 1500:
        motor.alive = false
```

## 8.5 接收与消息分发

```gdscript
func _poll_udp() -> void:
    if not udp_ready:
        return
    while udp.get_available_packet_count() > 0:
        var raw = udp.get_packet().get_string_from_utf8()
        var data = Protocol.parse(raw)
        _handle_message(data)

func _handle_message(data: Dictionary) -> void:
    last_rx_msec = Time.get_ticks_msec()
    var cmd = str(data.get("cmd", ""))
    var payload = data
    if data.has("payload") and typeof(data["payload"]) == TYPE_DICTIONARY:
        payload = data["payload"]
        payload["cmd"] = cmd

    match cmd:
        "motor_status":
            motor.update_from_dict(payload)
            motor.alive = true
        "sdo_read_result":
            _handle_sdo_result(payload)
        "ota_status":
            _handle_ota_status(payload)
        "ack":
            var status = str(payload.get("status", ""))
            var msg = str(payload.get("msg", ""))
            var text = "OK: %s" % msg if status == "ok" else "ERR: %s" % msg
            _set_status(text, status != "ok")
```

---

# 第九章：通信协议层设计

## 9.1 Protocol 类

`protocol.gd` 是纯工具类，使用 `static` 方法，无需实例化：

```gdscript
extends RefCounted
class_name Protocol

static var _seq_counter = 0

static func _next_seq() -> int:
    _seq_counter += 1
    return _seq_counter

static func _build(cmd: String, payload: Dictionary = {}) -> String:
    var msg = {
        "cmd": cmd,
        "seq": _next_seq(),
        "ts": int(Time.get_unix_time_from_system()),
    }
    if not payload.is_empty():
        msg["payload"] = payload
    return JSON.stringify(msg)
```

**设计要点：**
- `class_name Protocol`：声明全局类名，其他脚本可直接用 `Protocol.heartbeat()` 调用
- `static` 方法：适合无状态的工具操作
- `_next_seq()` 序列号：每个消息自动递增，用于请求-响应匹配

## 9.2 消息格式

```json
{
    "cmd": "命令名",
    "seq": 1,
    "ts": 1680000000,
    "payload": { ... }
}
```

## 9.3 完整命令列表

### 控制命令

```gdscript
Protocol.enable(node)           # 使能电机
Protocol.disable(node)          # 去使能
Protocol.estop()                # 急停
Protocol.jog_start(node, "cw", 500)  # 顺时针点动
Protocol.jog_stop(node)         # 停止点动
```

### SDO 读写（CiA 402 对象字典）

```gdscript
Protocol.sdo_read(node, 0x6041, 0)        # 读取状态字
Protocol.sdo_write(node, 0x6060, 0, 3)    # 设置运行模式为 PV
```

### OTA 命令

```gdscript
Protocol.ota_start(size, md5)   # 开始传输
Protocol.ota_chunk(offset, b64) # 发送数据块
Protocol.ota_verify()           # 请求校验
Protocol.ota_flash(node)        # 刷写到电机
```

### JSON 解析

```gdscript
static func parse(data: String) -> Dictionary:
    var parsed = JSON.parse_string(data)
    if typeof(parsed) == TYPE_DICTIONARY:
        return parsed
    return {"cmd": "unknown", "error": "json_parse_failed"}
```

---

# 第十章：电机数据管理

## 10.1 MotorData 类设计

`motor_data.gd` 继承 `RefCounted`（引用计数对象，不是节点），用 `class_name` 注册为全局类：

```gdscript
extends RefCounted
class_name MotorData

# 当前值
var current = 0.0
var voltage = 0.0
var speed = 0
var position = 0.0
var torque = 0.0
var status_word = 0
var fault_code = 0
var mode = 0
var alive = false
var wdg_ms = 0

# 波形历史数据
var timestamps: Array[float] = []
var current_history: Array[float] = []
var speed_history: Array[float] = []
var torque_history: Array[float] = []
```

## 10.2 从字典更新数据

当收到 Dongle 的 `motor_status` 消息时：

```gdscript
func update_from_dict(data: Dictionary) -> void:
    if data.has("current"):
        current = float(data["current"])
    if data.has("voltage"):
        voltage = float(data["voltage"])
    if data.has("speed"):
        speed = int(data["speed"])
    if data.has("position"):
        position = float(data["position"])
    if data.has("torque"):
        torque = float(data["torque"])
    if data.has("fault"):
        fault_code = int(data["fault"])
    if data.has("mode"):
        mode = int(data["mode"])
    if data.has("alive"):
        alive = bool(data["alive"])
    if data.has("wdg_ms"):
        wdg_ms = int(data["wdg_ms"])
    if data.has("status_word"):
        status_word = _parse_status_word(data["status_word"])

    # 更新波形历史
    var t = float(Time.get_ticks_msec() - _start_msec) / 1000.0
    _push_history(timestamps, t)
    _push_history(current_history, current)
    _push_history(speed_history, float(speed))
    _push_history(torque_history, torque)
```

注意每种字段都用 `has()` 检查后再转换类型，避免 KeyError。

## 10.3 波形历史管理

```gdscript
const AppSettings = preload("res://scripts/settings.gd")

func _push_history(target: Array, value: float) -> void:
    target.append(value)
    while target.size() > AppSettings.WAVEFORM_HISTORY:  # 最多 200 个点
        target.pop_front()
```

这是一个**滑动窗口**：新数据追加到末尾，超出容量时从头部移除。窗口大小由 `WAVEFORM_HISTORY = 200` 控制。

## 10.4 CiA 402 状态字解析

电机控制器的状态字遵循 CiA 402 标准，通过位掩码解析当前状态：

```gdscript
func get_status_text() -> String:
    var sw = status_word
    if sw & 0x004F == 0x0000:
        return "Not Ready"
    if sw & 0x004F == 0x0040:
        return "Switch Off"
    if sw & 0x006F == 0x0021:
        return "Ready"
    if sw & 0x006F == 0x0023:
        return "Switched On"
    if sw & 0x006F == 0x0027:
        return "Enabled"
    if sw & 0x004F == 0x0008:
        return "FAULT"
    return "0x%s" % _hex(sw)
```

**位运算解析逻辑：**
- `&` 是按位与运算
- `0x004F` 是掩码，提取状态字的 bit 0-3 和 bit 6
- 不同的组合对应不同的 CiA 402 状态机状态

### 故障检测

```gdscript
func is_fault() -> bool:
    return (status_word & 0x0008) != 0 or fault_code != 0
```

bit 3 为 1 表示 FAULT 状态，或者 fault_code 不为 0。

---

# 第十一章：OTA 固件升级

## 11.1 OTA 流程概览

```
1. Load Firmware     → 从文件系统加载固件二进制文件
2. Send to Dongle    → 分片发送到 ESP32 Dongle
3. Verify MD5        → 校验传输完整性
4. Flash Motor       → 将固件刷写到电机控制器
```

## 11.2 固件加载

```gdscript
const FIRMWARE_PATHS = [
    "/storage/firmware.bin",
    "/storage/update.bin",
    "/storage/motor_firmware.bin",
]

func _load_default_firmware() -> bool:
    for path in AppSettings.FIRMWARE_PATHS:
        if FileAccess.file_exists(path):
            var bytes = FileAccess.get_file_as_bytes(path)
            if bytes.is_empty():
                continue
            firmware_data = bytes
            firmware_size = firmware_data.size()
            firmware_name = path.get_file()
            firmware_md5 = FileAccess.get_md5(path)
            ota_state = "ready"
            ota_progress = 0
            _log_ota("Loaded %s (%d KB)" % [firmware_name, firmware_size / 1024])
            return true
    _log_ota("No firmware found in /storage")
    return false
```

**关键 API：**
- `FileAccess.file_exists(path)`：检查文件是否存在
- `FileAccess.get_file_as_bytes(path)`：读取整个文件为字节数组
- `FileAccess.get_md5(path)`：计算文件的 MD5 哈希值
- `path.get_file()`：从完整路径中提取文件名

## 11.3 分片传输

OTA 传输在 `_process()` 中异步进行，每 10ms 发送一个 512 字节的块：

```gdscript
const OTA_CHUNK_SIZE = 512
const OTA_SEND_INTERVAL_MS = 10

func _process_ota(now: int) -> void:
    if ota_state != "sending":
        return
    if now - last_ota_send_msec < AppSettings.OTA_SEND_INTERVAL_MS:
        return
    last_ota_send_msec = now

    # 第一步：发送 OTA 开始命令
    if not ota_started:
        _send(Protocol.ota_start(firmware_size, firmware_md5))
        ota_started = true
        return

    # 传输完成
    if ota_offset >= firmware_size:
        ota_state = "verify"
        ota_progress = 100
        _log_ota("Transfer done %.1f KB/s" % ota_speed_kbps)
        return

    # 发送一个数据块
    var end = min(ota_offset + AppSettings.OTA_CHUNK_SIZE, firmware_size)
    var chunk = firmware_data.slice(ota_offset, end)
    var data_b64 = Marshalls.raw_to_base64(chunk)
    _send(Protocol.ota_chunk(ota_offset, data_b64))
    ota_offset = end

    # 更新进度
    var elapsed = max(0.001, float(now - ota_start_msec) / 1000.0)
    ota_progress = int(float(ota_offset) * 100.0 / float(firmware_size))
    ota_speed_kbps = (float(ota_offset) / 1024.0) / elapsed
```

**关键设计：**
- `Marshalls.raw_to_base64(chunk)`：将二进制数据编码为 Base64 字符串，用于 JSON 传输
- `firmware_data.slice(start, end)`：切片获取指定范围的字节
- 传输速率计算：`已传输字节 / 耗时秒数 / 1024 = KB/s`

## 11.4 OTA 状态机

```
idle → ready → sending → verify → done
                         ↓
                       error
```

| 状态 | 含义 | 触发条件 |
|------|------|---------|
| `idle` | 未加载固件 | 初始状态 |
| `ready` | 固件已加载 | 调用 `_load_default_firmware()` 成功 |
| `sending` | 正在传输 | 调用 `_start_ota_transfer()` |
| `verify` | 等待校验 | 所有数据块发送完成 |
| `done` | 刷写完成 | 收到 Dongle 的 `ota_status: done` |
| `error` | 出错 | 收到 Dongle 的 `ota_status: error` |

---

# 第十二章：导出与部署到 RGB30

## 12.1 配置导出预设

`export_presets.cfg` 定义了导出目标：

```ini
[preset.0]
name="RGB30 Linux ARM64"
platform="Linux"
export_path="build/rgb30_diag_terminal_arm64"

[preset.0.options]
binary_format/architecture="arm64"
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=true
```

**关键选项：**
- `architecture="arm64"`：导出 ARM64 架构的可执行文件（RGB30 使用 RK3566 ARM64 芯片）
- `embed_pck=true`：将资源文件嵌入到可执行文件中，生成单文件程序
- `texture_format`：启用 S3TC 和 ETC2 纹理压缩格式

## 12.2 导出步骤

在 Godot 编辑器中：

1. 菜单栏 → Project → Export
2. 选择 "RGB30 Linux ARM64" 预设
3. 点击 "Export Project"
4. 保存到 `build/rgb30_diag_terminal_arm64`

导出后得到一个单独的可执行文件，包含了所有资源。

## 12.3 部署到 RGB30

### 上传文件

```bash
# 通过 SCP 上传到 RGB30
scp build/rgb30_diag_terminal_arm64 root@<RGB30_IP>:/storage/handheld_terminal_godot/
```

### 启动脚本

`deploy/rgb30_start_godot.sh` 负责在 RGB30 上启动 Godot 终端：

```bash
#!/bin/sh
set -eu

# 1. 停止原来的 Python/SDL2 服务
systemctl stop diag-terminal.service 2>/dev/null || true
sleep 3

# 2. 启动 Sway（Wayland 合成器）
systemctl restart sway.service
sleep 5

# 3. 设置 Wayland 环境变量
export XDG_RUNTIME_DIR=/var/run/0-runtime-dir
export WAYLAND_DISPLAY=wayland-1
export SWAYSOCK=/run/0-runtime-dir/sway-ipc.0.sock
export MALI_WAYLAND_AFBC=0
export GODOT_SILENCE_ROOT_WARNING=1

# 4. 配置显示输出（720x720）
swaymsg output DSI-1 enable >/dev/null 2>&1 || true
swaymsg output DSI-1 mode 720x720 >/dev/null 2>&1 || true
swaymsg output DSI-1 power on >/dev/null 2>&1 || true
echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null || true

# 5. 启动 Godot 终端
cd /storage/handheld_terminal_godot
exec ./rgb30_diag_terminal_arm64 \
  --display-driver wayland \
  --rendering-method gl_compatibility \
  --fullscreen \
  --resolution 720x720
```

**启动参数说明：**
- `--display-driver wayland`：使用 Wayland 显示驱动（RGB30 使用 Sway 合成器）
- `--rendering-method gl_compatibility`：使用 OpenGL 兼容渲染
- `--fullscreen`：全屏模式
- `--resolution 720x720`：指定分辨率

### 恢复 Python 服务

`deploy/rgb30_restore_python.sh` 用于回滚：

```bash
#!/bin/sh
pkill -f rgb30_diag_terminal_arm64 2>/dev/null || true
systemctl start diag-terminal.service
systemctl is-active diag-terminal.service
```

## 12.4 全局配置 (settings.gd)

所有可配置的常量集中在一个文件中，方便修改：

```gdscript
extends RefCounted
class_name AppSettings

# 网络配置
const DONGLE_IP = "192.168.4.1"
const DONGLE_UDP_PORT = 5000
const LOCAL_UDP_PORT = 5001
const HEARTBEAT_INTERVAL_MS = 150

# CAN 配置
const DEFAULT_NODE_ID = 1
const CAN_BAUDRATE = 500000

# OTA 配置
const OTA_CHUNK_SIZE = 512
const OTA_SEND_INTERVAL_MS = 10

# 显示配置
const SCREEN_WIDTH = 720
const SCREEN_HEIGHT = 720
const FPS = 30
const WAVEFORM_HISTORY = 200

# 输入配置
const INPUT_PROFILE = "rgb30_raw"

# 固件搜索路径
const FIRMWARE_PATHS = [
    "/storage/firmware.bin",
    "/storage/update.bin",
    "/storage/motor_firmware.bin",
]
```

---

# 附录：从 Python/SDL2 迁移到 Godot 的经验总结

## A.1 架构对比

| 方面 | Python/SDL2 版本 | Godot 版本 |
|------|-----------------|------------|
| 渲染 | SDL2 直接绑定 DRM/KMS framebuffer | Godot CanvasItem `_draw()` |
| 输入 | 直接读取 `/dev/input/js0` 二进制流 | Godot 输入事件系统 |
| 网络 | 自定义 UDPClient + 线程 | PacketPeerUDP 内置类 |
| 字体 | 预加载 SDL_ttf | ThemeDB.fallback_font |
| 主循环 | 手动 `while True` + `time.sleep(1/30)` | Godot `_process(delta)` 自动调用 |
| 部署 | Python 解释器 + 依赖库 | 单文件 ARM64 可执行程序 |

## A.2 迁移中的关键差异

1. **渲染同步**：Python 版需要手动 `display.flip()`，Godot 版只需 `queue_redraw()`，引擎自动处理双缓冲
2. **输入去重**：Python 版需要手动处理 `struct.unpack` 的 js0 事件，Godot 已经封装好了 `InputEvent`
3. **线程安全**：Python 版用线程读取手柄输入，Godot 的输入在主线程回调，无需锁
4. **字体渲染**：SDL2 需要 SDL_ttf 库，Godot 内置字体渲染，直接用 `draw_string()`
5. **资源管理**：Godot 自动管理资源生命周期，Python 版需要手动关闭文件和释放 SDL surface

## A.3 调试建议

```bash
# 在 Mac 上本地测试时，用键盘代替手柄
# 方向键导航，Enter/Space 确认，Tab 切换页面

# 查看 Godot 控制台输出
# Godot Editor 底部的 "Output" 面板会显示 print() 输出

# 网络调试
# 可以用 nc (netcat) 模拟 Dongle 发送数据：
echo '{"cmd":"motor_status","payload":{"current":2.5,"voltage":24,"speed":1500}}' | nc -u -w1 127.0.0.1 5001
```

