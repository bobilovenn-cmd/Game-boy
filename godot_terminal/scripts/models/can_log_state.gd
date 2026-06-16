extends RefCounted

const MAX_ROWS = 80

var filter = ""
var rows: Array[Dictionary] = []
var paused = false
var rx_count = 0
var last_line = ""


func clear() -> void:
	rows.clear()
	last_line = ""


func append_line(line: String, raw: String) -> void:
	rx_count += 1
	last_line = line
	rows.append({"line": line, "raw": raw})
	while rows.size() > MAX_ROWS:
		rows.pop_front()


func filtered_rows() -> Array[Dictionary]:
	if filter.strip_edges() == "":
		return rows
	var needle = filter.strip_edges().to_lower()
	var result: Array[Dictionary] = []
	for row in rows:
		var line = str(row.get("line", "")).to_lower()
		if line.contains(needle):
			result.append(row)
	return result
