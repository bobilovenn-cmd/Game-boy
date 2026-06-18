extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")


static func draw(canvas: CanvasItem, font: Font, t: Callable, ota, ota_items: Array, selected_index: int) -> void:
	AppChrome.draw_panel(canvas, Rect2(18, 140, 684, 120), UiTheme.C_PANEL, UiTheme.C_LINE)
	var fw = ota.firmware_name if ota.firmware_name != "" else t.call("no_firmware")
	var meta = t.call("copy_firmware")
	if ota.firmware_size > 0:
		meta = "Size %.1f KB  MD5 %s..." % [float(ota.firmware_size) / 1024.0, ota.firmware_md5.substr(0, 16)]
	AppChrome.draw_text(canvas, font, t.call("firmware_update") % [fw, meta], 36, 154, UiTheme.C_ACCENT, 12)

	var upload_rect = Rect2(36, 206, 650, 36)
	canvas.draw_rect(upload_rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(upload_rect, UiTheme.C_LINE, false, 1.0)
	AppChrome.draw_text(canvas, font, t.call("ota_upload_panel"), upload_rect.position.x + 12, upload_rect.position.y + 9, UiTheme.C_TEXT, 13)
	AppChrome.draw_text(canvas, font, t.call("ota_upload_hint"), upload_rect.position.x + 338, upload_rect.position.y + 9, UiTheme.C_DIM, 11)
	if selected_index == 0:
		canvas.draw_rect(upload_rect, UiTheme.C_ACCENT, false, 2.0)
		canvas.draw_rect(Rect2(upload_rect.position.x, upload_rect.position.y, 5, upload_rect.size.y), UiTheme.C_ACCENT, true)

	var ota_rail_selection = selected_index - 1
	AppChrome.draw_action_rail(canvas, font, t, Rect2(18, 284, 260, 226), _texts(t, ota_items.slice(1, 5)), ota_rail_selection)
	AppChrome.draw_panel(canvas, Rect2(300, 284, 402, 226), UiTheme.C_PANEL, UiTheme.C_LINE)
	AppChrome.draw_text(canvas, font, t.call("transfer_state") % ota.state.to_upper(), 318, 306, UiTheme.C_TEXT, 11)
	_draw_progress_bar(canvas, font, Rect2(318, 382, 360, 30), ota.progress, "%d%%  %.1f KB/s" % [ota.progress, ota.speed_kbps])
	AppChrome.draw_text(canvas, font, t.call("target_dongle"), 318, 446, UiTheme.C_TEXT, 11)

	AppChrome.draw_panel(canvas, Rect2(18, 548, 684, 92), UiTheme.C_INPUT, UiTheme.C_LINE)
	var log_head = t.call("ota_log")
	if not ota.log.is_empty():
		log_head = t.call("ota_log_line") % ota.log.back()
	AppChrome.draw_text(canvas, font, log_head, 36, 568, UiTheme.C_TEXT, 11)


static func _draw_progress_bar(canvas: CanvasItem, font: Font, rect: Rect2, progress: int, label: String) -> void:
	canvas.draw_rect(rect, UiTheme.C_INPUT, true)
	var bar_w = (rect.size.x - 4) * clamp(progress, 0, 100) / 100.0
	if bar_w > 0:
		canvas.draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, bar_w, rect.size.y - 4), UiTheme.C_ACCENT, true)
	canvas.draw_rect(rect, UiTheme.C_LINE, false, 1.0)
	AppChrome.draw_text(canvas, font, label, rect.position.x, rect.position.y + 9, UiTheme.C_TEXT, 11, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


static func _texts(t: Callable, keys: Array) -> Array[String]:
	var values: Array[String] = []
	for key in keys:
		values.append(t.call(str(key)))
	return values
