extends RefCounted

const UiTheme = preload("res://scripts/theme/ui_theme.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")


static func draw(canvas: CanvasItem, font: Font, t: Callable, selected_language: int) -> void:
	AppChrome.draw_panel(canvas, Rect2(78, 54, 564, 528), UiTheme.C_PANEL, UiTheme.C_LINE)
	AppChrome.draw_text(canvas, font, t.call("language_title"), 108, 96, UiTheme.C_TEXT, 24)
	AppChrome.draw_text(canvas, font, t.call("language_subtitle"), 108, 144, UiTheme.C_DIM, 14)
	var labels = [t.call("language_zh"), t.call("language_en"), t.call("language_shutdown")]
	for i in labels.size():
		var rect = Rect2(128, 200 + i * 74, 464, 52)
		canvas.draw_rect(rect, UiTheme.C_INPUT, true)
		canvas.draw_rect(rect, UiTheme.C_LINE, false, 1.0)
		var is_back = i == 2
		AppChrome.draw_text(canvas, font, labels[i], rect.position.x, rect.position.y + 15, UiTheme.C_DIM if is_back else UiTheme.C_TEXT, 17, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	var selected_rect = Rect2(128, 200 + selected_language * 74, 464, 52)
	var selected_color = UiTheme.C_WARN if selected_language == 2 else UiTheme.C_ACCENT
	canvas.draw_rect(selected_rect, selected_color, false, 2.0)
	canvas.draw_rect(Rect2(selected_rect.position.x, selected_rect.position.y, 6, selected_rect.size.y), selected_color, true)
	AppChrome.draw_panel(canvas, Rect2(78, 610, 564, 48), UiTheme.C_INPUT, UiTheme.C_LINE)
	AppChrome.draw_text(canvas, font, t.call("language_hint"), 78, 626, UiTheme.C_DIM, 14, HORIZONTAL_ALIGNMENT_CENTER, 564)
