extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")


static func draw(canvas: CanvasItem, font: Font, t: Callable, can_log, action_labels: Array, selected_index: int) -> void:
	_draw_panel(canvas, Rect2(18, 140, 684, 108), UiTheme.C_PANEL, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("can_header"), 36, 158, UiTheme.C_ACCENT, 13)
	_draw_text(canvas, font, t.call("can_filter_label"), 36, 194, UiTheme.C_DIM, 13)
	var input_rect = Rect2(112, 188, 474, 30)
	canvas.draw_rect(input_rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(input_rect, UiTheme.C_LINE, false, 1.0)
	var filter_text = can_log.filter if can_log.filter != "" else t.call("can_all")
	var filter_color = UiTheme.C_TEXT if can_log.filter != "" else UiTheme.C_DIM_2
	_draw_text(canvas, font, filter_text, input_rect.position.x + 10, input_rect.position.y + 7, filter_color, 12)
	if can_log.paused:
		_draw_text(canvas, font, t.call("can_paused"), 604, 194, UiTheme.C_WARN, 12)
	var rows = can_log.filtered_rows()
	_draw_text(canvas, font, "RX %d/%d" % [rows.size(), can_log.rows.size()], 580, 158, UiTheme.C_ACCENT, 13)
	var last_line = can_log.last_line if can_log.last_line != "" else "WAIT UDP PACKETS"
	_draw_text(canvas, font, last_line, 36, 224, UiTheme.C_TEXT, 12, HORIZONTAL_ALIGNMENT_LEFT, 680)

	_draw_action_rail(canvas, font, t, Rect2(18, 268, 188, 226), action_labels, selected_index)
	_draw_panel(canvas, Rect2(224, 268, 478, 372), UiTheme.C_PANEL, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("can_log"), 242, 288, UiTheme.C_DIM, 14)
	if rows.is_empty():
		_draw_text(canvas, font, t.call("can_empty"), 242, 332, UiTheme.C_TEXT, 15)
		return
	var start = max(0, rows.size() - 9)
	var y = 322.0
	for i in range(start, rows.size()):
		var row: Dictionary = rows[i]
		var row_rect = Rect2(240, y - 2, 444, 28)
		canvas.draw_rect(row_rect, UiTheme.C_INPUT, true)
		canvas.draw_rect(row_rect, UiTheme.C_LINE, false, 1.0)
		_draw_text(canvas, font, str(row.get("line", "")), 250, y + 5, UiTheme.C_TEXT, 11, HORIZONTAL_ALIGNMENT_LEFT, 420)
		y += 34


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
