extends RefCounted

var current_tab = 0
var selected = [0, 0, 0, 0]


func reset(tab_count: int) -> void:
	current_tab = 0
	selected.clear()
	for _i in tab_count:
		selected.append(0)


func selected_index(tab: int = current_tab) -> int:
	return int(selected[tab])


func set_selected_index(value: int, tab: int = current_tab) -> void:
	selected[tab] = value


func handle_action(action: String, tab_count: int, max_indices: Array) -> Dictionary:
	match action:
		"menu", "right":
			current_tab = (current_tab + 1) % tab_count
			return {"event": "page_changed", "tab": current_tab}
		"left":
			current_tab = (current_tab + tab_count - 1) % tab_count
			return {"event": "page_changed", "tab": current_tab}
		"up":
			selected[current_tab] = max(0, selected_index() - 1)
		"down":
			selected[current_tab] = min(_max_index(max_indices), selected_index() + 1)
		"confirm":
			return {"event": "confirm", "tab": current_tab, "index": selected_index()}
	return {"event": ""}


func _max_index(max_indices: Array) -> int:
	if current_tab >= 0 and current_tab < max_indices.size():
		return int(max_indices[current_tab])
	return 0
