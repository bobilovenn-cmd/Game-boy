extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")

const DIALOG_RECT := Rect2(78, 54, 564, 528)
const OPTION_START_Y: float = 200.0
const OPTION_STEP: float = 74.0
const OPTION_RECT_X: float = 128.0
const OPTION_SIZE := Vector2(464, 52)
const HINT_RECT := Rect2(78, 610, 564, 48)
const SHUTDOWN_OPTION_INDEX: int = 2
const HINT_FONT_SIZE: int = 15


static func draw(canvas: CanvasItem, font: Font, t: Callable, selected_language: int) -> void:
	AppChrome.draw_panel(canvas, DIALOG_RECT, UiTheme.C_PANEL, UiTheme.C_LINE)
	AppChrome.draw_text(canvas, font, t.call("language_title"), 108, 96, UiTheme.C_TEXT, 24)
	var labels = [t.call("language_zh"), t.call("language_en"), t.call("language_shutdown")]
	for i in labels.size():
		var rect = Rect2(Vector2(OPTION_RECT_X, OPTION_START_Y + i * OPTION_STEP), OPTION_SIZE)
		AppChrome.draw_rounded_rect(canvas, rect, UiTheme.C_INPUT, UiTheme.C_LINE, 7.0)
		var is_back = i == SHUTDOWN_OPTION_INDEX
		AppChrome.draw_text(canvas, font, labels[i], rect.position.x, rect.position.y + 15, UiTheme.C_DIM if is_back else UiTheme.C_TEXT, 17, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	var selected_rect = Rect2(Vector2(OPTION_RECT_X, OPTION_START_Y + selected_language * OPTION_STEP), OPTION_SIZE)
	var selected_color = UiTheme.C_WARN if selected_language == SHUTDOWN_OPTION_INDEX else UiTheme.C_ACCENT
	AppChrome.draw_rounded_rect(
		canvas, selected_rect, Color(UiTheme.C_INPUT, 0.0), selected_color, 7.0, 2
	)
	AppChrome.draw_rounded_rect(
		canvas,
		Rect2(selected_rect.position.x, selected_rect.position.y, 6, selected_rect.size.y),
		selected_color,
		selected_color,
		3.0
	)
	AppChrome.draw_panel(canvas, HINT_RECT, UiTheme.C_INPUT, UiTheme.C_LINE)
