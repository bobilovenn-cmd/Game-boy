extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")


static func draw(canvas: CanvasItem, font: Font, t: Callable, numeric_input, key_rows: Array, viewport_size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport_size), UiTheme.C_BG, true)
	var rect = Rect2(78, 58, 564, 548)
	canvas.draw_rect(rect, UiTheme.C_BG_2, true)
	canvas.draw_rect(rect, UiTheme.C_ACCENT, false, 2.0)
	canvas.draw_line(rect.position, rect.position + Vector2(28, 0), UiTheme.C_ACCENT, 3.0)
	canvas.draw_line(rect.position, rect.position + Vector2(0, 28), UiTheme.C_ACCENT, 3.0)
	var title_key = "motion_speed_title" if numeric_input.kind == "speed" else "motion_position_title"
	var hint_key = "motion_speed_hint" if numeric_input.kind == "speed" else "motion_position_hint"
	_draw_text(canvas, font, t.call(title_key), rect.position.x + 30, rect.position.y + 34, UiTheme.C_TEXT, 24)
	_draw_text(canvas, font, t.call(hint_key), rect.position.x + 30, rect.position.y + 78, UiTheme.C_DIM, 14)

	var input_rect = Rect2(rect.position.x + 72, rect.position.y + 126, rect.size.x - 144, 58)
	canvas.draw_rect(input_rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(input_rect, UiTheme.C_LINE, false, 1.0)
	var value_text = numeric_input.value if numeric_input.value != "" else "--"
	var value_color = UiTheme.C_ACCENT if numeric_input.value != "" else UiTheme.C_DIM_2
	_draw_text(canvas, font, value_text, input_rect.position.x, input_rect.position.y + 15, value_color, 22, HORIZONTAL_ALIGNMENT_CENTER, input_rect.size.x)
	if numeric_input.kind == "speed":
		_draw_text(canvas, font, "speed", input_rect.end.x - 66, input_rect.position.y + 20, UiTheme.C_DIM, 12)

	var key_w = 106.0
	var key_h = 42.0
	var gap = 12.0
	var y = rect.position.y + 226
	for row_index in key_rows.size():
		var row: Array = key_rows[row_index]
		var row_w = float(row.size()) * key_w + float(row.size() - 1) * gap
		var x = 360.0 - row_w * 0.5
		for col_index in row.size():
			var r = Rect2(x + col_index * (key_w + gap), y, key_w, key_h)
			canvas.draw_rect(r, UiTheme.C_INPUT, true)
			canvas.draw_rect(r, UiTheme.C_LINE, false, 1.0)
			_draw_text(canvas, font, str(row[col_index]), r.position.x, r.position.y + 11, UiTheme.C_TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += key_h + gap

	var selected_row: Array = key_rows[numeric_input.key_row]
	var selected_row_w = float(selected_row.size()) * key_w + float(selected_row.size() - 1) * gap
	var selected_x = 360.0 - selected_row_w * 0.5 + numeric_input.key_col * (key_w + gap)
	var selected_y = rect.position.y + 226 + numeric_input.key_row * (key_h + gap)
	var selected_rect = Rect2(selected_x, selected_y, key_w, key_h)
	var selected_key = str(key_rows[numeric_input.key_row][numeric_input.key_col])
	var selected_color = UiTheme.C_WARN if selected_key == "BACK" else UiTheme.C_ACCENT
	canvas.draw_rect(selected_rect, selected_color, false, 2.0)
	canvas.draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y), selected_color, true)


static func _draw_text(canvas: CanvasItem, font: Font, text: String, x: float, y: float, color: Color, font_size: int = 16, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if font == null:
		return
	canvas.draw_string(font, Vector2(x, y + font_size), text, align, width, font_size, color)
