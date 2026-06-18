extends RefCounted

var open = false
var kind = ""
var value = ""
var key_row = 0
var key_col = 0


func start(input_kind: String, default_speed: int) -> void:
	open = true
	kind = input_kind
	value = str(default_speed) if kind == "speed" else ""
	key_row = 0
	key_col = 0


func close() -> void:
	open = false


func handle_action(action: String, key_rows: Array) -> Dictionary:
	match action:
		"up":
			key_row = max(0, key_row - 1)
			key_col = min(key_col, key_rows[key_row].size() - 1)
		"down":
			key_row = min(key_rows.size() - 1, key_row + 1)
			key_col = min(key_col, key_rows[key_row].size() - 1)
		"left":
			key_col = max(0, key_col - 1)
		"right":
			key_col = min(key_rows[key_row].size() - 1, key_col + 1)
		"confirm":
			return apply_key(str(key_rows[key_row][key_col]))
		"back":
			open = false
			return {"event": "cancel"}
		"language_select":
			open = false
			return {"event": "language_select"}
	return {"event": ""}


func apply_key(key: String) -> Dictionary:
	match key:
		"BACK":
			open = false
			return {"event": "cancel"}
		"DEL":
			if value.length() > 0:
				value = value.substr(0, value.length() - 1)
		"CLR":
			value = ""
		"OK":
			return confirm()
		"-":
			if kind == "position":
				if value.begins_with("-"):
					value = value.substr(1)
				elif value == "":
					value = "-"
		_:
			if value.length() < 10:
				value += key
	return {"event": ""}


func confirm() -> Dictionary:
	if value == "" or value == "-" or not value.is_valid_int():
		return {"event": "error", "kind": "empty"}
	var parsed = int(value)
	if kind == "speed" and (parsed < 1 or parsed > 300000):
		return {"event": "error", "kind": "speed_range"}
	open = false
	return {
		"event": "selected",
		"kind": kind,
		"value": parsed,
	}
