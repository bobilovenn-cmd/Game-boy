extends SceneTree

const SessionController = preload("res://scripts/controllers/session_controller.gd")
const UiConfig = preload("res://scripts/app/ui_config.gd")
const UiText = preload("res://scripts/ui_text.gd")


func _init() -> void:
	var session = SessionController.new()
	session.handle_language_action("confirm", UiConfig.LANGUAGE_OPTIONS)
	assert(session.language_selected)
	assert(not session.mode_selected)

	var single = session.handle_mode_action("confirm", UiConfig.MODE_OPTIONS)
	assert(single.get("mode") == "single_motor")
	assert(session.mode_selected)
	assert(not session.node_selected)

	session.return_to_mode_select()
	session.handle_mode_action("down", UiConfig.MODE_OPTIONS)
	var ant = session.handle_mode_action("confirm", UiConfig.MODE_OPTIONS)
	assert(ant.get("mode") == "ant_control")
	assert(session.mode_selected)
	assert(session.node_selected)

	session.return_to_mode_select()
	var back = session.handle_mode_action("back", UiConfig.MODE_OPTIONS)
	assert(back.get("event") == "language_select")
	assert(session.ui_lang == UiText.LANG_ZH)
	print("mode_session_test: PASS")
	quit()
