extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")

const DIALOG_RECT := Rect2(78, 54, 564, 528)
const OPTION_START_Y := 214.0
const OPTION_STEP := 112.0
const OPTION_RECT_X := 108.0
const OPTION_SIZE := Vector2(504, 88)
const HINT_RECT := Rect2(78, 610, 564, 48)
const OPTION_TITLE_FONT_SIZE: int = 24
const OPTION_DESCRIPTION_FONT_SIZE: int = 13
const HINT_FONT_SIZE: int = 15


static func draw(
	canvas: CanvasItem,
	font: Font,
	t: Callable,
	mode_options: Array,
	selected_index: int
) -> void:
	AppChrome.draw_panel(canvas, DIALOG_RECT, UiTheme.C_PANEL, UiTheme.C_LINE)
	AppChrome.draw_text(canvas, font, t.call("mode_title"), 108, 92, UiTheme.C_TEXT, 24)
	for i in mode_options.size():
		var option: Dictionary = mode_options[i]
		var rect = Rect2(Vector2(OPTION_RECT_X, OPTION_START_Y + i * OPTION_STEP), OPTION_SIZE)
		AppChrome.draw_rounded_rect(canvas, rect, UiTheme.C_INPUT, UiTheme.C_LINE, 8.0)
		AppChrome.draw_text(
			canvas,
			font,
			t.call(str(option.get("title_key", ""))),
			rect.position.x + 20,
			rect.position.y + 13,
			UiTheme.C_TEXT,
			OPTION_TITLE_FONT_SIZE
		)
		var description_rect := Rect2(
			rect.position + Vector2(16, 48),
			Vector2(rect.size.x - 32, 28)
		)
		AppChrome.draw_rounded_rect(
			canvas, description_rect, UiTheme.C_PANEL, UiTheme.C_PANEL, 5.0
		)
	var selected_rect = Rect2(
		Vector2(OPTION_RECT_X, OPTION_START_Y + selected_index * OPTION_STEP),
		OPTION_SIZE
	)
	AppChrome.draw_rounded_rect(
		canvas, selected_rect, Color(UiTheme.C_INPUT, 0.0), UiTheme.C_ACCENT, 8.0, 2
	)
	AppChrome.draw_rounded_rect(
		canvas,
		Rect2(selected_rect.position.x, selected_rect.position.y, 6, selected_rect.size.y),
		UiTheme.C_ACCENT,
		UiTheme.C_ACCENT,
		3.0
	)
	AppChrome.draw_panel(canvas, HINT_RECT, UiTheme.C_INPUT, UiTheme.C_LINE)
