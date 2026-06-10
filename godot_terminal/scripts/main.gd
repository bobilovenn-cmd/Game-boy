## 主控制器 - main.gd
## 作用: 应用入口，整合所有功能模块
## 职责:
##   - UI渲染: 绘制监控、配置、OTA、CAN日志页面
##   - 输入处理: 读取/dev/input/js0手柄按键 + Godot键盘事件
##   - UDP通信: 与ESP32 CAN网关收发消息
##   - OTA固件升级: 加载、分块传输、校验、刷写
## 依赖: settings.gd, protocol.gd, motor_data.gd, ui_text.gd

extends Control

## 依赖模块加载
const AppSettings = preload("res://scripts/settings.gd")  # 全局配置
const Protocol = preload("res://scripts/protocol.gd")      # 通信协议
const MotorDataScript = preload("res://scripts/motor_data.gd")  # 电机数据模型
const UiText = preload("res://scripts/ui_text.gd")          # 国际化文本

## 主题色常量 - 深色科技风格配色方案
const C_BG = Color8(4, 8, 14)          # 背景色(深蓝黑)
const C_BG_2 = Color8(8, 18, 28)        # 次背景色
const C_PANEL = Color8(13, 29, 43)       # 面板背景
const C_PANEL_2 = Color8(18, 42, 58)     # 次面板背景
const C_INPUT = Color8(3, 12, 20)        # 输入框背景
const C_LINE = Color8(42, 92, 110)       # 边框线
const C_GRID = Color8(22, 58, 72)        # 网格线
const C_TEXT = Color8(234, 247, 252)      # 主文本(亮白)
const C_DIM = Color8(178, 214, 224)      # 次要文本(灰白)
const C_DIM_2 = Color8(145, 184, 196)    # 更暗文本
const C_ACCENT = Color8(0, 226, 188)     # 强调色(青绿)
const C_ACCENT_2 = Color8(56, 158, 255)  # 次强调色(蓝)
const C_WARN = Color8(255, 184, 77)      # 警告色(橙黄)
const C_RED = Color8(255, 72, 92)        # 错误色(红)
const C_GREEN = Color8(75, 255, 156)     # 成功色(绿)
const C_BLACK = Color8(0, 0, 0)          # 黑色

## UI配置常量
const LANGUAGE_OPTIONS = [UiText.LANG_ZH, UiText.LANG_EN]  # 支持的语言列表
const TAB_KEYS = ["tab_monitor", "tab_config", "tab_ota", "tab_can"]   # 页面标签
const MONITOR_ITEM_KEYS = ["cmd_enable", "cmd_disable", "cmd_estop", "cmd_jog_cw", "cmd_jog_ccw"]  # 监控页命令列表

## 配置页参数列表 - [显示名, CANopen索引, 子索引, 单位描述]
## 索引对应CiA 402协议的对象字典
const CONFIG_ITEMS = [
	["cfg_mode", 0x6060, 0, "cfg_drive_mode"],           # 驱动模式
	["cfg_control_word", 0x6040, 0, "cfg_cia_402"],       # 控制字
	["cfg_target_speed", 0x60FF, 0, "cfg_rpm"],           # 目标速度
	["cfg_target_torque", 0x6071, 0, "cfg_permille"],     # 目标转矩
	["cfg_pid_kp", 0x2010, 0, "cfg_proportional"],        # PID比例系数
	["cfg_pid_ki", 0x2011, 0, "cfg_integral"],            # PID积分系数
	["cfg_pid_kd", 0x2012, 0, "cfg_derivative"],          # PID微分系数
	["cfg_current_limit", 0x2013, 0, "cfg_amps"],         # 电流限制
	["cfg_save_eeprom", 0x1010, 1, "cfg_persist"],        # 保存到EEPROM
]
const OTA_ITEM_KEYS = ["ota_load", "ota_send", "ota_verify", "ota_flash"]  # OTA升级步骤
const CAN_ITEM_KEYS = ["can_filter", "can_reset", "can_pause"]  # CAN日志页操作
const KEYBOARD_ROWS = [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
	["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
	["A", "S", "D", "F", "G", "H", "J", "K", "L"],
	["Z", "X", "C", "V", "B", "N", "M"],
	["SHIFT", "-", "_", ":", ".", "SP", "DEL", "CLR", "OK"],
]

## RGB30手柄按键映射 - 直接读取/dev/input/js0的原始按键ID
## 优先使用此映射，响应更直接
const RGB30_RAW_BUTTONS = {
	0: "back",      # 返回键
	1: "confirm",   # 确认键(A)
	2: "enable",    # 使能键(X)
	3: "disable",   # 失能键(Y)
	4: "jog_ccw",   # 逆时针点动(L1)
	5: "jog_cw",    # 顺时针点动(R1)
	6: "language_select",  # SELECT: 返回语言选择界面
	7: "stick_press",  # 左轴按下(无动作)
	8: "language_select",  # SELECT: 返回语言选择界面(备用映射)
	9: "menu",      # 菜单/切页(START)
	13: "up",       # 上
	14: "down",     # 下
	15: "left",     # 左
	16: "right",    # 右
}

## Godot/SDL标准手柄按键映射 - 备用方案
## 当/dev/input/js0读取失败时使用
const GODOT_STANDARD_BUTTONS = {
	0: "confirm",
	1: "back",
	2: "enable",
	3: "disable",
	4: "language_select",
	6: "menu",
	7: "stick_press",
	9: "jog_ccw",
	10: "jog_cw",
	11: "up",
	12: "down",
	13: "left",
	14: "right",
}

## 核心对象
var font: Font                              # 当前字体
var udp = PacketPeerUDP.new()               # UDP通信对象
var motor = MotorDataScript.new()           # 电机数据实例

## 语言选择状态
var language_selected = false               # 是否已选择语言
var selected_language = 0                   # 当前选中的语言索引
var ui_lang = UiText.LANG_ZH               # 当前界面语言

## 页面导航状态
var current_tab = 0                         # 当前页面(0=监控, 1=配置, 2=OTA, 3=CAN日志)
var selected = [0, 0, 0, 0]                 # 各页面当前选中项索引

## 状态提示
var status_msg = ""                         # 状态提示文本
var status_kind = "info"                    # 提示类型(info/warn/error)
var status_until_msec = 0                   # 提示消失时间戳
var result_msg = ""                         # SDO读取结果

## UDP连接状态
var last_heartbeat_msec = 0                 # 上次心跳时间
var last_rx_msec = 0                        # 上次收到数据时间
var udp_ready = false                       # UDP是否就绪

## OTA固件升级状态
var firmware_data = PackedByteArray()       # 固件二进制数据
var firmware_md5 = ""                       # 固件MD5校验值
var firmware_name = ""                      # 固件文件名
var firmware_size = 0                       # 固件大小(字节)
var ota_state = "idle"                      # OTA状态(idle/ready/sending/verify/done/error)
var ota_progress = 0                        # 传输进度(0-100)
var ota_speed_kbps = 0.0                    # 传输速度(KB/s)
var ota_log: Array[String] = []             # OTA日志队列
var ota_offset = 0                          # 当前传输偏移量
var ota_started = false                     # 是否已发送ota_start命令
var ota_start_msec = 0                      # 传输开始时间
var last_ota_send_msec = 0                  # 上次发送数据块时间

## CAN日志页面状态
var can_filter = ""                         # CAN日志过滤字段
var can_rows: Array[Dictionary] = []         # CAN/UDP接收日志
var can_paused = false                      # 暂停刷新
var keyboard_open = false                   # 是否显示虚拟键盘
var keyboard_row = 0                        # 虚拟键盘选中行
var keyboard_col = 0                        # 虚拟键盘选中列
var keyboard_lowercase = false              # 虚拟键盘是否小写输入

## 手柄输入状态 - 使用独立线程读取/dev/input/js0
var raw_thread: Thread                      # 输入读取线程
var raw_mutex = Mutex.new()                 # 线程互斥锁
var raw_queue: Array[int] = []              # 按键事件队列
var raw_running = false                     # 线程运行标志
var raw_input_ok = false                    # /dev/input/js0是否可用
var last_input_label = "none"               # 最近按键调试标签
var last_raw_button = -1                    # 最近原始按键ID
var godot_input_enabled = false             # 是否启用Godot标准输入(备用)
var godot_axis_active = {}                  # fallback 轴输入去抖状态


## 应用初始化
func _ready() -> void:
	# 加载打包的CJK字体(支持中英文)，失败则回退到系统字体
	var cjk_font = ResourceLoader.load("res://fonts/AGV_CJK.ttf", "", ResourceLoader.CACHE_MODE_REUSE)
	if cjk_font:
		font = cjk_font
	else:
		font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font

	# 绑定本地UDP端口，设置目标地址(ESP32网关)
	var err = udp.bind(AppSettings.LOCAL_UDP_PORT, "0.0.0.0")
	if err == OK:
		udp.set_dest_address(AppSettings.DONGLE_IP, AppSettings.DONGLE_UDP_PORT)
		udp_ready = true
		_set_status("UDP ready 0.0.0.0:%d -> %s:%d" % [AppSettings.LOCAL_UDP_PORT, AppSettings.DONGLE_IP, AppSettings.DONGLE_UDP_PORT])
	else:
		_set_status("UDP bind failed: %d" % err, "error")

	# 启动手柄输入线程
	_start_raw_input()
	_log_ota("Godot terminal ready")
	set_process(true)


func _exit_tree() -> void:
	raw_running = false
	if raw_thread and raw_thread.is_started():
		raw_thread.wait_to_finish()


## 主循环 - 每帧执行
func _process(_delta: float) -> void:
	var now = Time.get_ticks_msec()
	# 处理手柄输入队列
	_drain_raw_input()
	# 语言未选择时只渲染语言选择界面
	if not language_selected:
		queue_redraw()
		return

	# 轮询UDP接收电机数据
	_poll_udp()

	# 定时发送心跳包维持连接
	if udp_ready and now - last_heartbeat_msec >= AppSettings.HEARTBEAT_INTERVAL_MS:
		_send(Protocol.heartbeat())
		last_heartbeat_msec = now

	# 超过1.5秒未收到数据则标记电机离线
	if last_rx_msec > 0 and now - last_rx_msec > 1500:
		motor.alive = false

	# 处理OTA传输逻辑
	_process_ota(now)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
	elif godot_input_enabled and event is InputEventJoypadButton:
		_handle_godot_joy_button(event.button_index, event.pressed)
	elif godot_input_enabled and event is InputEventJoypadMotion:
		_handle_godot_joy_motion(event.axis, event.axis_value)


## 渲染入口 - 根据当前状态绘制对应界面
func _draw() -> void:
	_draw_background()           # 绘制网格背景
	if not language_selected:
		_draw_language_select()  # 语言选择界面
		return

	_draw_header()               # 顶部标题栏(LINK/UDP状态指示)
	_draw_tabs()                 # 页面标签栏(监控/配置/升级)

	# 根据当前页面绘制内容
	match current_tab:
		0:
			_draw_monitor_page()   # 监控页: 命令列表 + 遥测数据 + 波形图
		1:
			_draw_config_page()    # 配置页: 对象字典参数读写
		2:
			_draw_ota_page()       # OTA页: 固件加载/传输/校验/刷写
		3:
			_draw_can_page()       # CAN日志页: 接收日志 + 过滤输入

	_draw_status_overlay()       # 状态提示浮层
	if keyboard_open:
		_draw_virtual_keyboard()
	_draw_footer()               # 底部快捷键提示栏


## 启动手柄输入线程 - 直接读取Linux /dev/input/js0设备
func _start_raw_input() -> void:
	raw_running = true
	raw_thread = Thread.new()
	var err = raw_thread.start(Callable(self, "_raw_input_loop"))
	if err != OK:
		raw_input_ok = false
		godot_input_enabled = true  # 回退到Godot标准输入
		_set_status("Raw input thread failed; using Godot joypad fallback", "warn")


func _raw_input_loop() -> void:
	var f = FileAccess.open("/dev/input/js0", FileAccess.READ)
	if f == null:
		raw_mutex.lock()
		raw_input_ok = false
		godot_input_enabled = true
		raw_mutex.unlock()
		return

	raw_mutex.lock()
	raw_input_ok = true
	godot_input_enabled = false
	raw_mutex.unlock()

	while raw_running:
		var buf = f.get_buffer(8)
		if buf.size() < 8:
			OS.delay_msec(8)
			continue
		var value = _i16_le(buf[4], buf[5])
		var event_type = buf[6] & 0x7f
		var number = buf[7]
		if event_type == 1:
			raw_mutex.lock()
			if value == 1:
				raw_queue.append(number)
			elif value == 0 and (number == 4 or number == 5):
				raw_queue.append(1000 + number)
			raw_mutex.unlock()


func _drain_raw_input() -> void:
	var events: Array[int] = []
	raw_mutex.lock()
	if not raw_queue.is_empty():
		events = raw_queue.duplicate()
		raw_queue.clear()
	raw_mutex.unlock()

	for raw in events:
		if raw >= 1000:
			var release_id = raw - 1000
			last_raw_button = release_id
			last_input_label = "raw %d -> jog_stop" % release_id
			_handle_action("jog_stop")
			continue
		last_raw_button = raw
		var action = RGB30_RAW_BUTTONS.get(raw, "")
		last_input_label = "raw %d -> %s" % [raw, action if action != "" else "unmapped"]
		if action != "":
			_handle_action(action)
		else:
			_set_status("Unmapped raw button %d" % raw, "warn")


func _handle_godot_joy_button(button_index: int, pressed: bool) -> void:
	if not GODOT_STANDARD_BUTTONS.has(button_index):
		return
	var action: String = GODOT_STANDARD_BUTTONS[button_index]
	last_input_label = "godot %d -> %s" % [button_index, action]
	if pressed:
		_handle_action(action)
	elif action == "jog_cw" or action == "jog_ccw":
		_handle_action("jog_stop")


func _handle_godot_joy_motion(axis: int, value: float) -> void:
	var action = ""
	if axis == 4:
		action = "estop"
	elif axis == 5:
		action = "r2"
	if action == "":
		return

	var is_pressed = value > 0.55
	var was_pressed = bool(godot_axis_active.get(axis, false))
	if is_pressed == was_pressed:
		return
	godot_axis_active[axis] = is_pressed
	last_input_label = "axis %d %.2f -> %s" % [axis, value, action if is_pressed else "release"]
	if is_pressed:
		_handle_action(action)


func _handle_key(keycode: int) -> void:
	match keycode:
		KEY_TAB:
			_handle_action("menu")
		KEY_UP:
			_handle_action("up")
		KEY_DOWN:
			_handle_action("down")
		KEY_LEFT:
			_handle_action("left")
		KEY_RIGHT:
			_handle_action("right")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_handle_action("confirm")
		KEY_ESCAPE:
			_handle_action("back")
		KEY_X:
			_handle_action("enable")
		KEY_Y:
			_handle_action("disable")
		KEY_Q:
			_handle_action("jog_ccw")
		KEY_E:
			_handle_action("jog_cw")
		KEY_S:
			_handle_action("estop")


func _handle_action(action: String) -> void:
	if not language_selected:
		_handle_language_action(action)
		return
	if keyboard_open:
		_handle_keyboard_action(action)
		return

	match action:
		"menu":
			current_tab = (current_tab + 1) % TAB_KEYS.size()
			_set_status("PAGE %s" % _tab_name(current_tab))
		"up":
			selected[current_tab] = max(0, int(selected[current_tab]) - 1)
		"down":
			var max_idx = MONITOR_ITEM_KEYS.size() - 1
			if current_tab == 1:
				max_idx = CONFIG_ITEMS.size() - 1
			elif current_tab == 2:
				max_idx = OTA_ITEM_KEYS.size() - 1
			elif current_tab == 3:
				max_idx = CAN_ITEM_KEYS.size() - 1
			selected[current_tab] = min(max_idx, int(selected[current_tab]) + 1)
		"left":
			current_tab = (current_tab + TAB_KEYS.size() - 1) % TAB_KEYS.size()
			_set_status("PAGE %s" % _tab_name(current_tab))
		"right":
			current_tab = (current_tab + 1) % TAB_KEYS.size()
			_set_status("PAGE %s" % _tab_name(current_tab))
		"confirm":
			_confirm_current_selection()
		"back":
			_send(Protocol.jog_stop(AppSettings.DEFAULT_NODE_ID), "Jog stopped")
		"enable":
			_send(Protocol.enable(AppSettings.DEFAULT_NODE_ID), "Enable sent")
		"disable":
			_send(Protocol.disable(AppSettings.DEFAULT_NODE_ID), "Disable sent")
		"estop":
			_send(Protocol.estop(), "E-STOP sent", "error")
		"jog_cw":
			_send(Protocol.jog_start(AppSettings.DEFAULT_NODE_ID, "cw", 500), "Jog CW")
		"jog_ccw":
			_send(Protocol.jog_start(AppSettings.DEFAULT_NODE_ID, "ccw", 500), "Jog CCW")
		"jog_stop":
			_send(Protocol.jog_stop(AppSettings.DEFAULT_NODE_ID), "Jog stopped")
		"r2":
			_set_status("R2 reserved")
		"stick_press":
			pass
		"language_select":
			_return_to_language_select()


func _handle_language_action(action: String) -> void:
	match action:
		"up", "left":
			selected_language = max(0, selected_language - 1)
			if selected_language < LANGUAGE_OPTIONS.size():
				ui_lang = LANGUAGE_OPTIONS[selected_language]
		"down", "right":
			selected_language = min(2, selected_language + 1)
			if selected_language < LANGUAGE_OPTIONS.size():
				ui_lang = LANGUAGE_OPTIONS[selected_language]
		"confirm":
			if selected_language == 2:
				OS.execute("poweroff", [])
			else:
				language_selected = true
				ui_lang = LANGUAGE_OPTIONS[selected_language]
				_set_status("LANGUAGE %s" % ui_lang.to_upper())


func _return_to_language_select() -> void:
	var idx = LANGUAGE_OPTIONS.find(ui_lang)
	selected_language = idx if idx >= 0 else 0
	language_selected = false
	status_msg = ""
	status_until_msec = 0


func _confirm_current_selection() -> void:
	if current_tab == 0:
		match int(selected[0]):
			0:
				_send(Protocol.enable(AppSettings.DEFAULT_NODE_ID), "Enable sent")
			1:
				_send(Protocol.disable(AppSettings.DEFAULT_NODE_ID), "Disable sent")
			2:
				_send(Protocol.estop(), "E-STOP sent", "error")
			3:
				_send(Protocol.jog_start(AppSettings.DEFAULT_NODE_ID, "cw", 500), "Jog CW")
			4:
				_send(Protocol.jog_start(AppSettings.DEFAULT_NODE_ID, "ccw", 500), "Jog CCW")
	elif current_tab == 1:
		var item: Array = CONFIG_ITEMS[int(selected[1])]
		var name_key: String = item[0]
		var index: int = item[1]
		var sub: int = item[2]
		if name_key == "cfg_save_eeprom":
			_send(Protocol.sdo_write(AppSettings.DEFAULT_NODE_ID, index, sub, 0x65766173), "Save EEPROM")
		else:
			result_msg = "Reading 0x%s..." % _hex(index)
			_send(Protocol.sdo_read(AppSettings.DEFAULT_NODE_ID, index, sub), result_msg)
	elif current_tab == 2:
		match int(selected[2]):
			0:
				_load_default_firmware()
			1:
				_start_ota_transfer()
			2:
				_send(Protocol.ota_verify(), "Verify requested")
				_log_ota("Requesting MD5 verify")
			3:
				_send(Protocol.ota_flash(AppSettings.DEFAULT_NODE_ID), "Flash command sent")
				_log_ota("Flash command sent")
	elif current_tab == 3:
		match int(selected[3]):
			0:
				keyboard_open = true
				keyboard_row = 1
				keyboard_col = 0
			1:
				can_rows.clear()
				_set_status(_t("can_reset_status"))
			2:
				can_paused = not can_paused
				_set_status(_t("can_paused") if can_paused else _t("can_run_status"))


func _handle_keyboard_action(action: String) -> void:
	match action:
		"up":
			keyboard_row = max(0, keyboard_row - 1)
			keyboard_col = min(keyboard_col, KEYBOARD_ROWS[keyboard_row].size() - 1)
		"down":
			keyboard_row = min(KEYBOARD_ROWS.size() - 1, keyboard_row + 1)
			keyboard_col = min(keyboard_col, KEYBOARD_ROWS[keyboard_row].size() - 1)
		"left":
			keyboard_col = max(0, keyboard_col - 1)
		"right":
			keyboard_col = min(KEYBOARD_ROWS[keyboard_row].size() - 1, keyboard_col + 1)
		"confirm":
			_apply_keyboard_key(_keyboard_key_value(keyboard_row, keyboard_col))
		"back":
			keyboard_open = false
		"language_select":
			keyboard_open = false
			_return_to_language_select()


func _apply_keyboard_key(key: String) -> void:
	match key:
		"SP":
			if can_filter.length() < 32:
				can_filter += " "
		"DEL":
			if can_filter.length() > 0:
				can_filter = can_filter.substr(0, can_filter.length() - 1)
		"CLR":
			can_filter = ""
		"OK":
			keyboard_open = false
		"SHIFT":
			keyboard_lowercase = not keyboard_lowercase
		_:
			if can_filter.length() < 32:
				can_filter += key


## 轮询UDP接收缓冲区 - 处理所有待处理的数据包
func _poll_udp() -> void:
	if not udp_ready:
		return
	while udp.get_available_packet_count() > 0:
		var raw = udp.get_packet().get_string_from_utf8()
		var data = Protocol.parse(raw)  # 解析JSON消息
		_record_can_row(raw, data)
		_handle_message(data)           # 分发处理


func _record_can_row(raw: String, data: Dictionary) -> void:
	if can_paused:
		return
	var cmd = str(data.get("cmd", "packet"))
	var payload = data
	if data.has("payload") and typeof(data["payload"]) == TYPE_DICTIONARY:
		payload = data["payload"]
	var can_id = str(payload.get("can_id", payload.get("id", "")))
	var dlc = str(payload.get("dlc", ""))
	var bytes = str(payload.get("data", payload.get("bytes", "")))
	var line = Time.get_time_string_from_system() + "  " + cmd
	if can_id != "":
		line += "  ID " + can_id
	if dlc != "":
		line += "  DLC " + dlc
	if bytes != "":
		line += "  " + bytes
	can_rows.append({"line": line, "raw": raw})
	while can_rows.size() > 80:
		can_rows.pop_front()


## 消息分发处理 - 根据cmd字段路由到对应处理器
func _handle_message(data: Dictionary) -> void:
	last_rx_msec = Time.get_ticks_msec()
	var cmd = str(data.get("cmd", ""))
	var payload = data
	if data.has("payload") and typeof(data["payload"]) == TYPE_DICTIONARY:
		payload = data["payload"]
		payload["cmd"] = cmd

	match cmd:
		"motor_status":        # 电机状态上报(周期性)
			motor.update_from_dict(payload)
			motor.alive = true
		"sdo_read_result":     # SDO读取结果
			_handle_sdo_result(payload)
		"ota_status":          # OTA升级状态
			_handle_ota_status(payload)
		"ack":                 # 通用应答
			var status = str(payload.get("status", ""))
			var msg = str(payload.get("msg", ""))
			var text = "OK: %s" % msg if status == "ok" else "ERR: %s" % msg
			_set_status(text, "info" if status == "ok" else "error")
			result_msg = text
			_log_ota(text)


func _handle_sdo_result(data: Dictionary) -> void:
	var index = int(data.get("index", 0))
	var result = str(data.get("data", ""))
	var val_text = result
	if result.is_valid_hex_number():
		val_text = "0x%s (%d)" % [result, result.hex_to_int()]
	result_msg = "0x%s = %s" % [_hex(index), val_text]
	_set_status(result_msg)


func _handle_ota_status(data: Dictionary) -> void:
	var state = str(data.get("state", ""))
	if state == "done":
		ota_state = "done"
		ota_progress = 100
		_log_ota("Flash complete")
	elif state == "error":
		ota_state = "error"
		_log_ota("OTA error")
	else:
		_log_ota("OTA: %s" % state)


func _send(message: String, ui_msg: String = "", kind: String = "info") -> bool:
	if not udp_ready:
		if ui_msg != "":
			_set_status("UDP not ready", "error")
		return false
	udp.set_dest_address(AppSettings.DONGLE_IP, AppSettings.DONGLE_UDP_PORT)
	var err = udp.put_packet(message.to_utf8_buffer())
	if err == OK:
		if ui_msg != "":
			_set_status(ui_msg, kind)
		return true
	if ui_msg != "":
		_set_status("Send failed: %d" % err, "error")
	return false


## OTA传输状态机 - 每帧调用，按固定间隔发送固件数据块
## 流程: ota_start → 分块发送(ota_chunk) → verify → flash
func _process_ota(now: int) -> void:
	if ota_state != "sending":
		return
	# 控制发送速率，避免网络拥塞
	if now - last_ota_send_msec < AppSettings.OTA_SEND_INTERVAL_MS:
		return
	last_ota_send_msec = now

	# 第一次发送: 先发ota_start通知固件大小和MD5
	if not ota_started:
		_send(Protocol.ota_start(firmware_size, firmware_md5))
		ota_started = true
		return

	# 传输完成: 切换到校验状态
	if ota_offset >= firmware_size:
		ota_state = "verify"
		ota_progress = 100
		_log_ota("Transfer done %.1f KB/s" % ota_speed_kbps)
		return

	# 分块发送: 每次OTA_CHUNK_SIZE字节，Base64编码
	var end = min(ota_offset + AppSettings.OTA_CHUNK_SIZE, firmware_size)
	var chunk = firmware_data.slice(ota_offset, end)
	_send(Protocol.ota_chunk(ota_offset, Marshalls.raw_to_base64(chunk)))
	ota_offset = end

	# 更新进度和速度
	var elapsed = max(0.001, float(now - ota_start_msec) / 1000.0)
	ota_progress = int(float(ota_offset) * 100.0 / float(firmware_size))
	ota_speed_kbps = (float(ota_offset) / 1024.0) / elapsed


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
			_set_status("Firmware loaded")
			return true
	_log_ota("No firmware found in /storage")
	_set_status("No firmware found", "warn")
	return false


func _start_ota_transfer() -> void:
	if firmware_data.is_empty() and not _load_default_firmware():
		return
	ota_state = "sending"
	ota_progress = 0
	ota_offset = 0
	ota_started = false
	ota_start_msec = Time.get_ticks_msec()
	last_ota_send_msec = 0
	_log_ota("Starting transfer")


func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 720, 720), C_BG, true)
	for y in range(0, 720, 24):
		draw_line(Vector2(0, y), Vector2(720, y), Color(C_GRID, 0.22), 1.0)
	for x in range(0, 720, 24):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(C_GRID, 0.12), 1.0)
	draw_circle(Vector2(610, 90), 150, Color(C_ACCENT_2, 0.055))
	draw_circle(Vector2(110, 660), 170, Color(C_ACCENT, 0.045))


func _draw_language_select() -> void:
	_draw_panel(Rect2(78, 54, 564, 528), C_PANEL, C_LINE)
	_draw_text(_t("language_title"), 108, 96, C_TEXT, 24)
	_draw_text(_t("language_subtitle"), 108, 144, C_DIM, 14)
	var labels = [_t("language_zh"), _t("language_en"), _t("language_shutdown")]
	for i in labels.size():
		var rect = Rect2(128, 200 + i * 74, 464, 52)
		draw_rect(rect, C_INPUT, true)
		draw_rect(rect, C_LINE, false, 1.0)
		var is_back = i == 2
		_draw_text(labels[i], rect.position.x, rect.position.y + 15, C_DIM if is_back else C_TEXT, 17, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	var selected_rect = Rect2(128, 200 + selected_language * 74, 464, 52)
	draw_rect(selected_rect, C_WARN if selected_language == 2 else C_ACCENT, false, 2.0)
	draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 6, selected_rect.size.y), C_WARN if selected_language == 2 else C_ACCENT, true)
	_draw_panel(Rect2(78, 610, 564, 48), C_INPUT, C_LINE)
	_draw_text(_t("language_hint"), 78, 626, C_DIM, 14, HORIZONTAL_ALIGNMENT_CENTER, 564)


func _draw_header() -> void:
	_draw_panel(Rect2(14, 12, 692, 64), C_PANEL, C_LINE)
	_draw_text(_t("app_title"), 30, 28, C_TEXT, 20)
	var link = motor.alive or (last_rx_msec > 0 and Time.get_ticks_msec() - last_rx_msec <= 1500)
	_draw_status_chip(Rect2(505, 23, 84, 24), "LINK", link)
	_draw_status_chip(Rect2(598, 23, 84, 24), "UDP", udp_ready)
	_draw_text("%d ms" % AppSettings.HEARTBEAT_INTERVAL_MS, 622, 56, C_DIM, 10)
	_draw_text(_t("header_subtitle") % AppSettings.DEFAULT_NODE_ID, 32, 56, C_TEXT, 10)


func _draw_tabs() -> void:
	var gap = 14.0
	var tab_w = (684.0 - gap * float(TAB_KEYS.size() - 1)) / float(TAB_KEYS.size())
	var x = 18.0
	for i in TAB_KEYS.size():
		var rect = Rect2(x, 88, tab_w, 38)
		var active = i == current_tab
		draw_rect(rect, C_ACCENT if active else C_PANEL_2, true)
		draw_rect(rect, C_ACCENT if active else C_LINE, false, 1.0)
		_draw_text(_tab_name(i), rect.position.x, rect.position.y + 10, C_TEXT, 12, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		x += tab_w + gap


func _draw_monitor_page() -> void:
	_draw_action_rail(Rect2(18, 140, 188, 360), _texts(MONITOR_ITEM_KEYS), int(selected[0]))
	_draw_telemetry_grid(Rect2(224, 140, 478, 190))
	_draw_waveform_panel(Rect2(224, 346, 478, 196))
	_draw_command_matrix(Rect2(18, 516, 188, 88))
	_draw_live_debug(Rect2(224, 558, 478, 46))


func _draw_config_page() -> void:
	_draw_panel(Rect2(18, 140, 684, 386), C_PANEL, C_LINE)
	_draw_text(_t("config_header"), 36, 158, C_ACCENT, 13)
	var y = 194.0
	for i in CONFIG_ITEMS.size():
		var item: Array = CONFIG_ITEMS[i]
		var row_rect = Rect2(34, y, 652, 32)
		draw_rect(row_rect, C_INPUT, true)
		draw_rect(row_rect, C_LINE, false, 1.0)
		var tc = C_TEXT
		var dc = C_DIM
		_draw_text(_t(item[0]), 46, y + 9, tc, 12)
		_draw_text("0x%s:%d" % [_hex(item[1]), item[2]], 288, y + 9, dc, 12)
		_draw_text(_t(item[3]), 408, y + 9, dc, 12)
		y += 36
	var selected_rect = Rect2(34, 194 + int(selected[1]) * 36, 652, 32)
	draw_rect(selected_rect, C_ACCENT, false, 2.0)
	draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y), C_ACCENT, true)
	_draw_panel(Rect2(18, 542, 684, 62), C_INPUT, C_LINE)
	_draw_text(_t("sdo_result"), 36, 562, C_TEXT, 11)
	_draw_text(result_msg if result_msg != "" else _t("no_sdo"), 36, 586, C_TEXT, 11)


func _draw_ota_page() -> void:
	_draw_panel(Rect2(18, 140, 684, 120), C_PANEL, C_LINE)
	var fw = firmware_name if firmware_name != "" else _t("no_firmware")
	var meta = _t("copy_firmware")
	if firmware_size > 0:
		meta = "Size %.1f KB  MD5 %s..." % [float(firmware_size) / 1024.0, firmware_md5.substr(0, 16)]
	_draw_text(_t("firmware_update") % [fw, meta], 36, 160, C_ACCENT, 13)

	_draw_action_rail(Rect2(18, 284, 260, 226), _texts(OTA_ITEM_KEYS), int(selected[2]))
	_draw_panel(Rect2(300, 284, 402, 226), C_PANEL, C_LINE)
	_draw_text(_t("transfer_state") % ota_state.to_upper(), 318, 306, C_TEXT, 11)
	_draw_progress_bar(Rect2(318, 382, 360, 30), ota_progress, "%d%%  %.1f KB/s" % [ota_progress, ota_speed_kbps])
	_draw_text(_t("target_dongle"), 318, 446, C_TEXT, 11)

	_draw_panel(Rect2(18, 548, 684, 92), C_INPUT, C_LINE)
	var log_head = _t("ota_log")
	if not ota_log.is_empty():
		log_head = _t("ota_log_line") % ota_log.back()
	_draw_text(log_head, 36, 568, C_TEXT, 11)


func _draw_can_page() -> void:
	_draw_panel(Rect2(18, 140, 684, 96), C_PANEL, C_LINE)
	_draw_text(_t("can_header"), 36, 158, C_ACCENT, 12)
	_draw_text(_t("can_filter_label"), 36, 194, C_DIM, 13)
	var input_rect = Rect2(112, 188, 474, 30)
	draw_rect(input_rect, C_INPUT, true)
	draw_rect(input_rect, C_LINE, false, 1.0)
	_draw_text(can_filter if can_filter != "" else _t("can_all"), input_rect.position.x + 10, input_rect.position.y + 7, C_TEXT if can_filter != "" else C_DIM_2, 12)
	if can_paused:
		_draw_text(_t("can_paused"), 604, 194, C_WARN, 12)

	_draw_action_rail(Rect2(18, 254, 188, 226), _can_action_labels(), int(selected[3]))
	_draw_panel(Rect2(224, 254, 478, 386), C_PANEL, C_LINE)
	_draw_text(_t("can_log"), 242, 274, C_DIM, 13)
	var rows = _filtered_can_rows()
	if rows.is_empty():
		_draw_text(_t("can_empty"), 242, 314, C_DIM, 13)
		return
	var start = max(0, rows.size() - 16)
	var y = 310.0
	for i in range(start, rows.size()):
		var row: Dictionary = rows[i]
		_draw_text(str(row.get("line", "")), 242, y, C_TEXT, 10)
		y += 20


func _draw_virtual_keyboard() -> void:
	var rect = Rect2(28, 338, 664, 318)
	draw_rect(rect, Color(C_INPUT, 0.98), true)
	draw_rect(rect, C_ACCENT, false, 2.0)
	_draw_text(_t("keyboard_title"), rect.position.x + 18, rect.position.y + 12, C_ACCENT, 13)
	_draw_text(_t("keyboard_hint"), rect.position.x + 210, rect.position.y + 12, C_DIM, 11)
	_draw_text(_t("can_filter_label"), rect.position.x + 18, rect.position.y + 44, C_DIM, 12)
	_draw_text(can_filter, rect.position.x + 88, rect.position.y + 44, C_TEXT, 12)

	var key_h = 30.0
	var gap = 6.0
	var y = rect.position.y + 82
	for row_index in KEYBOARD_ROWS.size():
		var row: Array = KEYBOARD_ROWS[row_index]
		var key_w = 56.0
		if row_index == 3:
			key_w = 62.0
		elif row_index == 4:
			key_w = 58.0
		var row_w = float(row.size()) * key_w + float(row.size() - 1) * gap
		var x = rect.position.x + (rect.size.x - row_w) * 0.5
		for col_index in row.size():
			var r = Rect2(x + col_index * (key_w + gap), y, key_w, key_h)
			draw_rect(r, C_PANEL, true)
			draw_rect(r, C_LINE, false, 1.0)
			var label = _keyboard_key_label(row_index, col_index)
			_draw_text(label, r.position.x, r.position.y + 7, C_TEXT, 11, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += key_h + gap

	var selected_row: Array = KEYBOARD_ROWS[keyboard_row]
	var selected_key_w = 56.0
	if keyboard_row == 3:
		selected_key_w = 62.0
	elif keyboard_row == 4:
		selected_key_w = 58.0
	var selected_row_w = float(selected_row.size()) * selected_key_w + float(selected_row.size() - 1) * gap
	var selected_x = rect.position.x + (rect.size.x - selected_row_w) * 0.5 + keyboard_col * (selected_key_w + gap)
	var selected_y = rect.position.y + 82 + keyboard_row * (key_h + gap)
	var selected_rect = Rect2(selected_x, selected_y, selected_key_w, key_h)
	draw_rect(selected_rect, C_ACCENT, false, 2.0)
	draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y), C_ACCENT, true)


func _draw_action_rail(rect: Rect2, items: Array, selected_index: int) -> void:
	_draw_panel(rect, C_PANEL, C_LINE)
	_draw_text(_t("commands"), rect.position.x + 18, rect.position.y + 18, C_DIM, 14)
	var y = rect.position.y + 48
	for i in items.size():
		var is_sel = i == selected_index
		var r = Rect2(rect.position.x + 14, y, rect.size.x - 28, 38)
		draw_rect(r, C_INPUT, true)
		draw_rect(r, C_LINE, false, 1.0)
		_draw_text(items[i], r.position.x, r.position.y + 10, C_TEXT, 15, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += 46
	var selected_rect = Rect2(rect.position.x + 14, rect.position.y + 48 + selected_index * 46, rect.size.x - 28, 38)
	draw_rect(selected_rect, C_ACCENT, false, 2.0)
	draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y), C_ACCENT, true)


func _draw_telemetry_grid(rect: Rect2) -> void:
	_draw_panel(rect, C_PANEL, C_LINE)
	_draw_text(_t("telemetry"), rect.position.x + 18, rect.position.y + 18, C_DIM, 14)
	var cards = [
		[_t("metric_current"), "%.2f" % motor.current, "A", C_ACCENT],
		[_t("metric_voltage"), "%.1f" % motor.voltage, "V", C_ACCENT_2],
		[_t("metric_speed"), "%d" % motor.speed, "rpm", C_WARN],
		[_t("metric_position"), "%.1f" % motor.position, "deg", C_TEXT],
		[_t("metric_torque"), "%.2f" % motor.torque, "Nm", C_GREEN],
		[_t("metric_status"), motor.get_status_text(), "", C_RED if motor.is_fault() else C_GREEN],
	]
	var idx = 0
	for row in 2:
		for col in 3:
			var card = cards[idx]
			var x = rect.position.x + 16 + col * 150
			var y = rect.position.y + 46 + row * 62
			_draw_metric_card(Rect2(x, y, 138, 52), card[0], card[1], card[2], card[3])
			idx += 1


func _draw_metric_card(rect: Rect2, label: String, value: String, unit: String, color: Color) -> void:
	draw_rect(rect, C_INPUT, true)
	draw_rect(rect, Color(color, 0.75), false, 1.0)
	_draw_text(label, rect.position.x + 8, rect.position.y + 7, C_DIM, 12)
	var display_value = value if unit == "" else "%s %s" % [value, unit]
	_draw_text(display_value, rect.position.x + 8, rect.position.y + 27, color, 12)


func _draw_waveform_panel(rect: Rect2) -> void:
	_draw_panel(rect, C_PANEL, C_LINE)
	_draw_text(_t("waveform"), rect.position.x + 18, rect.position.y + 18, C_DIM, 14)
	var plot = Rect2(rect.position.x + 18, rect.position.y + 46, rect.size.x - 36, rect.size.y - 66)
	draw_rect(plot, C_INPUT, true)
	for i in range(1, 5):
		var gy = plot.position.y + plot.size.y * i / 5.0
		draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), Color(C_GRID, 0.55), 1.0)
	for i in range(1, 7):
		var gx = plot.position.x + plot.size.x * i / 7.0
		draw_line(Vector2(gx, plot.position.y), Vector2(gx, plot.end.y), Color(C_GRID, 0.45), 1.0)
	draw_rect(plot, C_LINE, false, 1.0)

	var vals = motor.current_history
	var n = min(vals.size(), 96)
	if n < 2:
		_draw_text(_t("waiting_packets"), plot.position.x, plot.position.y + plot.size.y * 0.5 - 8, C_DIM, 15, HORIZONTAL_ALIGNMENT_CENTER, plot.size.x)
		return
	var start = vals.size() - n
	var vmin = vals[start]
	var vmax = vals[start]
	for i in range(start, vals.size()):
		vmin = min(vmin, vals[i])
		vmax = max(vmax, vals[i])
	var vrange = vmax - vmin
	if absf(vrange) < 0.001:
		vrange = 1.0
	var points = PackedVector2Array()
	for i in n:
		var v: float = vals[start + i]
		var px = plot.position.x + float(i) * plot.size.x / float(max(n - 1, 1))
		var py = plot.position.y + plot.size.y - ((v - vmin) / vrange * plot.size.y)
		points.append(Vector2(px, py))
	draw_polyline(points, C_ACCENT, 2.0)


func _draw_command_matrix(rect: Rect2) -> void:
	_draw_panel(rect, C_PANEL, C_LINE)
	_draw_text(_t("hotkeys"), rect.position.x + 14, rect.position.y + 16, C_DIM, 13)
	_draw_text("X %s" % _t("cmd_enable"), rect.position.x + 14, rect.position.y + 42, C_ACCENT, 13)
	_draw_text("Y %s" % _t("cmd_disable"), rect.position.x + 96, rect.position.y + 42, C_WARN, 13)
	_draw_text("L1/R1 JOG", rect.position.x + 14, rect.position.y + 66, C_TEXT, 13)
	_draw_text("L2 %s" % _t("cmd_estop"), rect.position.x + 96, rect.position.y + 66, C_RED, 13)


func _draw_live_debug(rect: Rect2) -> void:
	_draw_panel(rect, C_INPUT, C_LINE)
	var input_state = "RAW /dev/input/js0" if raw_input_ok else "GODOT FALLBACK"
	_draw_text(_t("input"), rect.position.x + 14, rect.position.y + 16, C_DIM, 13)
	_draw_text(input_state, rect.position.x + 76, rect.position.y + 16, C_ACCENT if raw_input_ok else C_WARN, 13)
	_draw_text(_t("last"), rect.position.x + 270, rect.position.y + 16, C_DIM, 13)
	_draw_text(last_input_label, rect.position.x + 314, rect.position.y + 16, C_TEXT, 13)


func _draw_status_overlay() -> void:
	if status_msg == "" or Time.get_ticks_msec() > status_until_msec:
		return
	var color = C_ACCENT
	if status_kind == "warn":
		color = C_WARN
	elif status_kind == "error":
		color = C_RED
	var rect = Rect2(110, 622, 500, 42)
	draw_rect(rect, Color(C_INPUT, 0.96), true)
	draw_rect(rect, color, false, 2.0)
	_draw_text(status_msg, rect.position.x, rect.position.y + 13, color, 14, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_footer() -> void:
	_draw_panel(Rect2(14, 670, 692, 36), C_PANEL, C_LINE)
	_draw_text(_t("footer"), 24, 681, C_DIM, 12)


func _draw_status_chip(rect: Rect2, label: String, ok: bool) -> void:
	var color = C_GREEN if ok else C_RED
	draw_rect(rect, Color(color, 0.18), true)
	draw_rect(rect, color, false, 1.0)
	_draw_text(label, rect.position.x, rect.position.y + 7, color, 10, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_panel(rect: Rect2, fill: Color, border: Color) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, 1.0)
	draw_line(rect.position, rect.position + Vector2(18, 0), C_ACCENT, 2.0)
	draw_line(rect.position, rect.position + Vector2(0, 18), C_ACCENT, 2.0)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - 18, rect.position.y), C_ACCENT_2, 2.0)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + 18), C_ACCENT_2, 2.0)


func _draw_progress_bar(rect: Rect2, progress: int, label: String) -> void:
	draw_rect(rect, C_INPUT, true)
	var bar_w = (rect.size.x - 4) * clamp(progress, 0, 100) / 100.0
	if bar_w > 0:
		draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, bar_w, rect.size.y - 4), C_ACCENT, true)
	draw_rect(rect, C_LINE, false, 1.0)
	_draw_text(label, rect.position.x, rect.position.y + 9, C_TEXT, 11, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_text(text: String, x: float, y: float, color: Color, font_size: int = 16, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if font == null:
		return
	draw_string(font, Vector2(x, y + font_size), text, align, width, font_size, color)


func _t(key: String) -> String:
	return UiText.text(ui_lang, key)


func _tab_name(index: int) -> String:
	return _t(TAB_KEYS[index])


func _texts(keys: Array) -> Array[String]:
	var values: Array[String] = []
	for key in keys:
		values.append(_t(str(key)))
	return values


func _can_action_labels() -> Array[String]:
	return [_t("can_filter"), _t("can_reset"), _t("can_run") if can_paused else _t("can_pause")]


func _filtered_can_rows() -> Array[Dictionary]:
	if can_filter.strip_edges() == "":
		return can_rows
	var needle = can_filter.to_lower()
	var rows: Array[Dictionary] = []
	for row in can_rows:
		var line = str(row.get("line", "")).to_lower()
		var raw = str(row.get("raw", "")).to_lower()
		if line.contains(needle) or raw.contains(needle):
			rows.append(row)
	return rows


func _keyboard_key_value(row_index: int, col_index: int) -> String:
	var key = str(KEYBOARD_ROWS[row_index][col_index])
	if key.length() == 1 and "ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(key) and keyboard_lowercase:
		return key.to_lower()
	return key


func _keyboard_key_label(row_index: int, col_index: int) -> String:
	var key = _keyboard_key_value(row_index, col_index)
	if key == "SHIFT":
		return "abc" if not keyboard_lowercase else "ABC"
	return key


func _set_status(message: String, kind: String = "info") -> void:
	status_msg = message
	status_kind = kind
	status_until_msec = Time.get_ticks_msec() + (2600 if kind == "error" else 1800)


func _log_ota(message: String) -> void:
	var ts = Time.get_time_string_from_system()
	ota_log.append("[%s] %s" % [ts, message])
	while ota_log.size() > 4:
		ota_log.pop_front()


func _state_color() -> Color:
	if ota_state == "error":
		return C_RED
	if ota_state == "sending" or ota_state == "verify":
		return C_WARN
	if ota_state == "done" or ota_state == "ready":
		return C_ACCENT
	return C_DIM


func _hex(value: int, width: int = 4) -> String:
	return ("%X" % value).pad_zeros(width)


func _i16_le(lo: int, hi: int) -> int:
	var v = (hi << 8) | lo
	if v >= 32768:
		v -= 65536
	return v
