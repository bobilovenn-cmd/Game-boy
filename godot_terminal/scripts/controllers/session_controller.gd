extends RefCounted

const AppSettings = preload("res://scripts/settings.gd")
const UiText = preload("res://scripts/ui_text.gd")

var language_selected = false
var selected_language = 0
var ui_lang = UiText.LANG_ZH
var mode_selected = false
var selected_mode_index = 0
var current_mode = ""
var node_selected = false
var selected_node_id = AppSettings.DEFAULT_NODE_ID


func handle_language_action(action: String, language_options: Array) -> Dictionary:
	match action:
		"up", "left":
			selected_language = max(0, selected_language - 1)
			_update_preview_language(language_options)
		"down", "right":
			selected_language = min(language_options.size(), selected_language + 1)
			_update_preview_language(language_options)
		"confirm":
			if selected_language == language_options.size():
				return {"event": "shutdown"}
			language_selected = true
			mode_selected = false
			current_mode = ""
			node_selected = false
			ui_lang = str(language_options[selected_language])
			return {"event": "language_selected", "language": ui_lang}
	return {"event": ""}


func handle_mode_action(action: String, mode_options: Array) -> Dictionary:
	match action:
		"up", "left":
			selected_mode_index = max(0, selected_mode_index - 1)
		"down", "right":
			selected_mode_index = min(mode_options.size() - 1, selected_mode_index + 1)
		"confirm":
			if selected_mode_index < 0 or selected_mode_index >= mode_options.size():
				return {"event": ""}
			var selected_option: Dictionary = mode_options[selected_mode_index]
			current_mode = str(selected_option.get("id", ""))
			mode_selected = current_mode != ""
			node_selected = not bool(selected_option.get("requires_node_selection", false))
			return {"event": "mode_selected", "mode": current_mode}
		"back", "language_select":
			return {"event": "language_select"}
	return {"event": ""}


func select_node(value: int) -> void:
	selected_node_id = value
	node_selected = true


func return_to_language_select(language_options: Array) -> void:
	var index = language_options.find(ui_lang)
	selected_language = index if index >= 0 else 0
	language_selected = false
	mode_selected = false
	current_mode = ""
	node_selected = false


func return_to_mode_select() -> void:
	mode_selected = false
	current_mode = ""
	node_selected = false


func _update_preview_language(language_options: Array) -> void:
	if selected_language < language_options.size():
		ui_lang = str(language_options[selected_language])
