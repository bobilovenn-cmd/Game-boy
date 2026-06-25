extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")

const DIALOG_RECT := Rect2(78, 58, 564, 548)
const INPUT_HORIZONTAL_MARGIN: float = 72.0
const INPUT_TOP_OFFSET: float = 126.0
const INPUT_HEIGHT: float = 58.0
const KEY_SIZE := Vector2(106, 42)
const KEY_GAP: float = 12.0
const KEYBOARD_CENTER_X: float = 360.0
const KEYBOARD_TOP_OFFSET: float = 226.0
const BACK_KEY: String = "BACK"


static func draw(canvas: CanvasItem, font: Font, t: Callable, numeric_input, key_rows: Array, viewport_size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport_size), UiTheme.C_BG, true)
	var rect = DIALOG_RECT
	canvas.draw_rect(rect, UiTheme.C_BG_2, true)
	canvas.draw_rect(rect, UiTheme.C_ACCENT, false, 2.0)
	canvas.draw_line(rect.position, rect.position + Vector2(28, 0), UiTheme.C_ACCENT, 3.0)
	canvas.draw_line(rect.position, rect.position + Vector2(0, 28), UiTheme.C_ACCENT, 3.0)
	var title_key = "motion_speed_title" if numeric_input.kind == "speed" else "motion_position_title"
	var hint_key = "motion_speed_hint" if numeric_input.kind == "speed" else "motion_position_hint"
	if numeric_input.kind == "node_change":
		title_key = "cfg_node_input_title"
		hint_key = "cfg_node_input_hint"
	AppChrome.draw_text(canvas, font, t.call(title_key), rect.position.x + 30, rect.position.y + 34, UiTheme.C_TEXT, 24)
	AppChrome.draw_text(canvas, font, t.call(hint_key), rect.position.x + 30, rect.position.y + 78, UiTheme.C_DIM, 14)

	var input_rect = Rect2(rect.position.x + INPUT_HORIZONTAL_MARGIN, rect.position.y + INPUT_TOP_OFFSET, rect.size.x - INPUT_HORIZONTAL_MARGIN * 2.0, INPUT_HEIGHT)
	canvas.draw_rect(input_rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(input_rect, UiTheme.C_LINE, false, 1.0)
	var value_text = numeric_input.value if numeric_input.value != "" else "--"
	var value_color = UiTheme.C_ACCENT if numeric_input.value != "" else UiTheme.C_DIM_2
	AppChrome.draw_text(canvas, font, value_text, input_rect.position.x, input_rect.position.y + 15, value_color, 22, HORIZONTAL_ALIGNMENT_CENTER, input_rect.size.x)
	if numeric_input.kind == "speed":
		AppChrome.draw_text(canvas, font, "speed", input_rect.end.x - 66, input_rect.position.y + 20, UiTheme.C_DIM, 12)
	elif numeric_input.kind == "node_change":
		AppChrome.draw_text(canvas, font, "node", input_rect.end.x - 58, input_rect.position.y + 20, UiTheme.C_DIM, 12)

	var y = rect.position.y + KEYBOARD_TOP_OFFSET
	for row_index in key_rows.size():
		var row: Array = key_rows[row_index]
		var row_w = float(row.size()) * KEY_SIZE.x + float(row.size() - 1) * KEY_GAP
		var x = KEYBOARD_CENTER_X - row_w * 0.5
		for col_index in row.size():
			var r = Rect2(Vector2(x + col_index * (KEY_SIZE.x + KEY_GAP), y), KEY_SIZE)
			canvas.draw_rect(r, UiTheme.C_INPUT, true)
			canvas.draw_rect(r, UiTheme.C_LINE, false, 1.0)
			AppChrome.draw_text(canvas, font, str(row[col_index]), r.position.x, r.position.y + 11, UiTheme.C_TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += KEY_SIZE.y + KEY_GAP

	var selected_row: Array = key_rows[numeric_input.key_row]
	var selected_row_w = float(selected_row.size()) * KEY_SIZE.x + float(selected_row.size() - 1) * KEY_GAP
	var selected_x = KEYBOARD_CENTER_X - selected_row_w * 0.5 + numeric_input.key_col * (KEY_SIZE.x + KEY_GAP)
	var selected_y = rect.position.y + KEYBOARD_TOP_OFFSET + numeric_input.key_row * (KEY_SIZE.y + KEY_GAP)
	var selected_rect = Rect2(Vector2(selected_x, selected_y), KEY_SIZE)
	var selected_key = str(key_rows[numeric_input.key_row][numeric_input.key_col])
	var selected_color = UiTheme.C_WARN if selected_key == BACK_KEY else UiTheme.C_ACCENT
	canvas.draw_rect(selected_rect, selected_color, false, 2.0)
	canvas.draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y), selected_color, true)
