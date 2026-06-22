extends RefCounted

const GlobalActionController = preload("res://scripts/controllers/global_action_controller.gd")

var global_actions = GlobalActionController.new()


func resolve(
	action: String,
	app_session,
	upload_mode,
	can_filter,
	numeric_input,
	node_selector,
	motor_controller,
	can_log,
	language_options: Array,
	node_key_rows: Array,
	numeric_key_rows: Array,
	keyboard_rows: Array,
	node_empty_error: String,
	node_range_error: String
) -> Dictionary:
	if not app_session.language_selected:
		return _resolve_language(action, app_session, language_options)
	if not app_session.mode_selected:
		return {}
	if not app_session.node_selected:
		return _resolve_node(action, node_selector, node_key_rows, node_empty_error, node_range_error)
	if upload_mode.open:
		if action in ["confirm", "back", "language_select"]:
			return {"event": "close_upload"}
		return {}
	if can_filter.open:
		return _resolve_filter(action, can_filter, keyboard_rows, can_log.filter)
	if numeric_input.open:
		return _resolve_numeric(action, numeric_input, numeric_key_rows)
	return global_actions.resolve(action, motor_controller)


func _resolve_language(action: String, app_session, language_options: Array) -> Dictionary:
	var result = app_session.handle_language_action(action, language_options)
	match str(result.get("event", "")):
		"shutdown":
			return {"event": "shutdown"}
		"language_selected":
			return {
				"event": "language_selected",
				"language": str(result.get("language", "")),
			}
	return {}


func _resolve_node(
	action: String,
	node_selector,
	node_key_rows: Array,
	empty_error: String,
	range_error: String
) -> Dictionary:
	var result = node_selector.handle_action(action, node_key_rows, empty_error, range_error)
	match str(result.get("event", "")):
		"back":
			return {"event": "language_select"}
		"selected":
			return {
				"event": "node_selected",
				"node": int(result.get("node", 1)),
			}
	return {}


func _resolve_numeric(action: String, numeric_input, numeric_key_rows: Array) -> Dictionary:
	var result = numeric_input.handle_action(action, numeric_key_rows)
	match str(result.get("event", "")):
		"language_select":
			return {"event": "language_select"}
		"error":
			return {
				"event": "numeric_error",
				"kind": str(result.get("kind", "")),
			}
		"selected":
			return {
				"event": "numeric_selected",
				"kind": str(result.get("kind", "")),
				"value": int(result.get("value", 0)),
			}
	return {}


func _resolve_filter(action: String, can_filter, keyboard_rows: Array, current_filter: String) -> Dictionary:
	var result = can_filter.handle_action(action, keyboard_rows, current_filter)
	var event = str(result.get("event", ""))
	if event == "language_select":
		return {"event": "language_select"}
	if result.has("filter"):
		return {
			"event": "filter_selected" if event == "selected" else "filter_changed",
			"filter": str(result.get("filter", current_filter)),
		}
	return {}
