extends SceneTree

const AntControlOverlay = preload("res://scripts/screens/ant_control_overlay.gd")
const AntControlState = preload("res://scripts/models/ant_control_state.gd")
const MotorData = preload("res://scripts/motor_data.gd")


func _init() -> void:
	var state = AntControlState.new(MotorData)
	var overlay = AntControlOverlay.new()
	root.add_child(overlay)

	state.left_motor.alive = true
	state.left_motor.valid_mask = MotorData.ALL_FIELDS
	state.left_motor.fresh_mask = MotorData.ALL_FIELDS
	state.left_motor.speed = 12345
	state.left_motor.current = 2.5
	state.left_motor.torque = 1.25
	state.left_motor.status_word = 0x0027
	state.left_motor.display_status = "ready"

	var connection = {"last_rx_msec": Time.get_ticks_msec()}
	overlay.sync(func(key: String) -> String: return key, state, connection, true)
	var fresh_values: String = overlay.labels["left_values"].text
	assert(fresh_values.contains("12345 pulse/s"))
	assert(fresh_values.contains("2.50 A"))
	assert(fresh_values.contains("1.25 Nm"))

	state.left_motor.fresh_mask = MotorData.FIELD_STATUS
	overlay.sync(func(key: String) -> String: return key, state, connection, true)
	var stale_values: String = overlay.labels["left_values"].text
	assert(not stale_values.contains("12345 pulse/s"))
	assert(not stale_values.contains("2.50 A"))
	assert(not stale_values.contains("1.25 Nm"))
	assert(stale_values.contains("--"))

	overlay.sync(func(key: String) -> String: return key, state, connection, false)
	for layer in overlay.layers:
		assert(not layer.visible)

	print("ant_control_overlay_test: PASS")
	quit()
