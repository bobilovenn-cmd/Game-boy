extends RefCounted

const AppSettings = preload("res://scripts/settings.gd")
const UiText = preload("res://scripts/ui_text.gd")

var language_selected = false
var selected_language = 0
var ui_lang = UiText.LANG_ZH
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
			node_selected = false
			ui_lang = str(language_options[selected_language])
			return {"event": "language_selected", "language": ui_lang}
	return {"event": ""}


func select_node(value: int) -> void:
	selected_node_id = value
	node_selected = true


func return_to_language_select(language_options: Array) -> void:
	var index = language_options.find(ui_lang)
	selected_language = index if index >= 0 else 0
	language_selected = false
	node_selected = false


func _update_preview_language(language_options: Array) -> void:
	if selected_language < language_options.size():
		ui_lang = str(language_options[selected_language])
