extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")
const UiConfig = preload("res://scripts/app/ui_config.gd")

const LOG_ROW_START_Y: float = 322.0
const LOG_ROW_RECT_X: float = 240.0
const LOG_ROW_WIDTH: float = 444.0
const LOG_ROW_HEIGHT: float = 28.0
const LOG_ROW_STEP: float = 34.0


static func draw(canvas: CanvasItem, font: Font, t: Callable, can_log, action_labels: Array, selected_index: int) -> void:
	AppChrome.draw_panel(canvas, UiConfig.CAN_HEADER_RECT, UiTheme.C_PANEL, UiTheme.C_LINE)
	AppChrome.draw_text(canvas, font, t.call("can_header"), 36, 158, UiTheme.C_ACCENT, 13)
	AppChrome.draw_text(canvas, font, t.call("can_filter_label"), 36, 194, UiTheme.C_DIM, 13)
	var input_rect = UiConfig.CAN_FILTER_RECT
	canvas.draw_rect(input_rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(input_rect, UiTheme.C_LINE, false, 1.0)
	var filter_text = can_log.filter if can_log.filter != "" else t.call("can_all")
	var filter_color = UiTheme.C_TEXT if can_log.filter != "" else UiTheme.C_DIM_2
	AppChrome.draw_text(canvas, font, filter_text, input_rect.position.x + 10, input_rect.position.y + 7, filter_color, 12)
	if can_log.paused:
		AppChrome.draw_text(canvas, font, t.call("can_paused"), 604, 194, UiTheme.C_WARN, 12)
	var rows: Array[Dictionary] = can_log.recent_matching_rows()
	AppChrome.draw_text(canvas, font, "RX %d/%d" % [can_log.matching_count(), can_log.row_count()], 580, 158, UiTheme.C_ACCENT, 13)
	var last_line = can_log.last_line if can_log.last_line != "" else "WAIT UDP PACKETS"
	AppChrome.draw_text(canvas, font, last_line, 36, 224, UiTheme.C_TEXT, 12, HORIZONTAL_ALIGNMENT_LEFT, 680)

	AppChrome.draw_action_rail(canvas, font, t, UiConfig.CAN_ACTION_RAIL_RECT, action_labels, selected_index)
	AppChrome.draw_panel(canvas, UiConfig.CAN_LOG_RECT, UiTheme.C_PANEL, UiTheme.C_LINE)
	AppChrome.draw_text(canvas, font, t.call("can_log"), 242, 288, UiTheme.C_DIM, 14)
	if rows.is_empty():
		AppChrome.draw_text(canvas, font, t.call("can_empty"), 242, 332, UiTheme.C_TEXT, 15)
		return
	var y = LOG_ROW_START_Y
	for row: Dictionary in rows:
		var row_rect = Rect2(LOG_ROW_RECT_X, y - 2, LOG_ROW_WIDTH, LOG_ROW_HEIGHT)
		canvas.draw_rect(row_rect, UiTheme.C_INPUT, true)
		canvas.draw_rect(row_rect, UiTheme.C_LINE, false, 1.0)
		AppChrome.draw_text(canvas, font, str(row.get("line", "")), 250, y + 5, UiTheme.C_TEXT, 11, HORIZONTAL_ALIGNMENT_LEFT, 420)
		y += LOG_ROW_STEP
