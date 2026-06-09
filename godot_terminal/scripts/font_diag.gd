extends Control

const C_BG = Color8(4, 8, 14)
const C_PANEL = Color8(13, 29, 43)
const C_LINE = Color8(42, 92, 110)
const C_GRID = Color8(22, 58, 72)
const C_TEXT = Color8(234, 247, 252)
const C_DIM = Color8(178, 214, 224)
const C_ACCENT = Color8(0, 226, 188)
const C_WARN = Color8(255, 184, 77)
const C_RED = Color8(255, 72, 92)
const C_GREEN = Color8(75, 255, 156)

const PIXEL_FONT = {
	" ": ["000", "000", "000", "000", "000"],
	"-": ["000", "000", "111", "000", "000"],
	".": ["000", "000", "000", "000", "010"],
	":": ["000", "010", "000", "010", "000"],
	"/": ["001", "001", "010", "100", "100"],
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"],
	"3": ["111", "001", "111", "001", "111"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"],
	"9": ["111", "101", "111", "001", "111"],
	"A": ["010", "101", "111", "101", "101"],
	"B": ["110", "101", "110", "101", "110"],
	"C": ["111", "100", "100", "100", "111"],
	"D": ["110", "101", "101", "101", "110"],
	"E": ["111", "100", "110", "100", "111"],
	"F": ["111", "100", "110", "100", "100"],
	"G": ["111", "100", "101", "101", "111"],
	"H": ["101", "101", "111", "101", "101"],
	"I": ["111", "010", "010", "010", "111"],
	"J": ["001", "001", "001", "101", "111"],
	"K": ["101", "101", "110", "101", "101"],
	"L": ["100", "100", "100", "100", "111"],
	"M": ["101", "111", "111", "101", "101"],
	"N": ["101", "111", "111", "111", "101"],
	"O": ["111", "101", "101", "101", "111"],
	"P": ["111", "101", "111", "100", "100"],
	"Q": ["111", "101", "101", "111", "001"],
	"R": ["111", "101", "111", "110", "101"],
	"S": ["111", "100", "111", "001", "111"],
	"T": ["111", "010", "010", "010", "010"],
	"U": ["101", "101", "101", "101", "111"],
	"V": ["101", "101", "101", "101", "010"],
	"W": ["101", "101", "111", "111", "101"],
	"X": ["101", "101", "010", "101", "101"],
	"Y": ["101", "101", "010", "010", "010"],
	"Z": ["111", "001", "010", "100", "111"],
}

var font: Font
var label_nodes: Array[Label] = []


func _ready() -> void:
	font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	_make_label(Vector2(372, 112), Vector2(300, 24), "LABEL 12 150 MS", 12, C_GREEN)
	_make_label(Vector2(372, 144), Vector2(300, 26), "LABEL 14 RGB30 NODE1", 14, C_GREEN)
	_make_label(Vector2(372, 178), Vector2(300, 30), "LABEL 16 0.00 A RPM", 16, C_GREEN)
	_make_label(Vector2(372, 214), Vector2(300, 34), "LABEL 20 OTA IDLE", 20, C_GREEN)
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 720, 720), C_BG, true)
	for y in range(0, 720, 24):
		draw_line(Vector2(0, y), Vector2(720, y), Color(C_GRID, 0.22), 1.0)
	for x in range(0, 720, 24):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(C_GRID, 0.12), 1.0)

	_panel(Rect2(14, 12, 692, 64))
	draw_rect(Rect2(500, 48, 34, 16), C_WARN, true)
	draw_rect(Rect2(542, 48, 34, 16), C_GREEN, true)
	draw_rect(Rect2(584, 48, 34, 16), C_RED, true)
	_text("RGB30 FONT DIAG V2", 30, 28, C_TEXT, 20)
	_text("DRAW STRING VS LABEL VS PIXEL BLOCKS", 32, 54, C_DIM, 14)
	_text("150 ms", 616, 55, C_DIM, 12)

	_panel(Rect2(18, 92, 324, 240))
	_text("DRAW_STRING", 36, 112, C_ACCENT, 16)
	_text("SIZE 10 150 MS", 36, 144, C_TEXT, 10)
	_text("SIZE 12 150 MS", 36, 174, C_TEXT, 12)
	_text("SIZE 14 RGB30 NODE1", 36, 206, C_TEXT, 14)
	_text("SIZE 16 0.00 A  0 RPM", 36, 240, C_TEXT, 16)
	_text("SIZE 20 OTA IDLE", 36, 282, C_TEXT, 20)

	_panel(Rect2(360, 92, 342, 240))
	_text("LABEL NODES", 378, 112, C_ACCENT, 16)

	_panel(Rect2(18, 352, 684, 180))
	_text("PIXEL BLOCK TEXT", 36, 372, C_ACCENT, 16)
	draw_rect(Rect2(36, 404, 28, 18), C_WARN, true)
	draw_rect(Rect2(74, 404, 28, 18), C_GREEN, true)
	draw_rect(Rect2(112, 404, 28, 18), C_RED, true)
	for i in range(12):
		draw_rect(Rect2(36 + i * 12, 426, 9, 18), C_GREEN, true)
	_marker_text("MARKER 150 MS", 36, 426, C_GREEN, 12)
	_pixel_text("PIXEL 150 MS", 36, 436, C_WARN, 5)
	_pixel_text("RGB30 720X720 CANOPEN UDP NODE1", 36, 484, C_WARN, 3)

	_panel(Rect2(18, 552, 684, 96))
	_text("POSITION TEST", 36, 572, C_ACCENT, 16)
	_text("TOP RIGHT NORMAL: 150 ms", 36, 604, C_TEXT, 14)
	_pixel_text("BOTTOM PIXEL 150 MS", 36, 626, C_WARN, 3)


func _make_label(pos: Vector2, size: Vector2, text: String, font_size: int, color: Color) -> void:
	var label = Label.new()
	label.position = pos
	label.size = size
	label.text = text
	label.clip_text = false
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	label_nodes.append(label)


func _text(text: String, x: float, y: float, color: Color, font_size: int) -> void:
	if font == null:
		return
	draw_string(font, Vector2(x, y + font_size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _pixel_text(text: String, x: float, y: float, color: Color, scale: int) -> void:
	var cx = x
	var upper = text.to_upper()
	for i in range(upper.length()):
		var ch = upper.substr(i, 1)
		if not PIXEL_FONT.has(ch):
			cx += 4 * scale
			continue
		var rows: Array = PIXEL_FONT[ch]
		for row in range(rows.size()):
			var bits: String = rows[row]
			for col in range(bits.length()):
				if bits.substr(col, 1) == "1":
					draw_rect(Rect2(cx + col * scale, y + row * scale, scale, scale), color, true)
		cx += 4 * scale


func _marker_text(text: String, x: float, y: float, color: Color, step: int) -> void:
	for i in range(text.length()):
		draw_rect(Rect2(x + i * step, y, step - 3, 18), color, true)


func _panel(rect: Rect2) -> void:
	draw_rect(rect, C_PANEL, true)
	draw_rect(rect, C_LINE, false, 1.0)
	draw_line(rect.position, rect.position + Vector2(18, 0), C_ACCENT, 2.0)
	draw_line(rect.position, rect.position + Vector2(0, 18), C_ACCENT, 2.0)
