extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")


static func draw(canvas: CanvasItem, font: Font, t: Callable, config_items: Array, selected_index: int, result_msg: String) -> void:
	_draw_panel(canvas, Rect2(18, 140, 684, 386), UiTheme.C_PANEL, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("config_header"), 36, 158, UiTheme.C_ACCENT, 13)
	var y = 194.0
	for i in config_items.size():
		var item: Array = config_items[i]
		var row_rect = Rect2(34, y, 652, 32)
		canvas.draw_rect(row_rect, UiTheme.C_INPUT, true)
		canvas.draw_rect(row_rect, UiTheme.C_LINE, false, 1.0)
		_draw_text(canvas, font, t.call(item[0]), 46, y + 9, UiTheme.C_TEXT, 12)
		_draw_text(canvas, font, "0x%s:%d" % [_hex(item[1]), item[2]], 288, y + 9, UiTheme.C_DIM, 12)
		_draw_text(canvas, font, t.call(item[3]), 408, y + 9, UiTheme.C_DIM, 12)
		y += 36
	var selected_rect = Rect2(34, 194 + selected_index * 36, 652, 32)
	canvas.draw_rect(selected_rect, UiTheme.C_ACCENT, false, 2.0)
	canvas.draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y), UiTheme.C_ACCENT, true)
	_draw_panel(canvas, Rect2(18, 542, 684, 62), UiTheme.C_INPUT, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("sdo_result"), 36, 562, UiTheme.C_TEXT, 11)
	var text = result_msg if result_msg != "" else t.call("no_sdo")
	_draw_text(canvas, font, text, 36, 586, UiTheme.C_TEXT, 11)


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


static func _hex(value: int, width: int = 4) -> String:
	return ("%X" % value).pad_zeros(width)
