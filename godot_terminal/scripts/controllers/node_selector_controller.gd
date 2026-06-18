extends RefCounted

var input = ""
var key_row = 0
var key_col = 0
var error_msg = ""


func reset() -> void:
	input = ""
	key_row = 0
	key_col = 0
	error_msg = ""


func handle_action(action: String, key_rows: Array, empty_error: String, range_error: String) -> Dictionary:
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
			return apply_key(str(key_rows[key_row][key_col]), empty_error, range_error)
		"back", "language_select":
			return {"event": "back"}
	return {"event": ""}


func apply_key(key: String, empty_error: String, range_error: String) -> Dictionary:
	match key:
		"BACK":
			return {"event": "back"}
		"DEL":
			if input.length() > 0:
				input = input.substr(0, input.length() - 1)
			error_msg = ""
		"OK":
			return confirm(empty_error, range_error)
		_:
			if input.length() < 3:
				input += key
			error_msg = ""
	return {"event": ""}


func confirm(empty_error: String, range_error: String) -> Dictionary:
	if input == "" or not input.is_valid_int():
		error_msg = empty_error
		return {"event": "error"}
	var value = int(input)
	if value < 1 or value > 127:
		error_msg = range_error
		return {"event": "error"}
	error_msg = ""
	return {
		"event": "selected",
		"node": value,
	}
