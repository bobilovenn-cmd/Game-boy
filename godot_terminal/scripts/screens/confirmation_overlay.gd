extends CanvasLayer

const UiTheme = preload("res://scripts/theme/ui_theme.gd")

const VIEWPORT_SIZE := Vector2(720, 720)
const PANEL_RECT := Rect2(90, 250, 540, 190)

var root: Control
var content_label: Label


func _init() -> void:
	layer = 100
	root = Control.new()
	root.name = "ConfirmationRoot"
	root.position = Vector2.ZERO
	root.size = VIEWPORT_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)

	var panel = Panel.new()
	panel.name = "ConfirmationPanel"
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = UiTheme.C_PANEL
	panel_style.border_color = UiTheme.C_WARN
	panel_style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	content_label = _make_label("Content", Rect2(24, 18, 492, 154), 16, UiTheme.C_TEXT)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(content_label)


func configure(font: Font) -> void:
	if font == null:
		return
	content_label.add_theme_font_override("font", font)


func sync(t: Callable, confirmation) -> void:
	var active = confirmation.is_active()
	root.visible = active
	if not active:
		return
	content_label.text = "%s\n\n%s\n\n%s" % [
		str(t.call("confirm_title")),
		str(t.call(confirmation.message_key)),
		str(t.call("confirm_hint")),
	]


func _make_label(
	label_name: String,
	rect: Rect2,
	font_size: int,
	color: Color
) -> Label:
	var label = Label.new()
	label.name = label_name
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
