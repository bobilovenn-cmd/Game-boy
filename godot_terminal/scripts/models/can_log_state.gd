extends RefCounted

const MAX_ROWS: int = 20_000
const DEFAULT_VISIBLE_ROWS: int = 9

var filter: String = "":
	set(value):
		if filter == value:
			return
		filter = value
		_filter_needle = value.strip_edges().to_lower()
		_rebuild_filter_cache()

var paused: bool = false
var rx_count: int = 0
var last_line: String = ""

var _rows: Array[Dictionary] = []
var _head: int = 0
var _count: int = 0
var _matching_count: int = 0
var _recent_matches: Array[Dictionary] = []
var _filter_needle: String = ""


func clear() -> void:
	_rows.clear()
	_head = 0
	_count = 0
	_matching_count = 0
	_recent_matches.clear()
	last_line = ""


func append_line(line: String, raw: String) -> void:
	rx_count += 1
	last_line = line
	var row: Dictionary = {
		"line": line,
		"raw": raw,
		"matches_filter": _matches_filter(line),
	}

	if _count < MAX_ROWS:
		_rows.append(row)
		_count += 1
	else:
		var evicted: Dictionary = _rows[_head]
		if bool(evicted.get("matches_filter", false)):
			_matching_count -= 1
			_recent_matches.erase(evicted)
		_rows[_head] = row
		_head = (_head + 1) % MAX_ROWS

	if bool(row["matches_filter"]):
		_matching_count += 1
		_recent_matches.append(row)
		if _recent_matches.size() > DEFAULT_VISIBLE_ROWS:
			_recent_matches.pop_front()


func row_count() -> int:
	return _count


func matching_count() -> int:
	return _matching_count


func recent_matching_rows() -> Array[Dictionary]:
	return _recent_matches


func _rebuild_filter_cache() -> void:
	_matching_count = 0
	_recent_matches.clear()
	for offset in _count:
		var index := (_head + offset) % _count if _count > 0 else 0
		var row: Dictionary = _rows[index]
		var matches := _matches_filter(str(row.get("line", "")))
		row["matches_filter"] = matches
		if matches:
			_matching_count += 1
			_recent_matches.append(row)
			if _recent_matches.size() > DEFAULT_VISIBLE_ROWS:
				_recent_matches.pop_front()


func _matches_filter(line: String) -> bool:
	return _filter_needle == "" or line.to_lower().contains(_filter_needle)
