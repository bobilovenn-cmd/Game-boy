extends RefCounted

var open = false
var key_row = 0
var key_col = 0
var lowercase = false


func start() -> void:
	open = true
	key_row = 1
	key_col = 0


func close() -> void:
	open = false


func handle_action(action: String, key_rows: Array, current_filter: String) -> Dictionary:
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
			return apply_key(_key_value(key_rows, key_row, key_col), current_filter)
		"back":
			open = false
			return {"event": "cancel"}
		"language_select":
			open = false
			return {"event": "language_select"}
	return {"event": "", "filter": current_filter}


func apply_key(key: String, current_filter: String) -> Dictionary:
	var next_filter = current_filter
	match key:
		"SP":
			if next_filter.length() < 32:
				next_filter += " "
		"DEL":
			if next_filter.length() > 0:
				next_filter = next_filter.substr(0, next_filter.length() - 1)
		"CLR":
			next_filter = ""
		"OK":
			open = false
			return {"event": "selected", "filter": next_filter}
		"SHIFT":
			lowercase = not lowercase
		_:
			if next_filter.length() < 32:
				next_filter += key
	return {"event": "changed", "filter": next_filter}


func _key_value(key_rows: Array, row_index: int, col_index: int) -> String:
	var key = str(key_rows[row_index][col_index])
	if key.length() == 1 and "ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(key) and lowercase:
		return key.to_lower()
	return key
