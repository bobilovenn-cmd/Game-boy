extends Node

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const LINK_TIMEOUT_MSEC := 1500

var labels: Dictionary = {}
var layers: Array[CanvasLayer] = []


func _init() -> void:
	# RGB30 实体渲染路径会遗漏同层的多个 Label，因此每个文字块独占 CanvasLayer。
	_add_label("title", Rect2(16, 11, 112, 30), 21, UiTheme.C_TEXT)
	_add_label("breadcrumb", Rect2(153, 17, 96, 20), 12, UiTheme.C_ACCENT)
	_add_label("link", Rect2(268, 14, 56, 24), 8, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("can", Rect2(330, 14, 56, 24), 8, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("safe", Rect2(404, 14, 58, 24), 8, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("left_node", Rect2(478, 12, 108, 27), 8, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("right_node", Rect2(596, 12, 108, 27), 8, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)

	_add_label("joystick_title", Rect2(16, 61, 180, 24), 15, UiTheme.C_ACCENT)
	_add_label("joystick_guides", Rect2(19, 91, 212, 178), 11, UiTheme.C_TEXT)
	_add_label("axis_x", Rect2(233, 118, 66, 44), 12, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("axis_y", Rect2(233, 186, 66, 44), 12, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("deadzone", Rect2(235, 245, 62, 18), 10, UiTheme.C_DIM,
		HORIZONTAL_ALIGNMENT_CENTER)

	_add_label("motion_title", Rect2(336, 61, 180, 24), 15, UiTheme.C_ACCENT)
	_add_label("motion_state", Rect2(336, 91, 220, 34), 23, UiTheme.C_ACCENT)
	_add_label("motion_names", Rect2(337, 137, 92, 108), 11, UiTheme.C_TEXT)
	_add_label("motion_values", Rect2(337, 155, 92, 90), 17, UiTheme.C_ACCENT)
	_add_label("forward", Rect2(548, 83, 52, 18), 10, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("motion_left_node", Rect2(472, 156, 54, 42), 9, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("motion_right_node", Rect2(632, 156, 54, 42), 9, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("trajectory", Rect2(500, 255, 152, 18), 11, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)

	_add_wheel_labels("left", 16, 299)
	_add_wheel_labels("right", 374, 299)

	_add_label("drive_title", Rect2(16, 470, 130, 18), 13, UiTheme.C_ACCENT)
	_add_label("drive_brake", Rect2(14, 497, 99, 30), 12, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("drive_enabled", Rect2(120, 497, 108, 30), 12, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("drive_fault", Rect2(235, 497, 107, 30), 12, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)

	_add_label("keys_title", Rect2(366, 470, 150, 18), 13, UiTheme.C_ACCENT)
	_add_label("key_x", Rect2(366, 497, 105, 30), 11, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("key_y", Rect2(478, 497, 105, 30), 11, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("key_l2", Rect2(590, 497, 114, 30), 11, UiTheme.C_RED,
		HORIZONTAL_ALIGNMENT_CENTER)

	_add_label("safety_title", Rect2(16, 555, 72, 20), 14, UiTheme.C_ACCENT)
	_add_label("safety_disconnect", Rect2(137, 564, 150, 34), 11, UiTheme.C_TEXT)
	_add_label("safety_timeout", Rect2(344, 564, 140, 34), 11, UiTheme.C_TEXT)
	_add_label("safety_nodes", Rect2(540, 564, 154, 34), 11, UiTheme.C_TEXT)

	_add_label("params_title", Rect2(16, 628, 72, 20), 14, UiTheme.C_ACCENT)
	_add_label("param_speed", Rect2(132, 635, 106, 28), 10, UiTheme.C_TEXT)
	_add_label("param_steering", Rect2(283, 635, 107, 28), 10, UiTheme.C_TEXT)
	_add_label("param_deadzone", Rect2(435, 635, 107, 28), 10, UiTheme.C_TEXT)
	_add_label("param_accel", Rect2(585, 635, 112, 28), 10, UiTheme.C_TEXT)

	_add_label("footer", Rect2(16, 691, 688, 17), 10, UiTheme.C_DIM,
		HORIZONTAL_ALIGNMENT_CENTER)


func configure(font: Font) -> void:
	if font == null:
		return
	for label in labels.values():
		label.add_theme_font_override("font", font)


func sync(t: Callable, state, connection, visible: bool) -> void:
	for canvas_layer in layers:
		canvas_layer.visible = visible
	if not visible:
		return

	labels["title"].text = t.call("ant_title")
	labels["breadcrumb"].text = "模式  /  蚂蚁"
	labels["link"].text = "LINK\n已连接"
	labels["can"].text = "CAN\n%s" % (
		"正常" if state.left_motor.alive or state.right_motor.alive else "离线"
	)
	labels["safe"].text = "安全\n%s" % ("急停" if state.estop_latched else "正常")
	labels["left_node"].text = "左轮 Node 1\n固定节点"
	labels["right_node"].text = "右轮 Node 2\n固定节点"
	var link_alive: bool = connection.last_rx_msec > 0 and (
		Time.get_ticks_msec() - connection.last_rx_msec <= LINK_TIMEOUT_MSEC
	)
	labels["link"].add_theme_color_override("font_color",
		UiTheme.C_ACCENT if link_alive else UiTheme.C_RED)
	labels["can"].add_theme_color_override("font_color",
		UiTheme.C_ACCENT if state.left_motor.alive or state.right_motor.alive else UiTheme.C_RED)
	labels["safe"].add_theme_color_override("font_color",
		UiTheme.C_RED if state.estop_latched else UiTheme.C_ACCENT)

	labels["joystick_title"].text = "摇杆输入"
	labels["joystick_guides"].text = "                 前进\n\n\n左转                                      右转\n\n\n                 后退"
	labels["axis_x"].text = "X\n%+.2f" % state.joystick.x
	labels["axis_y"].text = "Y\n%+.2f" % state.joystick.y
	labels["deadzone"].text = "死区 8%"

	labels["motion_title"].text = "运动状态"
	labels["motion_state"].text = t.call(state.motion_label())
	labels["motion_state"].add_theme_color_override("font_color",
		UiTheme.C_RED if state.estop_latched else UiTheme.C_ACCENT)
	labels["motion_names"].text = "线速度\n\n\n角速度"
	labels["motion_values"].text = "--  m/s\n\n--  rad/s"
	labels["forward"].text = "前进"
	labels["motion_left_node"].text = "左轮\nNode 1"
	labels["motion_right_node"].text = "右轮\nNode 2"
	labels["trajectory"].text = "预测轨迹（平地）"

	_sync_wheel("left", state.target_left_speed, state.left_motor)
	_sync_wheel("right", state.target_right_speed, state.right_motor)

	labels["drive_title"].text = "驾驶状态"
	labels["drive_brake"].text = "手刹\n(P)"
	labels["drive_enabled"].text = "驾驶\n◉"
	labels["drive_fault"].text = "故障停车\n△"
	labels["keys_title"].text = "物理按键控制"
	labels["key_x"].text = "X  驾驶\n放下手刹"
	labels["key_y"].text = "Y  停车\n拉起手刹"
	labels["key_l2"].text = "L2  急停"

	labels["safety_title"].text = "安全策略"
	labels["safety_disconnect"].text = "失联自动停车\n已启用"
	labels["safety_timeout"].text = "摇杆超时\n200 ms"
	labels["safety_nodes"].text = "双节点状态\n%s" % (
		"急停" if state.estop_latched else _node_summary(state)
	)
	labels["safety_nodes"].add_theme_color_override("font_color",
		UiTheme.C_RED if state.estop_latched else UiTheme.C_TEXT)

	labels["params_title"].text = "参数设置"
	labels["param_speed"].text = "速度上限\n30%"
	labels["param_steering"].text = "转向灵敏度\n100%"
	labels["param_deadzone"].text = "死区\n8%"
	labels["param_accel"].text = "平滑加速\n未接入"
	labels["footer"].text = "D-PAD 调整       A 设置       B 返回       SELECT 模式"


func _add_wheel_labels(prefix: String, x: float, y: float) -> void:
	_add_label("%s_title" % prefix, Rect2(x, y, 214, 24), 17, UiTheme.C_ACCENT)
	_add_label("%s_status" % prefix, Rect2(x + 267, y + 1, 62, 20), 10,
		UiTheme.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("%s_names" % prefix, Rect2(x + 49, y + 39, 82, 108), 10, UiTheme.C_TEXT)
	_add_label("%s_values" % prefix, Rect2(x + 205, y + 39, 127, 108), 9,
		UiTheme.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)


func _sync_wheel(prefix: String, target_speed: int, motor) -> void:
	var node := 1 if prefix == "left" else 2
	labels["%s_title" % prefix].text = "%s轮 / Node %d" % [
		"左" if prefix == "left" else "右",
		node,
	]
	labels["%s_status" % prefix].text = _motor_status(motor)
	labels["%s_status" % prefix].add_theme_color_override("font_color",
		UiTheme.C_ACCENT if motor.alive else UiTheme.C_WARN)
	labels["%s_names" % prefix].text = "本地目标\n\n实际速度\n\n电流\n\n转矩\n\n状态"
	labels["%s_values" % prefix].text = "%d pulse/s\n\n%s\n\n%s\n\n%s\n\n%s" % [
		target_speed,
		_speed_text(motor),
		_current_text(motor),
		_torque_text(motor),
		_motor_status(motor),
	]


func _speed_text(motor) -> String:
	return "%d pulse/s" % motor.speed if motor.is_field_fresh(motor.FIELD_SPEED) else "--"


func _current_text(motor) -> String:
	return "%.2f A" % motor.current if motor.is_field_fresh(motor.FIELD_CURRENT) else "--"


func _torque_text(motor) -> String:
	return "%.2f Nm" % motor.torque if motor.is_field_fresh(motor.FIELD_TORQUE) else "--"


func _motor_status(motor) -> String:
	return motor.get_status_text() if motor.alive else "离线"


func _node_summary(state) -> String:
	if state.left_motor.alive and state.right_motor.alive:
		return "正常"
	if state.left_motor.alive or state.right_motor.alive:
		return "单节点离线"
	return "等待连接"


func _add_label(
	key: String,
	rect: Rect2,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "%sLayer" % key
	canvas_layer.layer = 20 + layers.size()
	add_child(canvas_layer)
	layers.append(canvas_layer)

	var label := Label.new()
	label.name = key
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	canvas_layer.add_child(label)
	labels[key] = label
