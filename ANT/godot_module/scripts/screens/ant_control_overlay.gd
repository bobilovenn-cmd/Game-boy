extends Node

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const LINK_TIMEOUT_MSEC := 1500
const BOLD_LABEL_KEYS := [
	"title",
	"breadcrumb_mode",
	"breadcrumb_ant",
	"joystick_title",
	"axis_x",
	"axis_y",
	"motion_title",
	"motion_state",
	"motion_linear_name",
	"motion_angular_name",
	"motion_linear_value",
	"motion_angular_value",
	"forward",
	"motion_left_node",
	"motion_right_node",
	"left_title",
	"left_status_title",
	"left_status",
	"right_title",
	"right_status_title",
	"right_status",
	"drive_title",
	"drive_brake",
	"drive_enabled",
	"drive_fault",
	"keys_title",
	"key_x_button",
	"key_x_desc",
	"key_y_button",
	"key_y_desc",
	"key_l2_button",
	"key_l2_desc",
	"safety_title",
	"safety_disconnect",
	"safety_timeout",
	"safety_nodes",
	"params_title",
	"param_speed",
	"param_steering",
	"param_deadzone",
	"param_accel",
]
const WHEEL_ROW_KEYS := ["target", "speed", "current", "torque"]

var labels: Dictionary = {}
var layers: Array[CanvasLayer] = []


func _init() -> void:
	# RGB30 实体渲染路径会遗漏同层的多个 Label，因此每个文字块独占 CanvasLayer。
	_add_label("title", Rect2(16, 11, 112, 30), 21, UiTheme.C_TEXT)
	_add_label("breadcrumb_mode", Rect2(153, 17, 43, 20), 12, UiTheme.C_ACCENT)
	_add_label("breadcrumb_ant", Rect2(196, 17, 55, 20), 12, UiTheme.C_TEXT)
	_add_label("link", Rect2(268, 13, 56, 25), 12, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("can", Rect2(330, 13, 56, 25), 12, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("safe", Rect2(404, 13, 58, 25), 12, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("left_node", Rect2(478, 11, 108, 29), 11, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("right_node", Rect2(596, 11, 108, 29), 11, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)

	_add_label("joystick_title", Rect2(16, 61, 180, 24), 15, UiTheme.C_ACCENT)
	_add_label("joystick_forward", Rect2(90, 78, 74, 18), 11, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("joystick_reverse", Rect2(90, 251, 74, 18), 11, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("joystick_left", Rect2(20, 165, 40, 18), 11, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("joystick_right", Rect2(194, 165, 40, 18), 11, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("axis_x", Rect2(230, 111, 72, 57), 15, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("axis_y", Rect2(230, 179, 72, 57), 15, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("deadzone", Rect2(226, 242, 80, 22), 13, UiTheme.C_DIM,
		HORIZONTAL_ALIGNMENT_CENTER)

	_add_label("motion_title", Rect2(336, 61, 180, 24), 15, UiTheme.C_ACCENT)
	_add_label("motion_state", Rect2(336, 91, 220, 34), 23, UiTheme.C_ACCENT)
	_add_label("motion_linear_name", Rect2(337, 137, 92, 20), 12, UiTheme.C_TEXT)
	_add_label("motion_linear_value", Rect2(337, 155, 92, 26), 18, UiTheme.C_ACCENT)
	_add_label("motion_angular_name", Rect2(337, 196, 92, 20), 12, UiTheme.C_TEXT)
	_add_label("motion_angular_value", Rect2(337, 214, 92, 26), 18, UiTheme.C_ACCENT)
	_add_label("forward", Rect2(544, 70, 60, 20), 14, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("motion_left_node", Rect2(458, 151, 80, 48), 12, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("motion_right_node", Rect2(618, 151, 80, 48), 12, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("trajectory", Rect2(500, 252, 152, 20), 12, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)

	_add_wheel_labels("left", 16, 299)
	_add_wheel_labels("right", 374, 299)

	_add_label("drive_title", Rect2(16, 470, 130, 18), 13, UiTheme.C_ACCENT)
	_add_label("drive_brake", Rect2(14, 493, 99, 23), 15, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("drive_enabled", Rect2(120, 493, 108, 23), 15, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("drive_fault", Rect2(235, 493, 107, 23), 15, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)

	_add_label("keys_title", Rect2(366, 470, 150, 18), 13, UiTheme.C_ACCENT)
	_add_label("key_x_button", Rect2(374, 496, 30, 30), 13, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("key_x_desc", Rect2(406, 498, 61, 26), 14, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("key_y_button", Rect2(486, 496, 30, 30), 13, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("key_y_desc", Rect2(518, 498, 61, 26), 14, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("key_l2_button", Rect2(598, 496, 34, 30), 12, UiTheme.C_RED,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("key_l2_desc", Rect2(634, 498, 66, 26), 14, UiTheme.C_RED,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)

	_add_label("safety_title", Rect2(16, 555, 72, 20), 14, UiTheme.C_ACCENT)
	_add_label("safety_disconnect", Rect2(137, 560, 150, 40), 14, UiTheme.C_TEXT)
	_add_label("safety_timeout", Rect2(344, 560, 140, 40), 14, UiTheme.C_TEXT)
	_add_label("safety_nodes", Rect2(540, 560, 154, 40), 14, UiTheme.C_TEXT)

	_add_label("params_title", Rect2(16, 628, 72, 20), 14, UiTheme.C_ACCENT)
	_add_label("param_speed", Rect2(132, 631, 106, 36), 13, UiTheme.C_TEXT)
	_add_label("param_steering", Rect2(283, 631, 107, 36), 13, UiTheme.C_TEXT)
	_add_label("param_deadzone", Rect2(435, 631, 107, 36), 13, UiTheme.C_TEXT)
	_add_label("param_accel", Rect2(585, 631, 112, 36), 13, UiTheme.C_TEXT)

	_add_label("footer_dpad", Rect2(42, 691, 120, 17), 10, UiTheme.C_DIM)
	_add_label("footer_a_button", Rect2(190, 689, 16, 17), 10, UiTheme.C_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("footer_a", Rect2(214, 691, 126, 17), 10, UiTheme.C_DIM)
	_add_label("footer_b_button", Rect2(370, 689, 16, 17), 10, UiTheme.C_RED,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("footer_b", Rect2(394, 691, 116, 17), 10, UiTheme.C_DIM)
	_add_label("footer_select_button", Rect2(541, 691, 44, 13), 7, UiTheme.C_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_add_label("footer_select", Rect2(592, 691, 105, 17), 10, UiTheme.C_DIM)


func configure(font: Font) -> void:
	if font == null:
		return
	for label in labels.values():
		label.add_theme_font_override("font", font)
	var bold_font := FontVariation.new()
	bold_font.base_font = font
	bold_font.variation_embolden = 0.75
	for key in BOLD_LABEL_KEYS:
		labels[key].add_theme_font_override("font", bold_font)
	for prefix in ["left", "right"]:
		for row_key in WHEEL_ROW_KEYS:
			labels["%s_%s_name" % [prefix, row_key]].add_theme_font_override(
				"font", bold_font
			)
			labels["%s_%s_value" % [prefix, row_key]].add_theme_font_override(
				"font", bold_font
			)


func sync(t: Callable, state, connection, visible: bool) -> void:
	for canvas_layer in layers:
		canvas_layer.visible = visible
	if not visible:
		return

	labels["title"].text = t.call("ant_title")
	labels["breadcrumb_mode"].text = "模式 /"
	labels["breadcrumb_ant"].text = "蚂蚁"
	labels["link"].text = "LINK"
	labels["can"].text = "CAN"
	labels["safe"].text = "安全"
	labels["left_node"].text = "左轮 Node 1"
	labels["right_node"].text = "右轮 Node 2"
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
	labels["joystick_forward"].text = "前进"
	labels["joystick_reverse"].text = "后退"
	labels["joystick_left"].text = "左转"
	labels["joystick_right"].text = "右转"
	labels["axis_x"].text = "X\n%+.2f" % state.joystick.x
	labels["axis_y"].text = "Y\n%+.2f" % state.joystick.y
	labels["deadzone"].text = "死区 8%"

	labels["motion_title"].text = "运动状态"
	labels["motion_state"].text = t.call(state.motion_label())
	labels["motion_state"].add_theme_color_override("font_color",
		UiTheme.C_RED if state.estop_latched else UiTheme.C_ACCENT)
	labels["motion_linear_name"].text = "线速度"
	labels["motion_linear_value"].text = "--  m/s"
	labels["motion_angular_name"].text = "角速度"
	labels["motion_angular_value"].text = "--  rad/s"
	labels["forward"].text = "前进"
	labels["motion_left_node"].text = "左轮\nNode 1"
	labels["motion_right_node"].text = "右轮\nNode 2"
	labels["trajectory"].text = "预测轨迹（平地）"

	_sync_wheel("left", state.target_left_speed, state.left_motor)
	_sync_wheel("right", state.target_right_speed, state.right_motor)

	labels["drive_title"].text = "驾驶状态"
	labels["drive_brake"].text = "手刹"
	labels["drive_enabled"].text = "驾驶"
	labels["drive_fault"].text = "故障停车"
	labels["keys_title"].text = "物理按键控制"
	labels["key_x_button"].text = "X"
	labels["key_x_desc"].text = "驾驶"
	labels["key_y_button"].text = "Y"
	labels["key_y_desc"].text = "停车"
	labels["key_l2_button"].text = "L2"
	labels["key_l2_desc"].text = "急停"

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
	labels["footer_dpad"].text = "D-PAD 调整"
	labels["footer_a_button"].text = "A"
	labels["footer_a"].text = "A 设置"
	labels["footer_b_button"].text = "B"
	labels["footer_b"].text = "B 无操作"
	labels["footer_select_button"].text = "SELECT"
	labels["footer_select"].text = "SELECT 模式"


func _add_wheel_labels(prefix: String, x: float, y: float) -> void:
	_add_label("%s_title" % prefix, Rect2(x, y, 214, 24), 17, UiTheme.C_ACCENT)
	_add_label("%s_status_title" % prefix, Rect2(x + 275, y + 39, 57, 22), 12,
		UiTheme.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("%s_status" % prefix, Rect2(x + 275, y + 112, 57, 22), 11,
		UiTheme.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	var row_offsets := [32.0, 64.0, 96.0, 126.0]
	for index in WHEEL_ROW_KEYS.size():
		var row_y: float = y + row_offsets[index]
		_add_label(
			"%s_%s_name" % [prefix, WHEEL_ROW_KEYS[index]],
			Rect2(x + 49, row_y, 82, 18),
			12,
			UiTheme.C_TEXT
		)
		_add_label(
			"%s_%s_value" % [prefix, WHEEL_ROW_KEYS[index]],
			Rect2(x + 132, row_y, 132, 18),
			12,
			UiTheme.C_TEXT,
			HORIZONTAL_ALIGNMENT_LEFT
		)


func _sync_wheel(prefix: String, target_speed: int, motor) -> void:
	var node := 1 if prefix == "left" else 2
	labels["%s_title" % prefix].text = "%s轮 / Node %d" % [
		"左" if prefix == "left" else "右",
		node,
	]
	labels["%s_status_title" % prefix].text = "状态"
	labels["%s_status" % prefix].text = _motor_health(motor)
	labels["%s_status" % prefix].add_theme_color_override("font_color",
		UiTheme.C_ACCENT if motor.alive and not motor.is_alert() else (
			UiTheme.C_RED if motor.is_alert() else UiTheme.C_WARN
		)
	)
	var row_names := {
		"target": "目标速度",
		"speed": "实际速度",
		"current": "电流",
		"torque": "转矩",
	}
	var row_values := {
		"target": "%d pulse/s" % target_speed,
		"speed": _speed_text(motor),
		"current": _current_text(motor),
		"torque": _torque_text(motor),
	}
	for key in row_names:
		labels["%s_%s_name" % [prefix, key]].text = row_names[key]
		labels["%s_%s_value" % [prefix, key]].text = row_values[key]


func _speed_text(motor) -> String:
	return "%d pulse/s" % motor.speed if motor.is_field_fresh(motor.FIELD_SPEED) else "--"


func _current_text(motor) -> String:
	return "%.2f A" % motor.current if motor.is_field_fresh(motor.FIELD_CURRENT) else "--"


func _torque_text(motor) -> String:
	return "%.2f Nm" % motor.torque if motor.is_field_fresh(motor.FIELD_TORQUE) else "--"


func _motor_status(motor) -> String:
	return motor.get_status_text() if motor.alive else "离线"


func _motor_health(motor) -> String:
	if not motor.alive:
		return "离线"
	if motor.is_alert():
		return "故障"
	return "正常"


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
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
	vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_TOP
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
	label.vertical_alignment = vertical_alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	canvas_layer.add_child(label)
	labels[key] = label
