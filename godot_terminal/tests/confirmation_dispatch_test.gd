extends SceneTree


func _init() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(source.contains("func _apply_confirmed_action"))
	assert(source.contains("\"commit_node_change\":"))
	assert(source.contains("_commit_node_change()"))
	print("confirmation_dispatch_test: PASS")
	quit()
