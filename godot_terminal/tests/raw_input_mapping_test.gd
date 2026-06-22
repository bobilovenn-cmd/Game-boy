extends SceneTree

const InputMapper = preload("res://scripts/input/input_mapper.gd")
const RawInputReader = preload("res://scripts/input/raw_input_reader.gd")


func _init() -> void:
	assert(RawInputReader.normalized_button_id(305) == 1)
	assert(InputMapper.raw_action(1) == "confirm")

	assert(RawInputReader.normalized_button_id(304) == 0)
	assert(InputMapper.raw_action(0) == "back")
	assert(InputMapper.godot_button_action(0) == "confirm")
	assert(InputMapper.godot_button_action(1) == "back")

	assert(InputMapper.raw_action(RawInputReader.normalized_button_id(312)) == "estop")
	assert(InputMapper.raw_action(RawInputReader.normalized_button_id(314)) == "language_select")

	assert(InputMapper.raw_action(RawInputReader.normalized_button_id(310)) == "jog_ccw")
	assert(InputMapper.raw_action(RawInputReader.normalized_button_id(311)) == "jog_cw")
	assert(RawInputReader.normalized_button_id(999) == -1)
	assert(RawInputReader.parse_bridge_message("axis:0:0.5").get("axis") == 0)
	assert(is_equal_approx(
		float(RawInputReader.parse_bridge_message("axis:1:-0.25").get("value")),
		-0.25
	))
	assert(RawInputReader.parse_bridge_message("axis:9:bad").is_empty())

	print("raw_input_mapping_test: PASS")
	quit()
