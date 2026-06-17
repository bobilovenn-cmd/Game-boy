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
const UdpClient = preload("res://scripts/protocol/udp_client.gd")  # UDP收发
const CanLogFormatter = preload("res://scripts/protocol/can_log_formatter.gd")  # CAN日志格式化
const MotorController = preload("res://scripts/controllers/motor_controller.gd")  # 电机控制
const UploadModeController = preload("res://scripts/controllers/upload_mode_controller.gd")  # 固件上传模式
const NodeSelectorController = preload("res://scripts/controllers/node_selector_controller.gd")  # 节点选择
const NumericInputController = preload("res://scripts/controllers/numeric_input_controller.gd")  # 数字输入
const MotorDataScript = preload("res://scripts/motor_data.gd")  # 电机数据模型
const CanLogState = preload("res://scripts/models/can_log_state.gd")  # CAN日志状态
const OtaState = preload("res://scripts/models/ota_state.gd")  # OTA状态
const StatusState = preload("res://scripts/models/status_state.gd")  # 状态提示
const UiText = preload("res://scripts/ui_text.gd")          # 国际化文本
const UiTheme = preload("res://scripts/theme/ui_theme.gd")   # UI主题色
const UiConfig = preload("res://scripts/app/ui_config.gd")   # UI页面配置
const InputMapper = preload("res://scripts/input/input_mapper.gd")  # 按键映射
const RawInputReader = preload("res://scripts/input/raw_input_reader.gd")  # RGB30原始输入读取
const LanguageScreen = preload("res://scripts/screens/language_screen.gd")  # 语言选择页
const NodeSelectScreen = preload("res://scripts/screens/node_select_screen.gd")  # 节点选择页

## 主题色常量 - 深色科技风格配色方案
const C_BG = UiTheme.C_BG
const C_BG_2 = UiTheme.C_BG_2
const C_PANEL = UiTheme.C_PANEL
const C_PANEL_2 = UiTheme.C_PANEL_2
const C_INPUT = UiTheme.C_INPUT
const C_LINE = UiTheme.C_LINE
const C_GRID = UiTheme.C_GRID
const C_TEXT = UiTheme.C_TEXT
const C_DIM = UiTheme.C_DIM
const C_DIM_2 = UiTheme.C_DIM_2
const C_ACCENT = UiTheme.C_ACCENT
const C_ACCENT_2 = UiTheme.C_ACCENT_2
const C_WARN = UiTheme.C_WARN
const C_RED = UiTheme.C_RED
const C_GREEN = UiTheme.C_GREEN
const C_BLACK = UiTheme.C_BLACK

## UI配置常量
const LANGUAGE_OPTIONS = UiConfig.LANGUAGE_OPTIONS  # 支持的语言列表
const TAB_KEYS = UiConfig.TAB_KEYS                  # 页面标签
const MONITOR_ITEM_KEYS = UiConfig.MONITOR_ITEM_KEYS
const CONFIG_ITEMS = UiConfig.CONFIG_ITEMS
const OTA_ITEM_KEYS = UiConfig.OTA_ITEM_KEYS
const CAN_ITEM_KEYS = UiConfig.CAN_ITEM_KEYS
const NODE_KEY_ROWS = UiConfig.NODE_KEY_ROWS
const KEYBOARD_ROWS = UiConfig.KEYBOARD_ROWS
const NUMERIC_KEY_ROWS = UiConfig.NUMERIC_KEY_ROWS

## 核心对象
var font: Font                              # 当前字体
var udp_client = UdpClient.new()            # UDP通信对象
var motor = MotorDataScript.new()           # 电机数据实例
var motor_controller = MotorController.new() # 电机命令控制器
var upload_mode = UploadModeController.new() # 固件上传模式
var node_selector = NodeSelectorController.new() # 节点选择控制器
var numeric_input = NumericInputController.new() # 数字输入控制器
var can_log = CanLogState.new()             # CAN日志状态
var ota = OtaState.new()                    # OTA升级状态
var status = StatusState.new()              # 状态提示
var raw_input = RawInputReader.new()        # /dev/input/js0读取器

## 语言选择状态
var language_selected = false               # 是否已选择语言
var selected_language = 0                   # 当前选中的语言索引
var ui_lang = UiText.LANG_ZH               # 当前界面语言

## 节点选择状态
var node_selected = false                   # 是否已选择电机节点
var selected_node_id = AppSettings.DEFAULT_NODE_ID  # 当前控制节点

## 页面导航状态
var current_tab = 0                         # 当前页面(0=监控, 1=配置, 2=OTA, 3=CAN日志)
var selected = [0, 0, 0, 0]                 # 各页面当前选中项索引

var result_msg = ""                         # SDO读取结果

## UDP连接状态
var last_heartbeat_msec = 0                 # 上次心跳时间
var last_rx_msec = 0                        # 上次收到数据时间
var udp_ready = false                       # UDP是否就绪

## CAN日志输入状态
var keyboard_open = false                   # 是否显示虚拟键盘
var keyboard_row = 0                        # 虚拟键盘选中行
var keyboard_col = 0                        # 虚拟键盘选中列
var keyboard_lowercase = false              # 虚拟键盘是否小写输入

## 手柄输入状态
var last_input_label = "none"               # 最近按键调试标签
var last_raw_button = -1                    # 最近原始按键ID
var godot_axis_active = {}                  # fallback 轴输入去抖状态


## 应用初始化
func _ready() -> void:
	motor_controller.configure_node(selected_node_id)

	# 加载打包的CJK字体(支持中英文)，失败则回退到系统字体
	var cjk_font = ResourceLoader.load("res://fonts/AGV_CJK.ttf", "", ResourceLoader.CACHE_MODE_REUSE)
	if cjk_font:
		font = cjk_font
	else:
		font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font

	# 绑定本地UDP端口，设置目标地址(ESP32网关)
	udp_client.configure(AppSettings.LOCAL_UDP_PORT, AppSettings.DONGLE_IP, AppSettings.DONGLE_UDP_PORT)
	var err = udp_client.bind_any()
	if err == OK:
		udp_ready = true
		_set_status("UDP ready 0.0.0.0:%d -> %s:%d" % [AppSettings.LOCAL_UDP_PORT, AppSettings.DONGLE_IP, AppSettings.DONGLE_UDP_PORT])
	else:
		_set_status("UDP bind failed: %d" % err, "error")

	# 启动手柄输入线程
	var raw_err = raw_input.start()
	if raw_err != OK:
		_set_status("Raw input thread failed; using Godot joypad fallback", "warn")
	_log_ota("Godot terminal ready")
	set_process(true)


func _exit_tree() -> void:
	raw_input.stop()


## 主循环 - 每帧执行
func _process(_delta: float) -> void:
	var now = Time.get_ticks_msec()
	# 处理手柄输入队列
	_drain_raw_input()
	# 语言未选择时只渲染语言选择界面
	if not language_selected:
		queue_redraw()
		return
	if not node_selected:
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
	elif raw_input.fallback_enabled and event is InputEventJoypadButton:
		_handle_godot_joy_button(event.button_index, event.pressed)
	elif raw_input.fallback_enabled and event is InputEventJoypadMotion:
		_handle_godot_joy_motion(event.axis, event.axis_value)


## 渲染入口 - 根据当前状态绘制对应界面
func _draw() -> void:
	_draw_background()           # 绘制网格背景
	if not language_selected:
		_draw_language_select()  # 语言选择界面
		_draw_status_overlay()
		return
	if not node_selected:
		_draw_node_select()      # 节点选择界面
		_draw_status_overlay()
		return
	if upload_mode.open:
		_draw_upload_mode_page() # 固件上传模式独立页面
		_draw_status_overlay()
		return
	if keyboard_open:
		_draw_filter_input_page() # CAN过滤字段独立输入界面
		_draw_status_overlay()
		return
	if numeric_input.open:
		_draw_numeric_input_page()
		_draw_status_overlay()
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
	_draw_footer()               # 底部快捷键提示栏


func _drain_raw_input() -> void:
	for raw in raw_input.drain_events():
		if raw >= RawInputReader.RELEASE_OFFSET:
			var release_id = raw - RawInputReader.RELEASE_OFFSET
			last_raw_button = release_id
			last_input_label = "raw %d -> jog_stop" % release_id
			_handle_action("jog_stop")
			continue
		last_raw_button = raw
		var action = InputMapper.raw_action(raw)
		last_input_label = "raw %d -> %s" % [raw, action if action != "" else "unmapped"]
		if action != "":
			_handle_action(action)
		else:
			_set_status("Unmapped raw button %d" % raw, "warn")


func _handle_godot_joy_button(button_index: int, pressed: bool) -> void:
	var action := InputMapper.godot_button_action(button_index)
	if action == "":
		return
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
	if not node_selected:
		_handle_node_action(action)
		return
	if upload_mode.open:
		_handle_upload_mode_action(action)
		return
	if keyboard_open:
		_handle_keyboard_action(action)
		return
	if numeric_input.open:
		_handle_numeric_input_action(action)
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
			_send(motor_controller.jog_stop(), "Jog stopped")
		"enable":
			_send(motor_controller.enable(), "Enable sent")
		"disable":
			_send(motor_controller.disable(), "Disable sent")
		"estop":
			_send(motor_controller.estop(), "E-STOP sent", "error")
		"jog_cw":
			_send(motor_controller.jog_cw(), "Jog CW %d" % motor_controller.target_speed)
		"jog_ccw":
			_send(motor_controller.jog_ccw(), "Jog CCW %d" % motor_controller.target_speed)
		"jog_stop":
			_send(motor_controller.jog_stop(), "Jog stopped")
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
				node_selected = false
				node_selector.reset()
				ui_lang = LANGUAGE_OPTIONS[selected_language]
				_set_status("LANGUAGE %s" % ui_lang.to_upper())


func _handle_node_action(action: String) -> void:
	var result = node_selector.handle_action(action, NODE_KEY_ROWS, _t("node_error_empty"), _t("node_error_range"))
	match str(result.get("event", "")):
		"back":
			_return_to_language_select()
		"selected":
			_confirm_node_input(int(result.get("node", AppSettings.DEFAULT_NODE_ID)))


func _confirm_node_input(value: int) -> void:
	selected_node_id = value
	motor_controller.configure_node(selected_node_id)
	node_selected = true
	current_tab = 0
	selected = [0, 0, 0, 0]
	motor = MotorDataScript.new()
	last_rx_msec = 0
	result_msg = ""
	node_selector.error_msg = ""
	can_log.clear()
	_set_status(_t("node_selected_status") % selected_node_id)


func _return_to_language_select() -> void:
	var idx = LANGUAGE_OPTIONS.find(ui_lang)
	selected_language = idx if idx >= 0 else 0
	language_selected = false
	node_selected = false
	node_selector.reset()
	status.clear()


func _confirm_current_selection() -> void:
	if current_tab == 0:
		match int(selected[0]):
			0:
				_send(motor_controller.enable(), "Enable sent")
			1:
				_send(motor_controller.disable(), "Disable sent")
			2:
				_send(motor_controller.estop(), "E-STOP sent", "error")
			3:
				_send(motor_controller.jog_cw(), "Jog CW %d" % motor_controller.target_speed)
			4:
				_send(motor_controller.jog_ccw(), "Jog CCW %d" % motor_controller.target_speed)
			5:
				_open_numeric_input("position")
			6:
				_open_numeric_input("speed")
	elif current_tab == 1:
		var item: Array = CONFIG_ITEMS[int(selected[1])]
		var name_key: String = item[0]
		var index: int = item[1]
		var sub: int = item[2]
		if name_key == "cfg_save_eeprom":
			_send(Protocol.sdo_write(selected_node_id, index, sub, 0x65766173), "Save EEPROM")
		else:
			result_msg = "Reading 0x%s..." % _hex(index)
			_send(Protocol.sdo_read(selected_node_id, index, sub), result_msg)
	elif current_tab == 2:
		match int(selected[2]):
			0:
				_open_upload_mode()
			1:
				_load_default_firmware()
			2:
				_start_ota_transfer()
			3:
				_send(Protocol.ota_verify(), "Verify requested")
				_log_ota("Requesting MD5 verify")
			4:
				_send(Protocol.ota_flash(selected_node_id), "Flash command sent")
				_log_ota("Flash command sent")
	elif current_tab == 3:
		match int(selected[3]):
			0:
				keyboard_open = true
				keyboard_row = 1
				keyboard_col = 0
			1:
				can_log.clear()
				_set_status(_t("can_reset_status"))
			2:
				can_log.paused = not can_log.paused
				_set_status(_t("can_paused") if can_log.paused else _t("can_run_status"))


func _open_upload_mode() -> void:
	upload_mode.open_upload(AppSettings.UPLOAD_MODE_SCRIPT, _t("upload_starting"), _t("upload_script_missing"), _t("upload_ready"))
	_set_status(_t("upload_starting"))


func _close_upload_mode() -> void:
	upload_mode.close_upload(AppSettings.UPLOAD_MODE_SCRIPT)
	if FileAccess.file_exists("/storage/firmware.bin"):
		_load_default_firmware()
	_set_status(_t("upload_restore_status"))


func _handle_upload_mode_action(action: String) -> void:
	match action:
		"confirm", "back", "language_select":
			_close_upload_mode()


func _open_numeric_input(kind: String) -> void:
	numeric_input.start(kind, motor_controller.target_speed)


func _handle_numeric_input_action(action: String) -> void:
	var result = numeric_input.handle_action(action, NUMERIC_KEY_ROWS)
	match str(result.get("event", "")):
		"language_select":
			_return_to_language_select()
		"error":
			if str(result.get("kind", "")) == "speed_range":
				_set_status(_t("motion_speed_range"), "error")
			else:
				_set_status(_t("motion_input_empty"), "warn")
		"selected":
			_confirm_numeric_input(str(result.get("kind", "")), int(result.get("value", 0)))


func _confirm_numeric_input(kind: String, value: int) -> void:
	if kind == "speed":
		if value < 1 or value > 300000:
			_set_status(_t("motion_speed_range"), "error")
			return
		_send(motor_controller.set_target_speed(value), _t("motion_speed_sent") % motor_controller.target_speed)
	else:
		_send(motor_controller.move_position(value), _t("motion_position_sent"))


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
			if can_log.filter.length() < 32:
				can_log.filter += " "
		"DEL":
			if can_log.filter.length() > 0:
				can_log.filter = can_log.filter.substr(0, can_log.filter.length() - 1)
		"CLR":
			can_log.filter = ""
		"OK":
			keyboard_open = false
			_set_status(_t("can_filter_label") + ": " + (can_log.filter if can_log.filter != "" else _t("can_all")))
		"SHIFT":
			keyboard_lowercase = not keyboard_lowercase
		_:
			if can_log.filter.length() < 32:
				can_log.filter += key


## 轮询UDP接收缓冲区 - 处理所有待处理的数据包
func _poll_udp() -> void:
	if not udp_ready:
		return
	for raw in udp_client.poll_text_packets():
		var data = Protocol.parse(raw)  # 解析JSON消息
		_record_can_row(raw, data)
		_handle_message(data)           # 分发处理


func _record_can_row(raw: String, data: Dictionary) -> void:
	if can_log.paused:
		return
	if not CanLogFormatter.should_record(data):
		return
	can_log.append_line(CanLogFormatter.format_line(raw, data), raw)


## 消息分发处理 - 根据cmd字段路由到对应处理器
func _handle_message(data: Dictionary) -> void:
	last_rx_msec = Time.get_ticks_msec()
	var cmd = str(data.get("cmd", ""))
	var payload = Protocol.payload(data)
	if payload != data:
		payload["cmd"] = cmd

	match cmd:
		"motor_status":        # 电机状态上报(周期性)
			if not Protocol.matches_node(payload, selected_node_id):
				return
			motor.update_from_dict(payload)
			motor.alive = true
		"sdo_read_result":     # SDO读取结果
			if not Protocol.matches_node(payload, selected_node_id):
				return
			_handle_sdo_result(payload)
		"ota_status":          # OTA升级状态
			_handle_ota_status(payload)
		"ack":                 # 通用应答
			if not Protocol.matches_node(payload, selected_node_id):
				return
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
	ota.apply_status(state)


func _send(message: String, ui_msg: String = "", kind: String = "info") -> bool:
	if not udp_ready:
		if ui_msg != "":
			_set_status("UDP not ready", "error")
		return false
	var err = udp_client.send_text(message)
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
	if ota.state != "sending":
		return
	# 控制发送速率，避免网络拥塞
	if now - ota.last_send_msec < AppSettings.OTA_SEND_INTERVAL_MS:
		return
	ota.last_send_msec = now

	# 第一次发送: 先发ota_start通知固件大小和MD5
	if not ota.started:
		_send(Protocol.ota_start(ota.firmware_size, ota.firmware_md5))
		ota.started = true
		return

	# 传输完成: 切换到校验状态
	if ota.offset >= ota.firmware_size:
		ota.mark_transfer_done()
		return

	# 分块发送: 每次OTA_CHUNK_SIZE字节，Base64编码
	var end = min(ota.offset + AppSettings.OTA_CHUNK_SIZE, ota.firmware_size)
	var chunk = ota.firmware_data.slice(ota.offset, end)
	_send(Protocol.ota_chunk(ota.offset, Marshalls.raw_to_base64(chunk)))
	ota.offset = end

	# 更新进度和速度
	var elapsed = max(0.001, float(now - ota.start_msec) / 1000.0)
	ota.progress = int(float(ota.offset) * 100.0 / float(ota.firmware_size))
	ota.speed_kbps = (float(ota.offset) / 1024.0) / elapsed


func _load_default_firmware() -> bool:
	if ota.load_from_paths(AppSettings.FIRMWARE_PATHS):
		_set_status("Firmware loaded")
		return true
	_set_status("No firmware found", "warn")
	return false


func _start_ota_transfer() -> void:
	if ota.firmware_data.is_empty() and not _load_default_firmware():
		return
	ota.start_transfer(Time.get_ticks_msec())


func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 720, 720), C_BG, true)
	for y in range(0, 720, 24):
		draw_line(Vector2(0, y), Vector2(720, y), Color(C_GRID, 0.22), 1.0)
	for x in range(0, 720, 24):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(C_GRID, 0.12), 1.0)
	draw_circle(Vector2(610, 90), 150, Color(C_ACCENT_2, 0.055))
	draw_circle(Vector2(110, 660), 170, Color(C_ACCENT, 0.045))


func _draw_language_select() -> void:
	LanguageScreen.draw(self, font, Callable(self, "_t"), selected_language)


func _draw_node_select() -> void:
	NodeSelectScreen.draw(self, font, Callable(self, "_t"), NODE_KEY_ROWS, node_selector)


func _draw_header() -> void:
	_draw_panel(Rect2(14, 12, 692, 64), C_PANEL, C_LINE)
	_draw_text(_t("app_title"), 30, 28, C_TEXT, 20)
	var link = motor.alive or (last_rx_msec > 0 and Time.get_ticks_msec() - last_rx_msec <= 1500)
	_draw_status_chip(Rect2(505, 23, 84, 24), "LINK", link)
	_draw_status_chip(Rect2(598, 23, 84, 24), "UDP", udp_ready)
	_draw_text("%d ms" % AppSettings.HEARTBEAT_INTERVAL_MS, 622, 56, C_DIM, 10)
	_draw_text(_t("header_subtitle") % selected_node_id, 32, 56, C_TEXT, 10)


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
	var fw = ota.firmware_name if ota.firmware_name != "" else _t("no_firmware")
	var meta = _t("copy_firmware")
	if ota.firmware_size > 0:
		meta = "Size %.1f KB  MD5 %s..." % [float(ota.firmware_size) / 1024.0, ota.firmware_md5.substr(0, 16)]
	_draw_text(_t("firmware_update") % [fw, meta], 36, 154, C_ACCENT, 12)
	var upload_rect = Rect2(36, 206, 650, 36)
	draw_rect(upload_rect, C_INPUT, true)
	draw_rect(upload_rect, C_LINE, false, 1.0)
	_draw_text(_t("ota_upload_panel"), upload_rect.position.x + 12, upload_rect.position.y + 9, C_TEXT, 13)
	_draw_text(_t("ota_upload_hint"), upload_rect.position.x + 338, upload_rect.position.y + 9, C_DIM, 11)
	if int(selected[2]) == 0:
		draw_rect(upload_rect, C_ACCENT, false, 2.0)
		draw_rect(Rect2(upload_rect.position.x, upload_rect.position.y, 5, upload_rect.size.y), C_ACCENT, true)

	var ota_rail_selection = int(selected[2]) - 1
	_draw_action_rail(Rect2(18, 284, 260, 226), _texts(OTA_ITEM_KEYS.slice(1, 5)), ota_rail_selection)
	_draw_panel(Rect2(300, 284, 402, 226), C_PANEL, C_LINE)
	_draw_text(_t("transfer_state") % ota.state.to_upper(), 318, 306, C_TEXT, 11)
	_draw_progress_bar(Rect2(318, 382, 360, 30), ota.progress, "%d%%  %.1f KB/s" % [ota.progress, ota.speed_kbps])
	_draw_text(_t("target_dongle"), 318, 446, C_TEXT, 11)

	_draw_panel(Rect2(18, 548, 684, 92), C_INPUT, C_LINE)
	var log_head = _t("ota_log")
	if not ota.log.is_empty():
		log_head = _t("ota_log_line") % ota.log.back()
	_draw_text(log_head, 36, 568, C_TEXT, 11)


func _draw_can_page() -> void:
	_draw_panel(Rect2(18, 140, 684, 108), C_PANEL, C_LINE)
	_draw_text(_t("can_header"), 36, 158, C_ACCENT, 13)
	_draw_text(_t("can_filter_label"), 36, 194, C_DIM, 13)
	var input_rect = Rect2(112, 188, 474, 30)
	draw_rect(input_rect, C_INPUT, true)
	draw_rect(input_rect, C_LINE, false, 1.0)
	_draw_text(can_log.filter if can_log.filter != "" else _t("can_all"), input_rect.position.x + 10, input_rect.position.y + 7, C_TEXT if can_log.filter != "" else C_DIM_2, 12)
	if can_log.paused:
		_draw_text(_t("can_paused"), 604, 194, C_WARN, 12)
	var visible_count = _filtered_can_rows().size()
	_draw_text("RX %d/%d" % [visible_count, can_log.rows.size()], 580, 158, C_ACCENT, 13)
	var last_line = can_log.last_line if can_log.last_line != "" else "WAIT UDP PACKETS"
	_draw_text(last_line, 36, 224, C_TEXT, 12, HORIZONTAL_ALIGNMENT_LEFT, 680)

	_draw_action_rail(Rect2(18, 268, 188, 226), _can_action_labels(), int(selected[3]))
	_draw_panel(Rect2(224, 268, 478, 372), C_PANEL, C_LINE)
	_draw_text(_t("can_log"), 242, 288, C_DIM, 14)
	var rows = _filtered_can_rows()
	if rows.is_empty():
		_draw_text(_t("can_empty"), 242, 332, C_TEXT, 15)
		return
	var start = max(0, rows.size() - 9)
	var y = 322.0
	for i in range(start, rows.size()):
		var row: Dictionary = rows[i]
		var row_rect = Rect2(240, y - 2, 444, 28)
		draw_rect(row_rect, C_INPUT, true)
		draw_rect(row_rect, C_LINE, false, 1.0)
		_draw_text(str(row.get("line", "")), 250, y + 5, C_TEXT, 11, HORIZONTAL_ALIGNMENT_LEFT, 420)
		y += 34


func _draw_upload_mode_page() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), C_BG, true)
	var rect = Rect2(52, 54, 616, 520)
	draw_rect(rect, C_BG_2, true)
	draw_rect(rect, C_ACCENT, false, 2.0)
	draw_line(rect.position, rect.position + Vector2(28, 0), C_ACCENT, 3.0)
	draw_line(rect.position, rect.position + Vector2(0, 28), C_ACCENT, 3.0)
	_draw_text(_t("upload_title"), rect.position.x + 28, rect.position.y + 30, C_TEXT, 24)
	_draw_text(_t("upload_subtitle"), rect.position.x + 28, rect.position.y + 82, C_TEXT, 15)

	_draw_upload_value_section(_t("upload_wifi"), upload_mode.ssid, 160, 21)
	_draw_upload_value_section(_t("upload_url"), upload_mode.url, 264, 17)
	_draw_upload_value_section(_t("upload_save_path"), "/storage/firmware.bin", 368, 17)
	_draw_text(_t("upload_status") + ": " + upload_mode.status, 170, 510, C_TEXT, 14)

	var exit_rect = Rect2(128, 598, 464, 52)
	draw_rect(exit_rect, C_INPUT, true)
	draw_rect(exit_rect, C_LINE, false, 1.0)
	_draw_text(_t("upload_exit"), exit_rect.position.x, exit_rect.position.y + 15, C_TEXT, 17, HORIZONTAL_ALIGNMENT_CENTER, exit_rect.size.x)
	draw_rect(exit_rect, C_WARN, false, 2.0)
	draw_rect(Rect2(exit_rect.position.x, exit_rect.position.y, 6, exit_rect.size.y), C_WARN, true)


func _draw_upload_value_section(title: String, value: String, y: float, value_size: int) -> void:
	var title_rect = Rect2(285, y, 150, 30)
	draw_rect(title_rect, C_INPUT, true)
	draw_rect(title_rect, C_LINE, false, 1.0)
	_draw_text(title, title_rect.position.x, title_rect.position.y + 5, C_TEXT, 17, HORIZONTAL_ALIGNMENT_CENTER, title_rect.size.x)
	var value_rect = Rect2(170, y + 38, 380, 50)
	draw_rect(value_rect, C_BG, true)
	draw_rect(value_rect, C_BG_2, false, 1.0)
	_draw_text(value, value_rect.position.x, value_rect.position.y + 13, C_TEXT, value_size, HORIZONTAL_ALIGNMENT_CENTER, value_rect.size.x)


func _draw_numeric_input_page() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), C_BG, true)
	var rect = Rect2(78, 58, 564, 548)
	draw_rect(rect, C_BG_2, true)
	draw_rect(rect, C_ACCENT, false, 2.0)
	draw_line(rect.position, rect.position + Vector2(28, 0), C_ACCENT, 3.0)
	draw_line(rect.position, rect.position + Vector2(0, 28), C_ACCENT, 3.0)
	var title_key = "motion_speed_title" if numeric_input.kind == "speed" else "motion_position_title"
	var hint_key = "motion_speed_hint" if numeric_input.kind == "speed" else "motion_position_hint"
	_draw_text(_t(title_key), rect.position.x + 30, rect.position.y + 34, C_TEXT, 24)
	_draw_text(_t(hint_key), rect.position.x + 30, rect.position.y + 78, C_DIM, 14)
	var input_rect = Rect2(rect.position.x + 72, rect.position.y + 126, rect.size.x - 144, 58)
	draw_rect(input_rect, C_INPUT, true)
	draw_rect(input_rect, C_LINE, false, 1.0)
	var value_text = numeric_input.value if numeric_input.value != "" else "--"
	_draw_text(value_text, input_rect.position.x, input_rect.position.y + 15, C_ACCENT if numeric_input.value != "" else C_DIM_2, 22, HORIZONTAL_ALIGNMENT_CENTER, input_rect.size.x)
	if numeric_input.kind == "speed":
		_draw_text("speed", input_rect.end.x - 66, input_rect.position.y + 20, C_DIM, 12)
	var key_w = 106.0
	var key_h = 42.0
	var gap = 12.0
	var y = rect.position.y + 226
	for row_index in NUMERIC_KEY_ROWS.size():
		var row: Array = NUMERIC_KEY_ROWS[row_index]
		var row_w = float(row.size()) * key_w + float(row.size() - 1) * gap
		var x = 360.0 - row_w * 0.5
		for col_index in row.size():
			var r = Rect2(x + col_index * (key_w + gap), y, key_w, key_h)
			draw_rect(r, C_INPUT, true)
			draw_rect(r, C_LINE, false, 1.0)
			_draw_text(str(row[col_index]), r.position.x, r.position.y + 11, C_TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += key_h + gap
	var selected_row: Array = NUMERIC_KEY_ROWS[numeric_input.key_row]
	var selected_row_w = float(selected_row.size()) * key_w + float(selected_row.size() - 1) * gap
	var selected_x = 360.0 - selected_row_w * 0.5 + numeric_input.key_col * (key_w + gap)
	var selected_y = rect.position.y + 226 + numeric_input.key_row * (key_h + gap)
	var selected_rect = Rect2(selected_x, selected_y, key_w, key_h)
	var selected_key = str(NUMERIC_KEY_ROWS[numeric_input.key_row][numeric_input.key_col])
	var selected_color = C_WARN if selected_key == "BACK" else C_ACCENT
	draw_rect(selected_rect, selected_color, false, 2.0)
	draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y), selected_color, true)


func _draw_filter_input_page() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), C_BG, true)
	var rect = Rect2(28, 72, 664, 548)
	draw_rect(rect, C_BG_2, true)
	draw_rect(rect, C_ACCENT, false, 2.0)
	draw_line(rect.position, rect.position + Vector2(28, 0), C_ACCENT, 3.0)
	draw_line(rect.position, rect.position + Vector2(0, 28), C_ACCENT, 3.0)
	_draw_text(_t("keyboard_title"), rect.position.x + 22, rect.position.y + 24, C_TEXT, 22)
	_draw_text(_t("keyboard_hint"), rect.position.x + 22, rect.position.y + 62, C_DIM, 13)

	var input_rect = Rect2(rect.position.x + 44, rect.position.y + 102, rect.size.x - 88, 52)
	draw_rect(input_rect, C_INPUT, true)
	draw_rect(input_rect, C_LINE, false, 1.0)
	_draw_text(_t("can_filter_label") + ":", input_rect.position.x + 16, input_rect.position.y + 15, C_TEXT, 16)
	_draw_text(can_log.filter if can_log.filter != "" else _t("can_all"), input_rect.position.x + 104, input_rect.position.y + 15, C_TEXT if can_log.filter != "" else C_DIM_2, 16)

	var key_h = 30.0
	var gap = 6.0
	var y = rect.position.y + 186
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
	var selected_y = rect.position.y + 186 + keyboard_row * (key_h + gap)
	var selected_rect = Rect2(selected_x, selected_y, selected_key_w, key_h)
	draw_rect(selected_rect, C_ACCENT, false, 2.0)
	draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y), C_ACCENT, true)


func _draw_action_rail(rect: Rect2, items: Array, selected_index: int) -> void:
	_draw_panel(rect, C_PANEL, C_LINE)
	_draw_text(_t("commands"), rect.position.x + 18, rect.position.y + 18, C_DIM, 14)
	var gap = 8.0
	var row_h = min(38.0, (rect.size.y - 58.0 - gap * float(max(items.size() - 1, 0))) / float(max(items.size(), 1)))
	var y = rect.position.y + 48
	for i in items.size():
		var is_sel = i == selected_index
		var r = Rect2(rect.position.x + 14, y, rect.size.x - 28, row_h)
		draw_rect(r, C_INPUT, true)
		draw_rect(r, C_LINE, false, 1.0)
		_draw_text(items[i], r.position.x, r.position.y + max(7, int((row_h - 18) * 0.5)), C_TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += row_h + gap
	if selected_index >= 0 and selected_index < items.size():
		var selected_rect = Rect2(rect.position.x + 14, rect.position.y + 48 + selected_index * (row_h + gap), rect.size.x - 28, row_h)
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

	var vals = motor.speed_history
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
	var input_state = "RAW /dev/input/js0" if raw_input.ok else "GODOT FALLBACK"
	_draw_text(_t("input"), rect.position.x + 14, rect.position.y + 16, C_DIM, 13)
	_draw_text(input_state, rect.position.x + 76, rect.position.y + 16, C_ACCENT if raw_input.ok else C_WARN, 13)
	_draw_text(_t("last"), rect.position.x + 270, rect.position.y + 16, C_DIM, 13)
	_draw_text(last_input_label, rect.position.x + 314, rect.position.y + 16, C_TEXT, 13)


func _draw_status_overlay() -> void:
	if not status.is_visible():
		return
	var color = C_ACCENT
	if status.kind == "warn":
		color = C_WARN
	elif status.kind == "error":
		color = C_RED
	var rect = Rect2(110, 622, 500, 42)
	draw_rect(rect, Color(C_INPUT, 0.96), true)
	draw_rect(rect, color, false, 2.0)
	_draw_text(status.message, rect.position.x, rect.position.y + 13, color, 14, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


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
	return [_t("can_filter"), _t("can_reset"), _t("can_run") if can_log.paused else _t("can_pause")]


func _filtered_can_rows() -> Array[Dictionary]:
	return can_log.filtered_rows()


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
	status.set_message(message, kind)


func _log_ota(message: String) -> void:
	ota.add_log(message)


func _state_color() -> Color:
	if ota.state == "error":
		return C_RED
	if ota.state == "sending" or ota.state == "verify":
		return C_WARN
	if ota.state == "done" or ota.state == "ready":
		return C_ACCENT
	return C_DIM


func _hex(value: int, width: int = 4) -> String:
	return ("%X" % value).pad_zeros(width)
