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
const CanFilterController = preload("res://scripts/controllers/can_filter_controller.gd")  # CAN过滤键盘
const NavigationController = preload("res://scripts/controllers/navigation_controller.gd")  # 页面导航
const OtaTransferController = preload("res://scripts/controllers/ota_transfer_controller.gd")  # OTA分块传输
const MotorDataScript = preload("res://scripts/motor_data.gd")  # 电机数据模型
const CanLogState = preload("res://scripts/models/can_log_state.gd")  # CAN日志状态
const OtaState = preload("res://scripts/models/ota_state.gd")  # OTA状态
const StatusState = preload("res://scripts/models/status_state.gd")  # 状态提示
const UiText = preload("res://scripts/ui_text.gd")          # 国际化文本
const UiConfig = preload("res://scripts/app/ui_config.gd")   # UI页面配置
const InputMapper = preload("res://scripts/input/input_mapper.gd")  # 按键映射
const RawInputReader = preload("res://scripts/input/raw_input_reader.gd")  # RGB30原始输入读取
const LanguageScreen = preload("res://scripts/screens/language_screen.gd")  # 语言选择页
const NodeSelectScreen = preload("res://scripts/screens/node_select_screen.gd")  # 节点选择页
const UploadModeScreen = preload("res://scripts/screens/upload_mode_screen.gd")  # 固件上传模式页
const AppChrome = preload("res://scripts/screens/app_chrome.gd")  # UI外壳
const MonitorScreen = preload("res://scripts/screens/monitor_screen.gd")  # 监控页
const ConfigScreen = preload("res://scripts/screens/config_screen.gd")  # 配置页
const OtaScreen = preload("res://scripts/screens/ota_screen.gd")  # 固件升级页
const CanScreen = preload("res://scripts/screens/can_screen.gd")  # CAN日志页
const NumericInputScreen = preload("res://scripts/screens/numeric_input_screen.gd")  # 数字输入页
const FilterInputScreen = preload("res://scripts/screens/filter_input_screen.gd")  # CAN过滤键盘页

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
var can_filter = CanFilterController.new()   # CAN过滤输入控制器
var navigation = NavigationController.new()  # 页面导航控制器
var ota_transfer = OtaTransferController.new() # OTA传输控制器
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

var result_msg = ""                         # SDO读取结果

## UDP连接状态
var last_heartbeat_msec = 0                 # 上次心跳时间
var last_rx_msec = 0                        # 上次收到数据时间
var udp_ready = false                       # UDP是否就绪

## 手柄输入状态
var last_input_label = "none"               # 最近按键调试标签
var last_raw_button = -1                    # 最近原始按键ID
var godot_axis_active = {}                  # fallback 轴输入去抖状态


## 应用初始化
func _ready() -> void:
	motor_controller.configure_node(selected_node_id)
	navigation.reset(TAB_KEYS.size())

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
	if can_filter.open:
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
	match navigation.current_tab:
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
	if can_filter.open:
		_handle_filter_input_action(action)
		return
	if numeric_input.open:
		_handle_numeric_input_action(action)
		return

	match action:
		"menu", "up", "down", "left", "right", "confirm":
			_handle_navigation_action(action)
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


func _handle_navigation_action(action: String) -> void:
	var result = navigation.handle_action(action, TAB_KEYS.size(), _navigation_max_indices())
	match str(result.get("event", "")):
		"page_changed":
			_set_status("PAGE %s" % _tab_name(navigation.current_tab))
		"confirm":
			_confirm_current_selection()


func _navigation_max_indices() -> Array[int]:
	return [
		MONITOR_ITEM_KEYS.size() - 1,
		CONFIG_ITEMS.size() - 1,
		OTA_ITEM_KEYS.size() - 1,
		CAN_ITEM_KEYS.size() - 1,
	]


func _confirm_node_input(value: int) -> void:
	selected_node_id = value
	motor_controller.configure_node(selected_node_id)
	node_selected = true
	navigation.reset(TAB_KEYS.size())
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
	var tab = navigation.current_tab
	var index = navigation.selected_index(tab)
	if tab == 0:
		match index:
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
	elif tab == 1:
		var item: Array = CONFIG_ITEMS[index]
		var name_key: String = item[0]
		var index: int = item[1]
		var sub: int = item[2]
		if name_key == "cfg_save_eeprom":
			_send(Protocol.sdo_write(selected_node_id, index, sub, 0x65766173), "Save EEPROM")
		else:
			result_msg = "Reading 0x%s..." % _hex(index)
			_send(Protocol.sdo_read(selected_node_id, index, sub), result_msg)
	elif tab == 2:
		match index:
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
	elif tab == 3:
		match index:
			0:
				can_filter.start()
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


func _handle_filter_input_action(action: String) -> void:
	var result = can_filter.handle_action(action, KEYBOARD_ROWS, can_log.filter)
	if result.has("filter"):
		can_log.filter = str(result.get("filter", can_log.filter))
	match str(result.get("event", "")):
		"language_select":
			_return_to_language_select()
		"selected":
			_set_status(_t("can_filter_label") + ": " + (can_log.filter if can_log.filter != "" else _t("can_all")))


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


func _process_ota(now: int) -> void:
	for message in ota_transfer.process(ota, now):
		_send(message)


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
	AppChrome.draw_background(self)


func _draw_language_select() -> void:
	LanguageScreen.draw(self, font, Callable(self, "_t"), selected_language)


func _draw_node_select() -> void:
	NodeSelectScreen.draw(self, font, Callable(self, "_t"), NODE_KEY_ROWS, node_selector)


func _draw_header() -> void:
	AppChrome.draw_header(self, font, Callable(self, "_t"), motor, last_rx_msec, udp_ready, selected_node_id)


func _draw_tabs() -> void:
	AppChrome.draw_tabs(self, font, TAB_KEYS, navigation.current_tab, Callable(self, "_tab_name"))


func _draw_monitor_page() -> void:
	MonitorScreen.draw(self, font, Callable(self, "_t"), _texts(MONITOR_ITEM_KEYS), navigation.selected_index(0), motor, raw_input.ok, last_input_label)


func _draw_config_page() -> void:
	ConfigScreen.draw(self, font, Callable(self, "_t"), CONFIG_ITEMS, navigation.selected_index(1), result_msg)


func _draw_ota_page() -> void:
	OtaScreen.draw(self, font, Callable(self, "_t"), ota, OTA_ITEM_KEYS, navigation.selected_index(2))


func _draw_can_page() -> void:
	CanScreen.draw(self, font, Callable(self, "_t"), can_log, _can_action_labels(), navigation.selected_index(3))


func _draw_upload_mode_page() -> void:
	UploadModeScreen.draw(self, font, Callable(self, "_t"), upload_mode)


func _draw_numeric_input_page() -> void:
	NumericInputScreen.draw(self, font, Callable(self, "_t"), numeric_input, NUMERIC_KEY_ROWS, get_viewport_rect().size)


func _draw_filter_input_page() -> void:
	FilterInputScreen.draw(self, font, Callable(self, "_t"), can_log.filter, KEYBOARD_ROWS, can_filter.key_row, can_filter.key_col, can_filter.lowercase, get_viewport_rect().size)


func _draw_status_overlay() -> void:
	AppChrome.draw_status_overlay(self, font, status)


func _draw_footer() -> void:
	AppChrome.draw_footer(self, font, Callable(self, "_t"))


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


func _set_status(message: String, kind: String = "info") -> void:
	status.set_message(message, kind)


func _log_ota(message: String) -> void:
	ota.add_log(message)


func _hex(value: int, width: int = 4) -> String:
	return ("%X" % value).pad_zeros(width)
