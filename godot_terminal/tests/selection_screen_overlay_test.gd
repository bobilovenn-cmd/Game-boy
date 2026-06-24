extends SceneTree

const SelectionScreenOverlay = preload(
	"res://scripts/screens/selection_screen_overlay.gd"
)


class SessionStub:
	var language_selected := false
	var mode_selected := false
	var current_mode := ""
	var node_selected := false


func _init() -> void:
	var overlay = SelectionScreenOverlay.new()
	root.add_child(overlay)
	overlay.configure(ThemeDB.fallback_font)
	var session := SessionStub.new()
	var translate := func(key: String) -> String: return key

	overlay.sync(translate, session)
	assert(overlay.layers["language_subtitle"].visible)
	assert(overlay.labels["language_subtitle"].text == "language_subtitle")
	assert(not overlay.layers["mode_subtitle"].visible)

	session.language_selected = true
	overlay.sync(translate, session)
	assert(not overlay.layers["language_subtitle"].visible)
	assert(overlay.layers["mode_single_desc"].visible)
	assert(overlay.labels["mode_single_desc"].text == "mode_single_motor_desc")

	session.mode_selected = true
	session.current_mode = "single_motor"
	overlay.sync(translate, session)
	assert(overlay.layers["node_subtitle"].visible)
	assert(overlay.labels["node_hint"].text == "node_hint")
	print("selection_screen_overlay_test: PASS")
	quit()
