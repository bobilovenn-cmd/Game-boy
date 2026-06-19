extends SceneTree

const CanLogState = preload("res://scripts/models/can_log_state.gd")


func _init() -> void:
	var can_log = CanLogState.new()

	for index in 20_010:
		can_log.append_line("frame-%d" % index, "raw-%d" % index)

	assert(can_log.row_count() == CanLogState.MAX_ROWS)
	assert(can_log.matching_count() == CanLogState.MAX_ROWS)
	assert(can_log.recent_matching_rows().size() == CanLogState.DEFAULT_VISIBLE_ROWS)
	assert(str(can_log.recent_matching_rows().back().get("line", "")) == "frame-20009")

	can_log.filter = "frame-20009"
	assert(can_log.matching_count() == 1)
	assert(can_log.recent_matching_rows().size() == 1)

	can_log.clear()
	assert(can_log.row_count() == 0)
	assert(can_log.matching_count() == 0)

	print("can_log_state_test: PASS")
	quit()
