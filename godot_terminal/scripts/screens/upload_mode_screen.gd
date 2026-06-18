extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")

const DIALOG_RECT := Rect2(52, 54, 616, 520)
const WIFI_SECTION_Y: float = 160.0
const URL_SECTION_Y: float = 264.0
const SAVE_PATH_SECTION_Y: float = 368.0
const EXIT_BUTTON_RECT := Rect2(128, 598, 464, 52)
const VALUE_TITLE_SIZE := Vector2(150, 30)
const VALUE_RECT_SIZE := Vector2(380, 50)
const VALUE_CENTER_X: float = 360.0
const VALUE_VERTICAL_GAP: float = 8.0


static func draw(canvas: CanvasItem, font: Font, t: Callable, upload_mode: RefCounted) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.get_viewport_rect().size), UiTheme.C_BG, true)
	var rect = DIALOG_RECT
	canvas.draw_rect(rect, UiTheme.C_BG_2, true)
	canvas.draw_rect(rect, UiTheme.C_ACCENT, false, 2.0)
	canvas.draw_line(rect.position, rect.position + Vector2(28, 0), UiTheme.C_ACCENT, 3.0)
	canvas.draw_line(rect.position, rect.position + Vector2(0, 28), UiTheme.C_ACCENT, 3.0)
	AppChrome.draw_text(canvas, font, t.call("upload_title"), rect.position.x + 28, rect.position.y + 30, UiTheme.C_TEXT, 24)
	AppChrome.draw_text(canvas, font, t.call("upload_subtitle"), rect.position.x + 28, rect.position.y + 82, UiTheme.C_TEXT, 15)

	_draw_value_section(canvas, font, t.call("upload_wifi"), upload_mode.ssid, WIFI_SECTION_Y, 21)
	_draw_value_section(canvas, font, t.call("upload_url"), upload_mode.url, URL_SECTION_Y, 17)
	_draw_value_section(canvas, font, t.call("upload_save_path"), "/storage/firmware.bin", SAVE_PATH_SECTION_Y, 17)
	AppChrome.draw_text(canvas, font, t.call("upload_status") + ": " + upload_mode.status, 170, 510, UiTheme.C_TEXT, 14)

	var exit_rect = EXIT_BUTTON_RECT
	canvas.draw_rect(exit_rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(exit_rect, UiTheme.C_LINE, false, 1.0)
	AppChrome.draw_text(canvas, font, t.call("upload_exit"), exit_rect.position.x, exit_rect.position.y + 15, UiTheme.C_TEXT, 17, HORIZONTAL_ALIGNMENT_CENTER, exit_rect.size.x)
	canvas.draw_rect(exit_rect, UiTheme.C_WARN, false, 2.0)
	canvas.draw_rect(Rect2(exit_rect.position.x, exit_rect.position.y, 6, exit_rect.size.y), UiTheme.C_WARN, true)


static func _draw_value_section(canvas: CanvasItem, font: Font, title: String, value: String, y: float, value_size: int) -> void:
	var title_rect = Rect2(Vector2(VALUE_CENTER_X - VALUE_TITLE_SIZE.x * 0.5, y), VALUE_TITLE_SIZE)
	canvas.draw_rect(title_rect, UiTheme.C_INPUT, true)
	canvas.draw_rect(title_rect, UiTheme.C_LINE, false, 1.0)
	AppChrome.draw_text(canvas, font, title, title_rect.position.x, title_rect.position.y + 5, UiTheme.C_TEXT, 17, HORIZONTAL_ALIGNMENT_CENTER, title_rect.size.x)
	var value_rect = Rect2(Vector2(VALUE_CENTER_X - VALUE_RECT_SIZE.x * 0.5, y + VALUE_TITLE_SIZE.y + VALUE_VERTICAL_GAP), VALUE_RECT_SIZE)
	canvas.draw_rect(value_rect, UiTheme.C_BG, true)
	canvas.draw_rect(value_rect, UiTheme.C_BG_2, false, 1.0)
	AppChrome.draw_text(canvas, font, value, value_rect.position.x, value_rect.position.y + 13, UiTheme.C_TEXT, value_size, HORIZONTAL_ALIGNMENT_CENTER, value_rect.size.x)
