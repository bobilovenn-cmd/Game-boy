extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")


static func draw(canvas: CanvasItem, font: Font, t: Callable, ota, ota_items: Array, selected_index: int) -> void:
	_draw_panel(canvas, Rect2(18, 140, 684, 120), UiTheme.C_PANEL, UiTheme.C_LINE)
	var fw = ota.firmware_name if ota.firmware_name != "" else t.call("no_firmware")
	var meta = t.call("copy_firmware")
	if ota.firmware_size > 0:
		meta = "Size %.1f KB  MD5 %s..." % [float(ota.firmware_size) / 1024.0, ota.firmware_md5.substr(0, 16)]
	_draw_text(canvas, font, t.call("firmware_update") % [fw, meta], 36, 154, UiTheme.C_ACCENT, 12)

	var upload_rect = Rect2(36, 206, 650, 36)
	canvas.draw_rect(upload_rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(upload_rect, UiTheme.C_LINE, false, 1.0)
	_draw_text(canvas, font, t.call("ota_upload_panel"), upload_rect.position.x + 12, upload_rect.position.y + 9, UiTheme.C_TEXT, 13)
	_draw_text(canvas, font, t.call("ota_upload_hint"), upload_rect.position.x + 338, upload_rect.position.y + 9, UiTheme.C_DIM, 11)
	if selected_index == 0:
		canvas.draw_rect(upload_rect, UiTheme.C_ACCENT, false, 2.0)
		canvas.draw_rect(Rect2(upload_rect.position.x, upload_rect.position.y, 5, upload_rect.size.y), UiTheme.C_ACCENT, true)

	var ota_rail_selection = selected_index - 1
	_draw_action_rail(canvas, font, t, Rect2(18, 284, 260, 226), _texts(t, ota_items.slice(1, 5)), ota_rail_selection)
	_draw_panel(canvas, Rect2(300, 284, 402, 226), UiTheme.C_PANEL, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("transfer_state") % ota.state.to_upper(), 318, 306, UiTheme.C_TEXT, 11)
	_draw_progress_bar(canvas, font, Rect2(318, 382, 360, 30), ota.progress, "%d%%  %.1f KB/s" % [ota.progress, ota.speed_kbps])
	_draw_text(canvas, font, t.call("target_dongle"), 318, 446, UiTheme.C_TEXT, 11)

	_draw_panel(canvas, Rect2(18, 548, 684, 92), UiTheme.C_INPUT, UiTheme.C_LINE)
	var log_head = t.call("ota_log")
	if not ota.log.is_empty():
		log_head = t.call("ota_log_line") % ota.log.back()
	_draw_text(canvas, font, log_head, 36, 568, UiTheme.C_TEXT, 11)


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


static func _draw_progress_bar(canvas: CanvasItem, font: Font, rect: Rect2, progress: int, label: String) -> void:
	canvas.draw_rect(rect, UiTheme.C_INPUT, true)
	var bar_w = (rect.size.x - 4) * clamp(progress, 0, 100) / 100.0
	if bar_w > 0:
		canvas.draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, bar_w, rect.size.y - 4), UiTheme.C_ACCENT, true)
	canvas.draw_rect(rect, UiTheme.C_LINE, false, 1.0)
	_draw_text(canvas, font, label, rect.position.x, rect.position.y + 9, UiTheme.C_TEXT, 11, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


static func _draw_text(canvas: CanvasItem, font: Font, text: String, x: float, y: float, color: Color, font_size: int = 16, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if font == null:
		return
	canvas.draw_string(font, Vector2(x, y + font_size), text, align, width, font_size, color)


static func _texts(t: Callable, keys: Array) -> Array[String]:
	var values: Array[String] = []
	for key in keys:
		values.append(t.call(str(key)))
	return values
