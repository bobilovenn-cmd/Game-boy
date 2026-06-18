extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")


static func draw(canvas: CanvasItem, font: Font, t: Callable, can_log, action_labels: Array, selected_index: int) -> void:
	AppChrome.draw_panel(canvas, Rect2(18, 140, 684, 108), UiTheme.C_PANEL, UiTheme.C_LINE)
	AppChrome.draw_text(canvas, font, t.call("can_header"), 36, 158, UiTheme.C_ACCENT, 13)
	AppChrome.draw_text(canvas, font, t.call("can_filter_label"), 36, 194, UiTheme.C_DIM, 13)
	var input_rect = Rect2(112, 188, 474, 30)
	canvas.draw_rect(input_rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(input_rect, UiTheme.C_LINE, false, 1.0)
	var filter_text = can_log.filter if can_log.filter != "" else t.call("can_all")
	var filter_color = UiTheme.C_TEXT if can_log.filter != "" else UiTheme.C_DIM_2
	AppChrome.draw_text(canvas, font, filter_text, input_rect.position.x + 10, input_rect.position.y + 7, filter_color, 12)
	if can_log.paused:
		AppChrome.draw_text(canvas, font, t.call("can_paused"), 604, 194, UiTheme.C_WARN, 12)
	var rows = can_log.filtered_rows()
	AppChrome.draw_text(canvas, font, "RX %d/%d" % [rows.size(), can_log.rows.size()], 580, 158, UiTheme.C_ACCENT, 13)
	var last_line = can_log.last_line if can_log.last_line != "" else "WAIT UDP PACKETS"
	AppChrome.draw_text(canvas, font, last_line, 36, 224, UiTheme.C_TEXT, 12, HORIZONTAL_ALIGNMENT_LEFT, 680)

	AppChrome.draw_action_rail(canvas, font, t, Rect2(18, 268, 188, 226), action_labels, selected_index)
	AppChrome.draw_panel(canvas, Rect2(224, 268, 478, 372), UiTheme.C_PANEL, UiTheme.C_LINE)
	AppChrome.draw_text(canvas, font, t.call("can_log"), 242, 288, UiTheme.C_DIM, 14)
	if rows.is_empty():
		AppChrome.draw_text(canvas, font, t.call("can_empty"), 242, 332, UiTheme.C_TEXT, 15)
		return
	var start = max(0, rows.size() - 9)
	var y = 322.0
	for i in range(start, rows.size()):
		var row: Dictionary = rows[i]
		var row_rect = Rect2(240, y - 2, 444, 28)
		canvas.draw_rect(row_rect, UiTheme.C_INPUT, true)
		canvas.draw_rect(row_rect, UiTheme.C_LINE, false, 1.0)
		AppChrome.draw_text(canvas, font, str(row.get("line", "")), 250, y + 5, UiTheme.C_TEXT, 11, HORIZONTAL_ALIGNMENT_LEFT, 420)
		y += 34
