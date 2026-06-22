extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AntVehicleTexture = preload("res://assets/ant_vehicle_top.png")

const HEADER_RECT := Rect2(6, 6, 708, 42)
const JOYSTICK_RECT := Rect2(6, 54, 314, 228)
const MOTION_RECT := Rect2(326, 54, 388, 228)
const LEFT_WHEEL_RECT := Rect2(6, 288, 350, 170)
const RIGHT_WHEEL_RECT := Rect2(364, 288, 350, 170)
const DRIVE_RECT := Rect2(6, 464, 344, 78)
const KEYS_RECT := Rect2(356, 464, 358, 78)
const SAFETY_RECT := Rect2(6, 548, 708, 66)
const PARAMS_RECT := Rect2(6, 620, 708, 58)
const FOOTER_RECT := Rect2(6, 684, 708, 30)
const LINK_TIMEOUT_MSEC := 1500


static func draw(canvas: CanvasItem, font: Font, t: Callable, state, connection) -> void:
	_draw_header(canvas, state, connection)
	_draw_joystick(canvas, state)
	_draw_motion(canvas, state)
	_draw_wheel_panel(canvas, LEFT_WHEEL_RECT, state.target_left_speed, state.left_motor)
	_draw_wheel_panel(canvas, RIGHT_WHEEL_RECT, state.target_right_speed, state.right_motor)
	_draw_drive_panel(canvas, state)
	_draw_keys_panel(canvas)
	_draw_safety_panel(canvas, state)
	_draw_params_panel(canvas)
	_draw_panel(canvas, FOOTER_RECT, UiTheme.C_PANEL, UiTheme.C_LINE)


static func _draw_header(canvas: CanvasItem, state, connection) -> void:
	_draw_panel(canvas, HEADER_RECT, UiTheme.C_PANEL, UiTheme.C_ACCENT_2)
	canvas.draw_line(Vector2(140, 14), Vector2(140, 40), UiTheme.C_DIM_2, 1.0)
	canvas.draw_line(Vector2(258, 14), Vector2(258, 40), UiTheme.C_DIM_2, 1.0)
	canvas.draw_line(Vector2(396, 14), Vector2(396, 40), UiTheme.C_DIM_2, 1.0)
	var link_alive: bool = connection.last_rx_msec > 0 and (
		Time.get_ticks_msec() - connection.last_rx_msec <= LINK_TIMEOUT_MSEC
	)
	_draw_chip(canvas, Rect2(268, 13, 56, 25), link_alive)
	_draw_chip(canvas, Rect2(330, 13, 56, 25),
		state.left_motor.alive or state.right_motor.alive)
	_draw_chip(canvas, Rect2(404, 13, 58, 25), not state.estop_latched)
	_draw_node_badge(canvas, Rect2(478, 11, 108, 29))
	_draw_node_badge(canvas, Rect2(596, 11, 108, 29))


static func _draw_joystick(canvas: CanvasItem, state) -> void:
	_draw_panel(canvas, JOYSTICK_RECT, UiTheme.C_PANEL, UiTheme.C_ACCENT_2)
	var center := Vector2(127, 174)
	var radius := 78.0
	var field := Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	canvas.draw_rect(field, UiTheme.C_INPUT, true)
	canvas.draw_rect(field, UiTheme.C_DIM_2, false, 1.0)
	canvas.draw_circle(center, radius - 5.0, Color(UiTheme.C_PANEL, 0.8))
	canvas.draw_arc(center, radius - 5.0, 0, TAU, 64, UiTheme.C_DIM, 1.0)
	canvas.draw_line(center - Vector2(radius - 5, 0), center + Vector2(radius - 5, 0),
		UiTheme.C_DIM_2, 1.0)
	canvas.draw_line(center - Vector2(0, radius - 5), center + Vector2(0, radius - 5),
		UiTheme.C_DIM_2, 1.0)
	_draw_dashed_circle(canvas, center, 28.0, UiTheme.C_DIM_2)
	var dot := center + Vector2(state.joystick.x, -state.joystick.y) * (radius - 11.0)
	canvas.draw_dashed_line(center, dot, UiTheme.C_ACCENT, 5.0, 3.0)
	canvas.draw_circle(dot, 15.0, Color(UiTheme.C_ACCENT, 0.20))
	canvas.draw_circle(dot, 11.0, UiTheme.C_ACCENT)
	canvas.draw_circle(center, 4.0, UiTheme.C_BG)
	canvas.draw_arc(center, 4.0, 0, TAU, 16, UiTheme.C_DIM, 1.0)
	_draw_axis_card(canvas, Rect2(230, 111, 72, 57), UiTheme.C_ACCENT_2)
	_draw_axis_card(canvas, Rect2(230, 179, 72, 57), UiTheme.C_ACCENT)


static func _draw_motion(canvas: CanvasItem, state) -> void:
	_draw_panel(canvas, MOTION_RECT, UiTheme.C_PANEL, UiTheme.C_ACCENT_2)
	canvas.draw_line(Vector2(434, 128), Vector2(434, 248), UiTheme.C_LINE, 1.0)
	var center := Vector2(574, 177)
	var vehicle_rect := Rect2(center - Vector2(49, 64), Vector2(98, 128))
	canvas.draw_circle(center, 61.0, Color(UiTheme.C_ACCENT_2, 0.035))
	canvas.draw_texture_rect(AntVehicleTexture, vehicle_rect, false)
	_draw_predicted_path(canvas, center, state.joystick.x)
	canvas.draw_line(center + Vector2(0, -62), center + Vector2(0, -91),
		UiTheme.C_ACCENT, 3.0)
	canvas.draw_line(center + Vector2(0, -91), center + Vector2(-7, -79),
		UiTheme.C_ACCENT, 3.0)
	canvas.draw_line(center + Vector2(0, -91), center + Vector2(7, -79),
		UiTheme.C_ACCENT, 3.0)


static func _draw_wheel_panel(
	canvas: CanvasItem,
	rect: Rect2,
	target_speed: int,
	motor
) -> void:
	_draw_panel(canvas, rect, UiTheme.C_PANEL, UiTheme.C_ACCENT_2)
	var data_rect := Rect2(rect.position + Vector2(8, 35), Vector2(rect.size.x - 16, 126))
	_draw_panel(canvas, data_rect, UiTheme.C_INPUT, UiTheme.C_DIM_2, 5.0)
	var ratios := [
		clamp(abs(float(target_speed)) / 90000.0, 0.0, 1.0),
		clamp(abs(float(motor.speed)) / 90000.0, 0.0, 1.0)
			if motor.is_field_fresh(motor.FIELD_SPEED) else 0.0,
		clamp(abs(motor.current) / 10.0, 0.0, 1.0)
			if motor.is_field_fresh(motor.FIELD_CURRENT) else 0.0,
		clamp(abs(motor.torque) / 10.0, 0.0, 1.0)
			if motor.is_field_fresh(motor.FIELD_TORQUE) else 0.0,
	]
	for index in ratios.size():
		var y := data_rect.position.y + 29.0 + index * 23.0
		_draw_metric_icon(canvas, Vector2(data_rect.position.x + 18, y), index)
		var bar := Rect2(data_rect.position.x + 44, y + 7, 164, 6)
		canvas.draw_rect(bar, Color(UiTheme.C_DIM_2, 0.28), true)
		canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratios[index], bar.size.y)),
			UiTheme.C_ACCENT, true)


static func _draw_drive_panel(canvas: CanvasItem, state) -> void:
	_draw_panel(canvas, DRIVE_RECT, UiTheme.C_PANEL, UiTheme.C_ACCENT_2)
	var cards = [
		{"rect": Rect2(14, 489, 99, 44), "active": state.parking_brake,
			"color": UiTheme.C_DIM_2},
		{"rect": Rect2(120, 489, 108, 44), "active": state.driving_enabled,
			"color": UiTheme.C_ACCENT},
		{"rect": Rect2(235, 489, 107, 44), "active": state.estop_latched,
			"color": UiTheme.C_RED},
	]
	for card in cards:
		var color: Color = card["color"]
		canvas.draw_rect(card["rect"],
			Color(color, 0.30) if card["active"] else UiTheme.C_INPUT, true)
		canvas.draw_rect(card["rect"], color if card["active"] else UiTheme.C_LINE,
			false, 1.0)


static func _draw_keys_panel(canvas: CanvasItem) -> void:
	_draw_panel(canvas, KEYS_RECT, UiTheme.C_PANEL, UiTheme.C_ACCENT_2)
	var cards = [
		{"rect": Rect2(366, 489, 105, 44), "color": UiTheme.C_ACCENT_2},
		{"rect": Rect2(478, 489, 105, 44), "color": UiTheme.C_WARN},
		{"rect": Rect2(590, 489, 114, 44), "color": UiTheme.C_RED},
	]
	for card in cards:
		var color: Color = card["color"]
		canvas.draw_rect(card["rect"], Color(color, 0.08), true)
		canvas.draw_rect(card["rect"], color, false, 1.0)
		canvas.draw_rect(Rect2(card["rect"].position, Vector2(4, card["rect"].size.y)),
			color, true)


static func _draw_safety_panel(canvas: CanvasItem, state) -> void:
	_draw_panel(canvas, SAFETY_RECT, UiTheme.C_PANEL, UiTheme.C_ACCENT_2)
	var inner := Rect2(94, 559, 610, 45)
	_draw_panel(canvas, inner, UiTheme.C_INPUT, UiTheme.C_DIM_2, 5.0)
	canvas.draw_line(Vector2(295, 566), Vector2(295, 598), UiTheme.C_DIM_2, 1.0)
	canvas.draw_line(Vector2(493, 566), Vector2(493, 598), UiTheme.C_DIM_2, 1.0)
	_draw_shield(canvas, Vector2(119, 581), UiTheme.C_ACCENT)
	_draw_clock(canvas, Vector2(326, 581), UiTheme.C_TEXT)
	_draw_nodes(canvas, Vector2(522, 581),
		UiTheme.C_RED if state.estop_latched else UiTheme.C_ACCENT)


static func _draw_params_panel(canvas: CanvasItem) -> void:
	_draw_panel(canvas, PARAMS_RECT, UiTheme.C_PANEL, UiTheme.C_ACCENT_2)
	var inner := Rect2(94, 630, 610, 38)
	_draw_panel(canvas, inner, UiTheme.C_INPUT, UiTheme.C_DIM_2, 5.0)
	for x in [244.0, 396.0, 548.0]:
		canvas.draw_line(Vector2(x, 635), Vector2(x, 663), UiTheme.C_DIM_2, 1.0)
	_draw_gauge(canvas, Vector2(114, 649), UiTheme.C_TEXT)
	_draw_steering(canvas, Vector2(265, 649), UiTheme.C_TEXT)
	_draw_target(canvas, Vector2(417, 649), UiTheme.C_TEXT)
	_draw_wave(canvas, Vector2(567, 649), UiTheme.C_TEXT)


static func _draw_predicted_path(canvas: CanvasItem, center: Vector2, turn: float) -> void:
	if abs(turn) <= 0.05:
		canvas.draw_dashed_line(center + Vector2(0, -60), center + Vector2(0, -112),
			UiTheme.C_ACCENT_2, 6.0, 4.0)
		return
	var trajectory_center := center + Vector2(-turn * 115.0, -75)
	for index in range(0, 24, 2):
		var start: float = lerpf(PI * 0.10, PI * 0.90, float(index) / 24.0)
		var end: float = lerpf(PI * 0.10, PI * 0.90, float(index + 1) / 24.0)
		canvas.draw_arc(trajectory_center, 91.0, start, end, 4, UiTheme.C_ACCENT_2, 2.0)


static func _draw_metric_icon(canvas: CanvasItem, center: Vector2, kind: int) -> void:
	var color := UiTheme.C_TEXT
	match kind:
		0:
			canvas.draw_circle(center, 6.0, color, false, 1.2)
			canvas.draw_line(center - Vector2(9, 0), center + Vector2(9, 0), color, 1.0)
			canvas.draw_line(center - Vector2(0, 9), center + Vector2(0, 9), color, 1.0)
		1:
			canvas.draw_arc(center, 8.0, PI, TAU, 12, color, 1.2)
			canvas.draw_line(center, center + Vector2(5, -5), color, 1.2)
		2:
			canvas.draw_polyline(PackedVector2Array([
				center + Vector2(-3, -9), center + Vector2(2, -2),
				center + Vector2(-2, -2), center + Vector2(3, 9),
			]), color, 1.5)
		3:
			canvas.draw_circle(center, 8.0, color, false, 1.2)
			canvas.draw_arc(center, 4.0, 0, PI * 1.4, 10, color, 1.2)


static func _draw_axis_card(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_rect(rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(rect, color, false, 1.0)


static func _draw_chip(canvas: CanvasItem, rect: Rect2, ok: bool) -> void:
	var color := UiTheme.C_ACCENT if ok else UiTheme.C_RED
	canvas.draw_rect(rect, Color(color, 0.14), true)
	canvas.draw_rect(rect, color, false, 1.0)


static func _draw_node_badge(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(rect, UiTheme.C_ACCENT_2, false, 1.0)


static func _draw_dashed_circle(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	for index in range(0, 24, 2):
		var start := TAU * float(index) / 24.0
		var end := TAU * float(index + 1) / 24.0
		canvas.draw_arc(center, radius, start, end, 3, color, 1.0)


static func _draw_shield(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_polyline(PackedVector2Array([
		center + Vector2(-8, -9), center + Vector2(8, -9),
		center + Vector2(8, 2), center + Vector2(0, 10),
		center + Vector2(-8, 2), center + Vector2(-8, -9),
	]), color, 1.5)
	canvas.draw_line(center + Vector2(-4, 0), center + Vector2(-1, 4), color, 1.5)
	canvas.draw_line(center + Vector2(-1, 4), center + Vector2(5, -4), color, 1.5)


static func _draw_clock(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_circle(center, 10.0, color, false, 1.5)
	canvas.draw_line(center, center + Vector2(0, -6), color, 1.5)
	canvas.draw_line(center, center + Vector2(5, 2), color, 1.5)


static func _draw_nodes(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	for offset in [Vector2(-7, -7), Vector2(7, -7), Vector2(-7, 7), Vector2(7, 7)]:
		canvas.draw_circle(center + offset, 3.0, color, false, 1.2)
	canvas.draw_line(center + Vector2(-4, -7), center + Vector2(4, -7), color, 1.0)
	canvas.draw_line(center + Vector2(-4, 7), center + Vector2(4, 7), color, 1.0)
	canvas.draw_line(center + Vector2(-7, -4), center + Vector2(-7, 4), color, 1.0)
	canvas.draw_line(center + Vector2(7, -4), center + Vector2(7, 4), color, 1.0)


static func _draw_gauge(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_arc(center, 9.0, PI, TAU, 12, color, 1.3)
	canvas.draw_line(center, center + Vector2(5, -5), color, 1.3)


static func _draw_steering(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_circle(center, 9.0, color, false, 1.3)
	canvas.draw_circle(center, 3.0, color, false, 1.0)
	canvas.draw_line(center + Vector2(0, 3), center + Vector2(0, 9), color, 1.0)
	canvas.draw_line(center + Vector2(-3, -1), center + Vector2(-8, -4), color, 1.0)
	canvas.draw_line(center + Vector2(3, -1), center + Vector2(8, -4), color, 1.0)


static func _draw_target(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_circle(center, 9.0, color, false, 1.2)
	canvas.draw_circle(center, 4.0, color, false, 1.2)
	canvas.draw_line(center - Vector2(13, 0), center + Vector2(13, 0), color, 1.0)
	canvas.draw_line(center - Vector2(0, 13), center + Vector2(0, 13), color, 1.0)


static func _draw_wave(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_polyline(PackedVector2Array([
		center + Vector2(-12, 0), center + Vector2(-7, 0),
		center + Vector2(-4, -8), center + Vector2(0, 8),
		center + Vector2(4, -8), center + Vector2(7, 0),
		center + Vector2(12, 0),
	]), color, 1.5)


static func _draw_panel(
	canvas: CanvasItem,
	rect: Rect2,
	fill: Color,
	border: Color,
	radius: float = 7.0
) -> void:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	canvas.draw_rect(
		Rect2(rect.position + Vector2(r, 0), Vector2(rect.size.x - r * 2.0, rect.size.y)),
		fill,
		true
	)
	canvas.draw_rect(
		Rect2(rect.position + Vector2(0, r), Vector2(rect.size.x, rect.size.y - r * 2.0)),
		fill,
		true
	)
	for center in [
		rect.position + Vector2(r, r),
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.position.x + r, rect.end.y - r),
		rect.end - Vector2(r, r),
	]:
		canvas.draw_circle(center, r, fill)
	canvas.draw_line(Vector2(rect.position.x + r, rect.position.y),
		Vector2(rect.end.x - r, rect.position.y), border, 1.0)
	canvas.draw_line(Vector2(rect.position.x + r, rect.end.y),
		Vector2(rect.end.x - r, rect.end.y), border, 1.0)
	canvas.draw_line(Vector2(rect.position.x, rect.position.y + r),
		Vector2(rect.position.x, rect.end.y - r), border, 1.0)
	canvas.draw_line(Vector2(rect.end.x, rect.position.y + r),
		Vector2(rect.end.x, rect.end.y - r), border, 1.0)
	canvas.draw_arc(rect.position + Vector2(r, r), r, PI, PI * 1.5, 8, border, 1.0)
	canvas.draw_arc(Vector2(rect.end.x - r, rect.position.y + r), r,
		PI * 1.5, TAU, 8, border, 1.0)
	canvas.draw_arc(Vector2(rect.position.x + r, rect.end.y - r), r,
		PI * 0.5, PI, 8, border, 1.0)
	canvas.draw_arc(rect.end - Vector2(r, r), r, 0, PI * 0.5, 8, border, 1.0)
