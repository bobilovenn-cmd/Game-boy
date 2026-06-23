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
	assert(overlay.labels["link"].text == "LINK")
	assert(overlay.labels["can"].text == "CAN")
	assert(overlay.labels["safe"].text == "安全")
	assert(overlay.labels["left_node"].text == "左轮 Node 1")
	assert(overlay.labels["right_node"].text == "右轮 Node 2")
	assert(overlay.labels["left_target_name"].text == "目标速度")
	assert(overlay.labels["joystick_forward"].text == "前进")
	assert(overlay.labels["joystick_reverse"].text == "后退")
	assert(overlay.labels["joystick_left"].text == "左转")
	assert(overlay.labels["joystick_right"].text == "右转")
	assert(overlay.labels["left_speed_value"].text == "12345 pulse/s")
	assert(overlay.labels["left_current_value"].text == "2.50 A")
	assert(overlay.labels["left_torque_value"].text == "1.25 Nm")
	assert(overlay.labels["left_status"].text == "正常")
	assert(overlay.labels["left_drive_state"].text == "Enabled")
	assert(not overlay.labels.has("left_state_name"))
	assert(not overlay.labels.has("left_state_value"))

	state.left_motor.fresh_mask = MotorData.FIELD_STATUS
	overlay.sync(func(key: String) -> String: return key, state, connection, true)
	assert(overlay.labels["left_speed_value"].text == "--")
	assert(overlay.labels["left_current_value"].text == "--")
	assert(overlay.labels["left_torque_value"].text == "--")

	state.left_motor.alive = false
	overlay.sync(func(key: String) -> String: return key, state, connection, true)
	assert(overlay.labels["left_status"].text == "离线")

	overlay.sync(func(key: String) -> String: return key, state, connection, false)
	for layer in overlay.layers:
		assert(not layer.visible)

	print("ant_control_overlay_test: PASS")
	quit()
