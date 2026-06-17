extends RefCounted

const AppSettings = preload("res://scripts/settings.gd")
const UiTheme = preload("res://scripts/theme/ui_theme.gd")


static func draw_background(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(0, 0, 720, 720), UiTheme.C_BG, true)
	for y in range(0, 720, 24):
		canvas.draw_line(Vector2(0, y), Vector2(720, y), Color(UiTheme.C_GRID, 0.22), 1.0)
	for x in range(0, 720, 24):
		canvas.draw_line(Vector2(x, 0), Vector2(x, 720), Color(UiTheme.C_GRID, 0.12), 1.0)
	canvas.draw_circle(Vector2(610, 90), 150, Color(UiTheme.C_ACCENT_2, 0.055))
	canvas.draw_circle(Vector2(110, 660), 170, Color(UiTheme.C_ACCENT, 0.045))


static func draw_header(canvas: CanvasItem, font: Font, t: Callable, motor, last_rx_msec: int, udp_ready: bool, selected_node_id: int) -> void:
	_draw_panel(canvas, Rect2(14, 12, 692, 64), UiTheme.C_PANEL, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("app_title"), 30, 28, UiTheme.C_TEXT, 20)
	var link = motor.alive or (last_rx_msec > 0 and Time.get_ticks_msec() - last_rx_msec <= 1500)
	_draw_status_chip(canvas, font, Rect2(505, 23, 84, 24), "LINK", link)
	_draw_status_chip(canvas, font, Rect2(598, 23, 84, 24), "UDP", udp_ready)
	_draw_text(canvas, font, "%d ms" % AppSettings.HEARTBEAT_INTERVAL_MS, 622, 56, UiTheme.C_DIM, 10)
	_draw_text(canvas, font, t.call("header_subtitle") % selected_node_id, 32, 56, UiTheme.C_TEXT, 10)


static func draw_tabs(canvas: CanvasItem, font: Font, tab_keys: Array, current_tab: int, tab_name: Callable) -> void:
	var gap = 14.0
	var tab_w = (684.0 - gap * float(tab_keys.size() - 1)) / float(tab_keys.size())
	var x = 18.0
	for i in tab_keys.size():
		var rect = Rect2(x, 88, tab_w, 38)
		var active = i == current_tab
		canvas.draw_rect(rect, UiTheme.C_ACCENT if active else UiTheme.C_PANEL_2, true)
		canvas.draw_rect(rect, UiTheme.C_ACCENT if active else UiTheme.C_LINE, false, 1.0)
		_draw_text(canvas, font, tab_name.call(i), rect.position.x, rect.position.y + 10, UiTheme.C_TEXT, 12, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		x += tab_w + gap


static func draw_status_overlay(canvas: CanvasItem, font: Font, status) -> void:
	if not status.is_visible():
		return
	var color = UiTheme.C_ACCENT
	if status.kind == "warn":
		color = UiTheme.C_WARN
	elif status.kind == "error":
		color = UiTheme.C_RED
	var rect = Rect2(110, 622, 500, 42)
	canvas.draw_rect(rect, Color(UiTheme.C_INPUT, 0.96), true)
	canvas.draw_rect(rect, color, false, 2.0)
	_draw_text(canvas, font, status.message, rect.position.x, rect.position.y + 13, color, 14, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


static func draw_footer(canvas: CanvasItem, font: Font, t: Callable) -> void:
	_draw_panel(canvas, Rect2(14, 670, 692, 36), UiTheme.C_PANEL, UiTheme.C_LINE)
	_draw_text(canvas, font, t.call("footer"), 24, 681, UiTheme.C_DIM, 12)


static func _draw_status_chip(canvas: CanvasItem, font: Font, rect: Rect2, label: String, ok: bool) -> void:
	var color = UiTheme.C_GREEN if ok else UiTheme.C_RED
	canvas.draw_rect(rect, Color(color, 0.18), true)
	canvas.draw_rect(rect, color, false, 1.0)
	_draw_text(canvas, font, label, rect.position.x, rect.position.y + 7, color, 10, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


static func _draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color) -> void:
	canvas.draw_rect(rect, fill, true)
	canvas.draw_rect(rect, border, false, 1.0)
	canvas.draw_line(rect.position, rect.position + Vector2(18, 0), UiTheme.C_ACCENT, 2.0)
	canvas.draw_line(rect.position, rect.position + Vector2(0, 18), UiTheme.C_ACCENT, 2.0)
	canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - 18, rect.position.y), UiTheme.C_ACCENT_2, 2.0)
	canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + 18), UiTheme.C_ACCENT_2, 2.0)


static func _draw_text(canvas: CanvasItem, font: Font, text: String, x: float, y: float, color: Color, font_size: int = 16, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if font == null:
		return
	canvas.draw_string(font, Vector2(x, y + font_size), text, align, width, font_size, color)
