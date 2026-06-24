extends Node

const UiTheme = preload("res://scripts/theme/ui_theme.gd")

const LANGUAGE_KEYS := ["language_subtitle", "language_hint"]
const MODE_KEYS := [
	"mode_subtitle",
	"mode_single_desc",
	"mode_hint",
]
const NODE_KEYS := ["node_subtitle", "node_range", "node_hint"]

var labels: Dictionary = {}
var layers: Dictionary = {}


func _init() -> void:
	# RGB30 的实体渲染路径偶尔会遗漏同一 _draw() 批次中的小字号文字。
	# 关键副标题、说明和操作提示使用独立 CanvasLayer，避免依赖绘制批次顺序。
	_add_label("language_subtitle", Rect2(108, 138, 504, 26), 14)
	_add_label("language_hint", Rect2(78, 610, 564, 48), 15,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)

	_add_label("mode_subtitle", Rect2(108, 134, 504, 28), 14)
	_add_label("mode_single_desc", Rect2(132, 262, 456, 28), 13)
	_add_label("mode_hint", Rect2(78, 610, 564, 48), 15,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)

	_add_label("node_subtitle", Rect2(108, 134, 504, 28), 14)
	_add_label("node_range", Rect2(108, 162, 504, 24), 12, HORIZONTAL_ALIGNMENT_LEFT,
		VERTICAL_ALIGNMENT_CENTER, UiTheme.C_DIM_2)
	_add_label("node_hint", Rect2(78, 626, 564, 42), 14,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)


func configure(font: Font) -> void:
	if font == null:
		return
	for label in labels.values():
		label.add_theme_font_override("font", font)


func sync(t: Callable, session) -> void:
	var language_visible: bool = not session.language_selected
	var mode_visible: bool = session.language_selected and not session.mode_selected
	var node_visible: bool = (
		session.mode_selected
		and not session.node_selected
	)
	_set_group_visible(LANGUAGE_KEYS, language_visible)
	_set_group_visible(MODE_KEYS, mode_visible)
	_set_group_visible(NODE_KEYS, node_visible)

	if language_visible:
		labels["language_subtitle"].text = t.call("language_subtitle")
		labels["language_hint"].text = t.call("language_hint")
	if mode_visible:
		labels["mode_subtitle"].text = t.call("mode_subtitle")
		labels["mode_single_desc"].text = t.call("mode_single_motor_desc")
		labels["mode_hint"].text = t.call("mode_hint")
	if node_visible:
		labels["node_subtitle"].text = t.call("node_subtitle")
		labels["node_range"].text = t.call("node_range")
		labels["node_hint"].text = t.call("node_hint")


func _set_group_visible(keys: Array, visible: bool) -> void:
	for key in keys:
		layers[key].visible = visible


func _add_label(
	key: String,
	rect: Rect2,
	font_size: int,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
	vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_TOP,
	color: Color = UiTheme.C_DIM
) -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "%sLayer" % key
	canvas_layer.layer = 10 + layers.size()
	add_child(canvas_layer)
	layers[key] = canvas_layer

	var label := Label.new()
	label.name = key
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = vertical_alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	canvas_layer.add_child(label)
	labels[key] = label
