extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")

const DIALOG_RECT := Rect2(28, 72, 664, 548)
const INPUT_HORIZONTAL_MARGIN: float = 44.0
const INPUT_TOP_OFFSET: float = 102.0
const INPUT_HEIGHT: float = 52.0
const KEY_HEIGHT: float = 30.0
const KEY_GAP: float = 6.0
const KEYBOARD_TOP_OFFSET: float = 186.0
const FUNCTION_ROW_INDEX: int = 3
const BOTTOM_ROW_INDEX: int = 4
const STANDARD_KEY_WIDTH: float = 56.0
const FUNCTION_KEY_WIDTH: float = 62.0
const BOTTOM_KEY_WIDTH: float = 58.0


static func draw(canvas: CanvasItem, font: Font, t: Callable, filter_value: String, key_rows: Array, keyboard_row: int, keyboard_col: int, lowercase: bool, viewport_size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport_size), UiTheme.C_BG, true)
	var rect = DIALOG_RECT
	canvas.draw_rect(rect, UiTheme.C_BG_2, true)
	canvas.draw_rect(rect, UiTheme.C_ACCENT, false, 2.0)
	canvas.draw_line(rect.position, rect.position + Vector2(28, 0), UiTheme.C_ACCENT, 3.0)
	canvas.draw_line(rect.position, rect.position + Vector2(0, 28), UiTheme.C_ACCENT, 3.0)
	AppChrome.draw_text(canvas, font, t.call("keyboard_title"), rect.position.x + 22, rect.position.y + 24, UiTheme.C_TEXT, 22)
	AppChrome.draw_text(canvas, font, t.call("keyboard_hint"), rect.position.x + 22, rect.position.y + 62, UiTheme.C_DIM, 13)

	var input_rect = Rect2(rect.position.x + INPUT_HORIZONTAL_MARGIN, rect.position.y + INPUT_TOP_OFFSET, rect.size.x - INPUT_HORIZONTAL_MARGIN * 2.0, INPUT_HEIGHT)
	canvas.draw_rect(input_rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(input_rect, UiTheme.C_LINE, false, 1.0)
	AppChrome.draw_text(canvas, font, t.call("can_filter_label") + ":", input_rect.position.x + 16, input_rect.position.y + 15, UiTheme.C_TEXT, 16)
	var value_text = filter_value if filter_value != "" else t.call("can_all")
	var value_color = UiTheme.C_TEXT if filter_value != "" else UiTheme.C_DIM_2
	AppChrome.draw_text(canvas, font, value_text, input_rect.position.x + 104, input_rect.position.y + 15, value_color, 16)

	var y = rect.position.y + KEYBOARD_TOP_OFFSET
	for row_index in key_rows.size():
		var row: Array = key_rows[row_index]
		var key_w = _key_width(row_index)
		var row_w = float(row.size()) * key_w + float(row.size() - 1) * KEY_GAP
		var x = rect.position.x + (rect.size.x - row_w) * 0.5
		for col_index in row.size():
			var r = Rect2(x + col_index * (key_w + KEY_GAP), y, key_w, KEY_HEIGHT)
			canvas.draw_rect(r, UiTheme.C_PANEL, true)
			canvas.draw_rect(r, UiTheme.C_LINE, false, 1.0)
			var label = _keyboard_key_label(key_rows, row_index, col_index, lowercase)
			AppChrome.draw_text(canvas, font, label, r.position.x, r.position.y + 7, UiTheme.C_TEXT, 11, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += KEY_HEIGHT + KEY_GAP

	var selected_row: Array = key_rows[keyboard_row]
	var selected_key_w = _key_width(keyboard_row)
	var selected_row_w = float(selected_row.size()) * selected_key_w + float(selected_row.size() - 1) * KEY_GAP
	var selected_x = rect.position.x + (rect.size.x - selected_row_w) * 0.5 + keyboard_col * (selected_key_w + KEY_GAP)
	var selected_y = rect.position.y + KEYBOARD_TOP_OFFSET + keyboard_row * (KEY_HEIGHT + KEY_GAP)
	var selected_rect = Rect2(selected_x, selected_y, selected_key_w, KEY_HEIGHT)
	canvas.draw_rect(selected_rect, UiTheme.C_ACCENT, false, 2.0)
	canvas.draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y), UiTheme.C_ACCENT, true)


static func _key_width(row_index: int) -> float:
	if row_index == FUNCTION_ROW_INDEX:
		return FUNCTION_KEY_WIDTH
	if row_index == BOTTOM_ROW_INDEX:
		return BOTTOM_KEY_WIDTH
	return STANDARD_KEY_WIDTH


static func _keyboard_key_value(key_rows: Array, row_index: int, col_index: int, lowercase: bool) -> String:
	var key = str(key_rows[row_index][col_index])
	if key.length() == 1 and "ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(key) and lowercase:
		return key.to_lower()
	return key


static func _keyboard_key_label(key_rows: Array, row_index: int, col_index: int, lowercase: bool) -> String:
	var key = _keyboard_key_value(key_rows, row_index, col_index, lowercase)
	if key == "SHIFT":
		return "abc" if not lowercase else "ABC"
	return key
