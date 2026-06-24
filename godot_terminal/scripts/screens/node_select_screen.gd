extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")

const DIALOG_RECT := Rect2(78, 54, 564, 548)
const NODE_INPUT_RECT := Rect2(180, 198, 360, 58)
const KEY_SIZE := Vector2(106, 42)
const KEY_GAP: float = 12.0
const KEYBOARD_CENTER_X: float = 360.0
const KEYBOARD_START_Y: float = 292.0
const HINT_RECT := Rect2(78, 626, 564, 42)
const ERROR_RECT := Rect2(178, 678, 364, 30)
const BACK_KEY: String = "BACK"
const HINT_FONT_SIZE: int = 14


static func draw(canvas: CanvasItem, font: Font, t: Callable, key_rows: Array, selector: RefCounted) -> void:
	AppChrome.draw_panel(canvas, DIALOG_RECT, UiTheme.C_PANEL, UiTheme.C_LINE)
	AppChrome.draw_text(canvas, font, t.call("node_title"), 108, 92, UiTheme.C_TEXT, 24)

	var input_rect = NODE_INPUT_RECT
	AppChrome.draw_rounded_rect(canvas, input_rect, UiTheme.C_INPUT, UiTheme.C_LINE, 7.0)
	var node_text = selector.input if selector.input != "" else "--"
	AppChrome.draw_text(canvas, font, node_text, input_rect.position.x, input_rect.position.y + 15, UiTheme.C_ACCENT if selector.input != "" else UiTheme.C_DIM_2, 22, HORIZONTAL_ALIGNMENT_CENTER, input_rect.size.x)

	var y = KEYBOARD_START_Y
	for row_index in key_rows.size():
		var row: Array = key_rows[row_index]
		var row_w = float(row.size()) * KEY_SIZE.x + float(row.size() - 1) * KEY_GAP
		var x = KEYBOARD_CENTER_X - row_w * 0.5
		for col_index in row.size():
			var r = Rect2(Vector2(x + col_index * (KEY_SIZE.x + KEY_GAP), y), KEY_SIZE)
			AppChrome.draw_rounded_rect(canvas, r, UiTheme.C_INPUT, UiTheme.C_LINE, 6.0)
			AppChrome.draw_text(canvas, font, str(row[col_index]), r.position.x, r.position.y + 11, UiTheme.C_TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += KEY_SIZE.y + KEY_GAP

	var selected_row: Array = key_rows[selector.key_row]
	var selected_row_w = float(selected_row.size()) * KEY_SIZE.x + float(selected_row.size() - 1) * KEY_GAP
	var selected_x = KEYBOARD_CENTER_X - selected_row_w * 0.5 + selector.key_col * (KEY_SIZE.x + KEY_GAP)
	var selected_y = KEYBOARD_START_Y + selector.key_row * (KEY_SIZE.y + KEY_GAP)
	var selected_rect = Rect2(Vector2(selected_x, selected_y), KEY_SIZE)
	var selected_key = str(key_rows[selector.key_row][selector.key_col])
	var selected_color = UiTheme.C_WARN if selected_key == BACK_KEY else UiTheme.C_ACCENT
	AppChrome.draw_rounded_rect(
		canvas, selected_rect, Color(UiTheme.C_INPUT, 0.0), selected_color, 6.0, 2
	)
	AppChrome.draw_rounded_rect(
		canvas,
		Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y),
		selected_color,
		selected_color,
		2.5
	)

	AppChrome.draw_panel(canvas, HINT_RECT, UiTheme.C_INPUT, UiTheme.C_LINE)
	if selector.error_msg != "":
		var err_rect = ERROR_RECT
		AppChrome.draw_rounded_rect(
			canvas, err_rect, Color(UiTheme.C_RED, 0.15), UiTheme.C_RED, 6.0
		)
		AppChrome.draw_text(canvas, font, selector.error_msg, err_rect.position.x, err_rect.position.y + 7, UiTheme.C_RED, 13, HORIZONTAL_ALIGNMENT_CENTER, err_rect.size.x)
