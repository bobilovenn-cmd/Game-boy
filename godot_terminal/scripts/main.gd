## 主控制器 - main.gd
## 作用: 应用入口，整合所有功能模块
## 职责:
##   - UI渲染: 绘制监控、配置、OTA、CAN日志页面
##   - 输入处理: 读取/dev/input/js0手柄按键 + Godot键盘事件
##   - UDP通信: 与ESP32 CAN网关收发消息
##   - OTA固件升级: 加载、分块传输、校验、刷写
## 依赖: settings.gd, protocol.gd, motor_data.gd, ui_text.gd

extends Control

## 集中模块目录：main 只依赖这一个入口
const Modules = preload("res://scripts/app/app_modules.gd")

## UI配置常量
const LANGUAGE_OPTIONS = Modules.UiConfig.LANGUAGE_OPTIONS  # 支持的语言列表
const TAB_KEYS = Modules.UiConfig.TAB_KEYS                  # 页面标签
const MONITOR_ITEM_KEYS = Modules.UiConfig.MONITOR_ITEM_KEYS
const CONFIG_ITEMS = Modules.UiConfig.CONFIG_ITEMS
const OTA_ITEM_KEYS = Modules.UiConfig.OTA_ITEM_KEYS
const CAN_ITEM_KEYS = Modules.UiConfig.CAN_ITEM_KEYS
const NODE_KEY_ROWS = Modules.UiConfig.NODE_KEY_ROWS
const KEYBOARD_ROWS = Modules.UiConfig.KEYBOARD_ROWS
const NUMERIC_KEY_ROWS = Modules.UiConfig.NUMERIC_KEY_ROWS

## 核心对象
var font: Font                              # 当前字体
var udp_client = Modules.UdpClient.new()            # UDP通信对象
var motor = Modules.MotorData.new()           # 电机数据实例
var motor_controller = Modules.MotorController.new() # 电机命令控制器
var upload_mode = Modules.UploadModeController.new() # 固件上传模式
var node_selector = Modules.NodeSelectorController.new() # 节点选择控制器
var numeric_input = Modules.NumericInputController.new() # 数字输入控制器
var can_filter = Modules.CanFilterController.new()   # CAN过滤输入控制器
var navigation = Modules.NavigationController.new()  # 页面导航控制器
var ota_transfer = Modules.OtaTransferController.new() # OTA传输控制器
var app_session = Modules.SessionController.new()    # 语言和节点会话控制器
var page_commands = Modules.PageCommandController.new() # 页面命令控制器
var firmware_controller = Modules.FirmwareController.new() # 固件加载控制器
var global_actions = Modules.GlobalActionController.new() # 全局动作控制器
var runtime = Modules.RuntimeController.new()         # 主循环运行调度器
var can_log = Modules.CanLogState.new()             # CAN日志状态
var connection = Modules.ConnectionState.new()      # UDP连接运行状态
var ota = Modules.OtaState.new()                    # OTA升级状态
var status = Modules.StatusState.new()              # 状态提示
var raw_input = Modules.RawInputReader.new()        # /dev/input/js0读取器
var input_router = Modules.InputRouter.new()        # 统一输入事件路由

var result_msg = ""                         # SDO读取结果


## 应用初始化
func _ready() -> void:
	motor_controller.configure_node(app_session.selected_node_id)
	navigation.reset(TAB_KEYS.size())

	font = Modules.AppBootstrap.load_ui_font(self)
	var udp_result = Modules.AppBootstrap.configure_udp(udp_client)
	connection.set_udp_ready(bool(udp_result.get("ok", false)))
	_set_status(str(udp_result.get("message", "")), str(udp_result.get("kind", "info")))

	var raw_result = Modules.AppBootstrap.start_raw_input(raw_input)
	if not bool(raw_result.get("ok", false)):
		_set_status(str(raw_result.get("message", "")), str(raw_result.get("kind", "warn")))
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
	if not app_session.language_selected:
		queue_redraw()
		return
	if not app_session.node_selected:
		queue_redraw()
		return

	for event in runtime.process_frame(
		now,
		udp_client,
		connection,
		motor,
		ota,
		ota_transfer,
		can_log,
		app_session.selected_node_id,
		Modules.AppSettings.HEARTBEAT_INTERVAL_MS
	):
		_apply_runtime_event(event)
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
	if not app_session.language_selected:
		_draw_language_select()  # 语言选择界面
		_draw_status_overlay()
		return
	if not app_session.node_selected:
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
		_apply_input_result(input_router.route_raw(raw, Modules.RawInputReader.RELEASE_OFFSET))


func _handle_godot_joy_button(button_index: int, pressed: bool) -> void:
	_apply_input_result(input_router.route_godot_button(button_index, pressed))


func _handle_godot_joy_motion(axis: int, value: float) -> void:
	_apply_input_result(input_router.route_godot_axis(axis, value))


func _handle_key(keycode: int) -> void:
	_apply_input_result(input_router.route_keyboard(keycode))


func _apply_input_result(result: Dictionary) -> void:
	if result.has("action"):
		_handle_action(str(result.get("action", "")))
	elif result.has("unmapped_button"):
		_set_status("Unmapped raw button %d" % int(result.get("unmapped_button", -1)), "warn")


func _handle_action(action: String) -> void:
	if not app_session.language_selected:
		_handle_language_action(action)
		return
	if not app_session.node_selected:
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

	_apply_global_action(global_actions.resolve(action, motor_controller))


func _apply_global_action(result: Dictionary) -> void:
	match str(result.get("event", "")):
		"navigate":
			_handle_navigation_action(str(result.get("action", "")))
		"send":
			_send(
				str(result.get("message", "")),
				str(result.get("ui_message", "")),
				str(result.get("kind", "info"))
			)
		"status":
			_set_status(str(result.get("message", "")), str(result.get("kind", "info")))
		"language_select":
			_return_to_language_select()


func _handle_language_action(action: String) -> void:
	var result = app_session.handle_language_action(action, LANGUAGE_OPTIONS)
	match str(result.get("event", "")):
		"shutdown":
			OS.execute("poweroff", [])
		"language_selected":
			node_selector.reset()
			_set_status("LANGUAGE %s" % app_session.ui_lang.to_upper())


func _handle_node_action(action: String) -> void:
	var result = node_selector.handle_action(action, NODE_KEY_ROWS, _t("node_error_empty"), _t("node_error_range"))
	match str(result.get("event", "")):
		"back":
			_return_to_language_select()
		"selected":
			_confirm_node_input(int(result.get("node", Modules.AppSettings.DEFAULT_NODE_ID)))


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
	app_session.select_node(value)
	motor_controller.configure_node(app_session.selected_node_id)
	navigation.reset(TAB_KEYS.size())
	motor = Modules.MotorData.new()
	connection.reset_received()
	result_msg = ""
	node_selector.error_msg = ""
	can_log.clear()
	_set_status(_t("node_selected_status") % app_session.selected_node_id)


func _return_to_language_select() -> void:
	app_session.return_to_language_select(LANGUAGE_OPTIONS)
	node_selector.reset()
	status.clear()


func _confirm_current_selection() -> void:
	var command = page_commands.resolve(
		navigation.current_tab,
		navigation.selected_index(),
		app_session.selected_node_id,
		CONFIG_ITEMS,
		motor_controller
	)
	_apply_page_command(command)


func _apply_page_command(command: Dictionary) -> void:
	if command.has("result_msg"):
		result_msg = str(command.get("result_msg", ""))
	if command.has("ota_log"):
		_log_ota(str(command.get("ota_log", "")))
	match str(command.get("event", "")):
		"send":
			_send(
				str(command.get("message", "")),
				str(command.get("ui_message", "")),
				str(command.get("kind", "info"))
			)
		"open_numeric":
			_open_numeric_input(str(command.get("kind", "")))
		"open_upload":
			_open_upload_mode()
		"load_firmware":
			_apply_firmware_result(firmware_controller.load_default(ota, Modules.AppSettings.FIRMWARE_PATHS))
		"start_ota":
			_apply_firmware_result(firmware_controller.start_transfer(ota, Modules.AppSettings.FIRMWARE_PATHS, Time.get_ticks_msec()))
		"open_filter":
			can_filter.start()
		"clear_can_log":
			can_log.clear()
			_set_status(_t("can_reset_status"))
		"toggle_can_pause":
			can_log.paused = not can_log.paused
			_set_status(_t("can_paused") if can_log.paused else _t("can_run_status"))


func _open_upload_mode() -> void:
	upload_mode.open_upload(Modules.AppSettings.UPLOAD_MODE_SCRIPT, _t("upload_starting"), _t("upload_script_missing"), _t("upload_ready"))
	_set_status(_t("upload_starting"))


func _close_upload_mode() -> void:
	upload_mode.close_upload(Modules.AppSettings.UPLOAD_MODE_SCRIPT)
	if FileAccess.file_exists("/storage/firmware.bin"):
		_apply_firmware_result(firmware_controller.load_default(ota, Modules.AppSettings.FIRMWARE_PATHS))
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


func _apply_runtime_event(event: Dictionary) -> void:
	if event.has("result_msg"):
		result_msg = str(event.get("result_msg", ""))
	if event.has("status_message"):
		_set_status(str(event.get("status_message", "")), str(event.get("status_kind", "info")))
	if event.has("ota_log"):
		_log_ota(str(event.get("ota_log", "")))
	if str(event.get("event", "")) == "send":
		_send(str(event.get("message", "")))


func _send(message: String, ui_msg: String = "", kind: String = "info") -> bool:
	if not connection.udp_ready:
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


func _apply_firmware_result(result: Dictionary) -> void:
	if result.has("status_message"):
		_set_status(str(result.get("status_message", "")), str(result.get("status_kind", "info")))


func _draw_background() -> void:
	Modules.AppChrome.draw_background(self)


func _draw_language_select() -> void:
	Modules.LanguageScreen.draw(self, font, Callable(self, "_t"), app_session.selected_language)


func _draw_node_select() -> void:
	Modules.NodeSelectScreen.draw(self, font, Callable(self, "_t"), NODE_KEY_ROWS, node_selector)


func _draw_header() -> void:
	Modules.AppChrome.draw_header(self, font, Callable(self, "_t"), motor, connection.last_rx_msec, connection.udp_ready, app_session.selected_node_id)


func _draw_tabs() -> void:
	Modules.AppChrome.draw_tabs(self, font, TAB_KEYS, navigation.current_tab, Callable(self, "_tab_name"))


func _draw_monitor_page() -> void:
	Modules.MonitorScreen.draw(self, font, Callable(self, "_t"), _texts(MONITOR_ITEM_KEYS), navigation.selected_index(0), motor, raw_input.ok, input_router.last_input_label)


func _draw_config_page() -> void:
	Modules.ConfigScreen.draw(self, font, Callable(self, "_t"), CONFIG_ITEMS, navigation.selected_index(1), result_msg)


func _draw_ota_page() -> void:
	Modules.OtaScreen.draw(self, font, Callable(self, "_t"), ota, OTA_ITEM_KEYS, navigation.selected_index(2))


func _draw_can_page() -> void:
	Modules.CanScreen.draw(self, font, Callable(self, "_t"), can_log, _can_action_labels(), navigation.selected_index(3))


func _draw_upload_mode_page() -> void:
	Modules.UploadModeScreen.draw(self, font, Callable(self, "_t"), upload_mode)


func _draw_numeric_input_page() -> void:
	Modules.NumericInputScreen.draw(self, font, Callable(self, "_t"), numeric_input, NUMERIC_KEY_ROWS, get_viewport_rect().size)


func _draw_filter_input_page() -> void:
	Modules.FilterInputScreen.draw(self, font, Callable(self, "_t"), can_log.filter, KEYBOARD_ROWS, can_filter.key_row, can_filter.key_col, can_filter.lowercase, get_viewport_rect().size)


func _draw_status_overlay() -> void:
	Modules.AppChrome.draw_status_overlay(self, font, status)


func _draw_footer() -> void:
	Modules.AppChrome.draw_footer(self, font, Callable(self, "_t"))


func _t(key: String) -> String:
	return Modules.UiText.text(app_session.ui_lang, key)


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
