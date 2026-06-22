extends SceneTree

const ConfirmationOverlay = preload("res://scripts/screens/confirmation_overlay.gd")
const ConfirmationState = preload("res://scripts/models/confirmation_state.gd")


func _init() -> void:
	var overlay = ConfirmationOverlay.new()
	var confirmation = ConfirmationState.new()
	root.add_child(overlay)

	var panel = overlay.get_node("ConfirmationRoot/ConfirmationPanel") as Panel
	var panel_style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert(overlay.layer == 100)
	assert(panel_style.bg_color.a == 1.0)
	assert(not overlay.has_node("ConfirmationRoot/OpaqueBackdrop"))
	assert(not overlay.root.visible)

	confirmation.arm("confirm_shutdown", {"event": "shutdown_confirmed"}, 1000)
	overlay.sync(func(key: String) -> String: return key, confirmation)
	assert(overlay.root.visible)
	assert(overlay.content_label.text.contains("confirm_title"))
	assert(overlay.content_label.text.contains("confirm_shutdown"))
	assert(overlay.content_label.text.contains("confirm_hint"))

	confirmation.cancel()
	overlay.sync(func(key: String) -> String: return key, confirmation)
	assert(not overlay.root.visible)
	print("confirmation_overlay_test: PASS")
	quit()
