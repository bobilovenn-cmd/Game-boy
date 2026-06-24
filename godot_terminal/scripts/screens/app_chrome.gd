extends RefCounted

const AppSettings = preload("res://scripts/settings.gd")
const UiTheme = preload("res://scripts/theme/ui_theme.gd")

const VIEWPORT_SIZE := Vector2(720, 720)
const BACKGROUND_GRID_STEP: int = 24
const HEADER_RECT := Rect2(14, 12, 692, 64)
const TAB_TOP: float = 88.0
const TAB_HEIGHT: float = 38.0
const TAB_TOTAL_WIDTH: float = 684.0
const TAB_START_X: float = 18.0
const TAB_GAP: float = 14.0
const STATUS_OVERLAY_RECT := Rect2(110, 622, 500, 42)
const FOOTER_RECT := Rect2(14, 670, 692, 36)
const PANEL_CORNER_LENGTH: float = 18.0
const PANEL_RADIUS: float = 8.0
const ACTION_RAIL_SIDE_PADDING: float = 14.0
const ACTION_RAIL_TOP_OFFSET: float = 48.0
const ACTION_RAIL_TITLE_OFFSET: float = 18.0
const ACTION_RAIL_BOTTOM_RESERVE: float = 58.0
const ACTION_ROW_MAX_HEIGHT: float = 38.0
const ACTION_ROW_GAP: float = 8.0


static func draw_background(canvas: CanvasItem, show_grid: bool = true) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), UiTheme.C_BG, true)
	if not show_grid:
		return
	for y in range(0, int(VIEWPORT_SIZE.y), BACKGROUND_GRID_STEP):
		canvas.draw_line(Vector2(0, y), Vector2(VIEWPORT_SIZE.x, y), Color(UiTheme.C_GRID, 0.22), 1.0)
	for x in range(0, int(VIEWPORT_SIZE.x), BACKGROUND_GRID_STEP):
		canvas.draw_line(Vector2(x, 0), Vector2(x, VIEWPORT_SIZE.y), Color(UiTheme.C_GRID, 0.12), 1.0)
	canvas.draw_circle(Vector2(610, 90), 150, Color(UiTheme.C_ACCENT_2, 0.055))
	canvas.draw_circle(Vector2(110, 660), 170, Color(UiTheme.C_ACCENT, 0.045))


static func draw_header(canvas: CanvasItem, font: Font, t: Callable, motor, last_rx_msec: int, udp_ready: bool, selected_node_id: int) -> void:
	draw_panel(canvas, HEADER_RECT, UiTheme.C_PANEL, UiTheme.C_LINE)
	draw_text(canvas, font, t.call("app_title"), 30, 28, UiTheme.C_TEXT, 20)
	var link = motor.alive or (last_rx_msec > 0 and Time.get_ticks_msec() - last_rx_msec <= 1500)
	_draw_status_chip(canvas, font, Rect2(505, 23, 84, 24), "LINK", link)
	_draw_status_chip(canvas, font, Rect2(598, 23, 84, 24), "UDP", udp_ready)
	draw_text(canvas, font, "%d ms" % AppSettings.HEARTBEAT_INTERVAL_MS, 622, 56, UiTheme.C_DIM, 10)
	draw_text(canvas, font, t.call("header_subtitle") % selected_node_id, 32, 56, UiTheme.C_TEXT, 10)


static func draw_tabs(canvas: CanvasItem, font: Font, tab_keys: Array, current_tab: int, tab_name: Callable) -> void:
	var tab_w = (TAB_TOTAL_WIDTH - TAB_GAP * float(tab_keys.size() - 1)) / float(tab_keys.size())
	var x = TAB_START_X
	for i in tab_keys.size():
		var rect = Rect2(x, TAB_TOP, tab_w, TAB_HEIGHT)
		var active = i == current_tab
		draw_rounded_rect(
			canvas,
			rect,
			UiTheme.C_ACCENT if active else UiTheme.C_PANEL_2,
			UiTheme.C_ACCENT if active else UiTheme.C_LINE,
			6.0
		)
		draw_text(canvas, font, tab_name.call(i), rect.position.x, rect.position.y + 10, UiTheme.C_TEXT, 12, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		x += tab_w + TAB_GAP


static func draw_status_overlay(canvas: CanvasItem, font: Font, status) -> void:
	if not status.is_visible():
		return
	var color = UiTheme.C_ACCENT
	if status.kind == "warn":
		color = UiTheme.C_WARN
	elif status.kind == "error":
		color = UiTheme.C_RED
	var rect = STATUS_OVERLAY_RECT
	draw_rounded_rect(canvas, rect, Color(UiTheme.C_INPUT, 0.96), color, 7.0, 2)
	draw_text(canvas, font, status.message, rect.position.x, rect.position.y + 13, color, 14, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


static func draw_footer(canvas: CanvasItem, font: Font, t: Callable) -> void:
	draw_panel(canvas, FOOTER_RECT, UiTheme.C_PANEL, UiTheme.C_LINE)
	draw_text(canvas, font, t.call("footer"), 24, 681, UiTheme.C_DIM, 12)


static func draw_action_rail(canvas: CanvasItem, font: Font, t: Callable, rect: Rect2, items: Array, selected_index: int) -> void:
	draw_panel(canvas, rect, UiTheme.C_PANEL, UiTheme.C_LINE)
	draw_text(canvas, font, t.call("commands"), rect.position.x + ACTION_RAIL_TITLE_OFFSET, rect.position.y + ACTION_RAIL_TITLE_OFFSET, UiTheme.C_DIM, 14)
	var row_h = min(ACTION_ROW_MAX_HEIGHT, (rect.size.y - ACTION_RAIL_BOTTOM_RESERVE - ACTION_ROW_GAP * float(max(items.size() - 1, 0))) / float(max(items.size(), 1)))
	var y = rect.position.y + ACTION_RAIL_TOP_OFFSET
	for i in items.size():
		var row_rect = Rect2(rect.position.x + ACTION_RAIL_SIDE_PADDING, y, rect.size.x - ACTION_RAIL_SIDE_PADDING * 2.0, row_h)
		draw_rounded_rect(canvas, row_rect, UiTheme.C_INPUT, UiTheme.C_LINE, 5.0)
		draw_text(canvas, font, items[i], row_rect.position.x, row_rect.position.y + max(7, int((row_h - 18) * 0.5)), UiTheme.C_TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER, row_rect.size.x)
		y += row_h + ACTION_ROW_GAP
	if selected_index >= 0 and selected_index < items.size():
		var selected_rect = Rect2(rect.position.x + ACTION_RAIL_SIDE_PADDING, rect.position.y + ACTION_RAIL_TOP_OFFSET + selected_index * (row_h + ACTION_ROW_GAP), rect.size.x - ACTION_RAIL_SIDE_PADDING * 2.0, row_h)
		draw_rounded_rect(
			canvas, selected_rect, Color(UiTheme.C_INPUT, 0.0), UiTheme.C_ACCENT, 5.0, 2
		)
		draw_rounded_rect(
			canvas,
			Rect2(selected_rect.position.x, selected_rect.position.y, 5, selected_rect.size.y),
			UiTheme.C_ACCENT,
			UiTheme.C_ACCENT,
			2.5
		)


static func _draw_status_chip(canvas: CanvasItem, font: Font, rect: Rect2, label: String, ok: bool) -> void:
	var color = UiTheme.C_GREEN if ok else UiTheme.C_RED
	draw_rounded_rect(canvas, rect, Color(color, 0.18), color, 5.0)
	draw_text(canvas, font, label, rect.position.x, rect.position.y + 7, color, 10, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


static func draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color) -> void:
	draw_rounded_rect(canvas, rect, fill, border, PANEL_RADIUS)


static func draw_rounded_rect(
	canvas: CanvasItem,
	rect: Rect2,
	fill: Color,
	border: Color,
	radius: float = 8.0,
	border_width: int = 1
) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	var corner_radius := int(minf(radius, minf(rect.size.x, rect.size.y) * 0.5))
	style.set_corner_radius_all(corner_radius)
	canvas.draw_style_box(style, rect)


static func draw_text(canvas: CanvasItem, font: Font, text: String, x: float, y: float, color: Color, font_size: int = 16, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if font == null:
		return
	canvas.draw_string(font, Vector2(x, y + font_size), text, align, width, font_size, color)
