extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")


static func draw(canvas: CanvasItem, font: Font, t: Callable, command_items: Array, selected_index: int, motor, raw_ok: bool, last_input_label: String) -> void:
	_draw_action_rail(canvas, font, t, Rect2(18, 140, 188, 360), command_items, selected_index)
	_draw_telemetry_grid(canvas, font, t, Rect2(224, 140, 478, 190), motor)
	_draw_waveform_panel(canvas, font, t, Rect2(224, 346, 478, 196), motor)
	_draw_command_matrix(canvas, font, t, Rect2(18, 516, 188, 88))
	_draw_live_debug(canvas, font, t, Rect2(224, 558, 478, 46), raw_ok, last_input_label)


static func _draw_action_rail(canvas: CanvasItem, font: Font, t: Callable, rect: Rect2, items: Array, selected_index: int) -> void:
	_draw_panel(canvas, rect, UiTheme.C_PANEL, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("commands"), rect.position.x + 18, rect.position.y + 18, UiTheme.C_DIM, 14)
	var gap = 8.0
	var row_h = min(38.0, (rect.size.y - 58.0 - gap * float(max(items.size() - 1, 0))) / float(max(items.size(), 1)))
	var y = rect.position.y + 48
	for i in items.size():
		var r = Rect2(rect.position.x + 14, y, rect.size.x - 28, row_h)
		canvas.draw_rect(r, UiTheme.C_INPUT, true)
		canvas.draw_rect(r, UiTheme.C_LINE, false, 1.0)
		_draw_text(canvas, font, items[i], r.position.x, r.position.y + max(7, int((row_h - 18) * 0.5)), UiTheme.C_TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += row_h + gap
	if selected_index >= 0 and selected_index < items.size():
		var selected_rect = Rect2(rect.position.x + 14, rect.position.y + 48 + selected_index * (row_h + gap), rect.size.x - 28, row_h)
		canvas.draw_rect(selected_rect, UiTheme.C_ACCENT, false, 2.0)
		canvas.draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y), UiTheme.C_ACCENT, true)


static func _draw_telemetry_grid(canvas: CanvasItem, font: Font, t: Callable, rect: Rect2, motor) -> void:
	_draw_panel(canvas, rect, UiTheme.C_PANEL, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("telemetry"), rect.position.x + 18, rect.position.y + 18, UiTheme.C_DIM, 14)
	var cards = [
		[t.call("metric_current"), "%.2f" % motor.current, "A", UiTheme.C_ACCENT],
		[t.call("metric_voltage"), "%.1f" % motor.voltage, "V", UiTheme.C_ACCENT_2],
		[t.call("metric_speed"), "%d" % motor.speed, "rpm", UiTheme.C_WARN],
		[t.call("metric_position"), "%.1f" % motor.position, "deg", UiTheme.C_TEXT],
		[t.call("metric_torque"), "%.2f" % motor.torque, "Nm", UiTheme.C_GREEN],
		[t.call("metric_status"), motor.get_status_text(), "", UiTheme.C_RED if motor.is_fault() else UiTheme.C_GREEN],
	]
	var idx = 0
	for row in 2:
		for col in 3:
			var card = cards[idx]
			var x = rect.position.x + 16 + col * 150
			var y = rect.position.y + 46 + row * 62
			_draw_metric_card(canvas, font, Rect2(x, y, 138, 52), card[0], card[1], card[2], card[3])
			idx += 1


static func _draw_metric_card(canvas: CanvasItem, font: Font, rect: Rect2, label: String, value: String, unit: String, color: Color) -> void:
	canvas.draw_rect(rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(rect, Color(color, 0.75), false, 1.0)
	_draw_text(canvas, font, label, rect.position.x + 8, rect.position.y + 7, UiTheme.C_DIM, 12)
	var display_value = value if unit == "" else "%s %s" % [value, unit]
	_draw_text(canvas, font, display_value, rect.position.x + 8, rect.position.y + 27, color, 12)


static func _draw_waveform_panel(canvas: CanvasItem, font: Font, t: Callable, rect: Rect2, motor) -> void:
	_draw_panel(canvas, rect, UiTheme.C_PANEL, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("waveform"), rect.position.x + 18, rect.position.y + 18, UiTheme.C_DIM, 14)
	var plot = Rect2(rect.position.x + 18, rect.position.y + 46, rect.size.x - 36, rect.size.y - 66)
	canvas.draw_rect(plot, UiTheme.C_INPUT, true)
	for i in range(1, 5):
		var gy = plot.position.y + plot.size.y * i / 5.0
		canvas.draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), Color(UiTheme.C_GRID, 0.55), 1.0)
	for i in range(1, 7):
		var gx = plot.position.x + plot.size.x * i / 7.0
		canvas.draw_line(Vector2(gx, plot.position.y), Vector2(gx, plot.end.y), Color(UiTheme.C_GRID, 0.45), 1.0)
	canvas.draw_rect(plot, UiTheme.C_LINE, false, 1.0)

	var vals = motor.speed_history
	var n = min(vals.size(), 96)
	if n < 2:
		_draw_text(canvas, font, t.call("waiting_packets"), plot.position.x, plot.position.y + plot.size.y * 0.5 - 8, UiTheme.C_DIM, 15, HORIZONTAL_ALIGNMENT_CENTER, plot.size.x)
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
	canvas.draw_polyline(points, UiTheme.C_ACCENT, 2.0)


static func _draw_command_matrix(canvas: CanvasItem, font: Font, t: Callable, rect: Rect2) -> void:
	_draw_panel(canvas, rect, UiTheme.C_PANEL, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("hotkeys"), rect.position.x + 14, rect.position.y + 16, UiTheme.C_DIM, 13)
	_draw_text(canvas, font, "X %s" % t.call("cmd_enable"), rect.position.x + 14, rect.position.y + 42, UiTheme.C_ACCENT, 13)
	_draw_text(canvas, font, "Y %s" % t.call("cmd_disable"), rect.position.x + 96, rect.position.y + 42, UiTheme.C_WARN, 13)
	_draw_text(canvas, font, "L1/R1 JOG", rect.position.x + 14, rect.position.y + 66, UiTheme.C_TEXT, 13)
	_draw_text(canvas, font, "L2 %s" % t.call("cmd_estop"), rect.position.x + 96, rect.position.y + 66, UiTheme.C_RED, 13)


static func _draw_live_debug(canvas: CanvasItem, font: Font, t: Callable, rect: Rect2, raw_ok: bool, last_input_label: String) -> void:
	_draw_panel(canvas, rect, UiTheme.C_INPUT, UiTheme.C_LINE)
	var input_state = "RAW /dev/input/js0" if raw_ok else "GODOT FALLBACK"
	_draw_text(canvas, font, t.call("input"), rect.position.x + 14, rect.position.y + 16, UiTheme.C_DIM, 13)
	_draw_text(canvas, font, input_state, rect.position.x + 76, rect.position.y + 16, UiTheme.C_ACCENT if raw_ok else UiTheme.C_WARN, 13)
	_draw_text(canvas, font, t.call("last"), rect.position.x + 270, rect.position.y + 16, UiTheme.C_DIM, 13)
	_draw_text(canvas, font, last_input_label, rect.position.x + 314, rect.position.y + 16, UiTheme.C_TEXT, 13)


static func _draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color) -> void:
	canvas.draw_rect(rect, fill, true)
	canvas.draw_rect(rect, border, false, 1.0)
	canvas.draw_line(rect.position, rect.position + Vector2(18, 0), UiTheme.C_ACCENT, 2.0)
	canvas.draw_line(rect.position, rect.position + Vector2(0, 18), UiTheme.C_ACCENT, 2.0)
	canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - 18, rect.position.y), UiTheme.C_ACCENT_2, 2.0)
	canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + 18), UiTheme.C_ACCENT_2, 2.0)


static func _draw_text(canvas: CanvasItem, font: Font, text: String, x: float, y: float, color: Color, font_size: int = 16, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if font == null:
		return
	canvas.draw_string(font, Vector2(x, y + font_size), text, align, width, font_size, color)
