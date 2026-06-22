extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")

const DIALOG_RECT := Rect2(78, 54, 564, 528)
const OPTION_START_Y := 214.0
const OPTION_STEP := 112.0
const OPTION_RECT_X := 108.0
const OPTION_SIZE := Vector2(504, 88)
const HINT_RECT := Rect2(78, 610, 564, 48)


static func draw(
	canvas: CanvasItem,
	font: Font,
	t: Callable,
	mode_options: Array,
	selected_index: int
) -> void:
	AppChrome.draw_panel(canvas, DIALOG_RECT, UiTheme.C_PANEL, UiTheme.C_LINE)
	AppChrome.draw_text(canvas, font, t.call("mode_title"), 108, 92, UiTheme.C_TEXT, 24)
	AppChrome.draw_text(canvas, font, t.call("mode_subtitle"), 108, 138, UiTheme.C_DIM, 14)
	for i in mode_options.size():
		var option: Dictionary = mode_options[i]
		var rect = Rect2(Vector2(OPTION_RECT_X, OPTION_START_Y + i * OPTION_STEP), OPTION_SIZE)
		canvas.draw_rect(rect, UiTheme.C_INPUT, true)
		canvas.draw_rect(rect, UiTheme.C_LINE, false, 1.0)
		AppChrome.draw_text(
			canvas,
			font,
			"%s  ·  %s" % [
				t.call(str(option.get("title_key", ""))),
				t.call(str(option.get("desc_key", ""))),
			],
			rect.position.x + 18,
			rect.position.y + 31,
			UiTheme.C_TEXT,
			12
		)
	var selected_rect = Rect2(
		Vector2(OPTION_RECT_X, OPTION_START_Y + selected_index * OPTION_STEP),
		OPTION_SIZE
	)
	canvas.draw_rect(selected_rect, UiTheme.C_ACCENT, false, 2.0)
	canvas.draw_rect(
		Rect2(selected_rect.position.x, selected_rect.position.y, 6, selected_rect.size.y),
		UiTheme.C_ACCENT,
		true
	)
	AppChrome.draw_panel(canvas, HINT_RECT, UiTheme.C_INPUT, UiTheme.C_LINE)
	AppChrome.draw_text(
		canvas, font, t.call("mode_hint"), HINT_RECT.position.x,
		HINT_RECT.position.y + 14, UiTheme.C_DIM, 14,
		HORIZONTAL_ALIGNMENT_CENTER, HINT_RECT.size.x
	)
