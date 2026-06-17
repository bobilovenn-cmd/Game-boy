extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")


static func draw(canvas: CanvasItem, font: Font, t: Callable, key_rows: Array, selector: RefCounted) -> void:
	_draw_panel(canvas, Rect2(78, 54, 564, 548), UiTheme.C_PANEL, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("node_title"), 108, 92, UiTheme.C_TEXT, 24)
	_draw_text(canvas, font, t.call("node_subtitle"), 108, 138, UiTheme.C_DIM, 14)
	_draw_text(canvas, font, t.call("node_range"), 108, 164, UiTheme.C_DIM_2, 12)

	var input_rect = Rect2(180, 198, 360, 58)
	canvas.draw_rect(input_rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(input_rect, UiTheme.C_LINE, false, 1.0)
	var node_text = selector.input if selector.input != "" else "--"
	_draw_text(canvas, font, node_text, input_rect.position.x, input_rect.position.y + 15, UiTheme.C_ACCENT if selector.input != "" else UiTheme.C_DIM_2, 22, HORIZONTAL_ALIGNMENT_CENTER, input_rect.size.x)

	var key_w = 106.0
	var key_h = 42.0
	var gap = 12.0
	var y = 292.0
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

	var selected_row: Array = key_rows[selector.key_row]
	var selected_row_w = float(selected_row.size()) * key_w + float(selected_row.size() - 1) * gap
	var selected_x = 360.0 - selected_row_w * 0.5 + selector.key_col * (key_w + gap)
	var selected_y = 292.0 + selector.key_row * (key_h + gap)
	var selected_rect = Rect2(selected_x, selected_y, key_w, key_h)
	var selected_key = str(key_rows[selector.key_row][selector.key_col])
	var selected_color = UiTheme.C_WARN if selected_key == "BACK" else UiTheme.C_ACCENT
	canvas.draw_rect(selected_rect, selected_color, false, 2.0)
	canvas.draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y), selected_color, true)

	_draw_panel(canvas, Rect2(78, 626, 564, 42), UiTheme.C_INPUT, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("node_hint"), 78, 637, UiTheme.C_DIM, 12, HORIZONTAL_ALIGNMENT_CENTER, 564)
	if selector.error_msg != "":
		var err_rect = Rect2(178, 678, 364, 30)
		canvas.draw_rect(err_rect, Color(UiTheme.C_RED, 0.15), true)
		canvas.draw_rect(err_rect, UiTheme.C_RED, false, 1.0)
		_draw_text(canvas, font, selector.error_msg, err_rect.position.x, err_rect.position.y + 7, UiTheme.C_RED, 13, HORIZONTAL_ALIGNMENT_CENTER, err_rect.size.x)


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
