extends SceneTree

const AntControlState = preload("res://scripts/models/ant_control_state.gd")
const MotorData = preload("res://scripts/motor_data.gd")


func _init() -> void:
	var state = AntControlState.new(MotorData)
	assert(state.LEFT_NODE_ID == 1)
	assert(state.RIGHT_NODE_ID == 2)
	assert(state.parking_brake)
	assert(not state.driving_enabled)

	state.set_driving_enabled(true)
	state.update_axis(1, -0.8, 1000)
	assert(state.target_left_speed > 0)
	assert(state.target_right_speed > 0)

	state.update_axis(0, 0.4, 1050)
	assert(state.target_left_speed > state.target_right_speed)

	state.set_driving_enabled(false)
	assert(state.target_left_speed == 0)
	assert(state.target_right_speed == 0)
	assert(state.parking_brake)

	state.set_driving_enabled(true)
	state.update_axis(1, -0.5, 2000)
	assert(state.enforce_joystick_timeout(2201))
	assert(state.target_left_speed == 0)
	assert(state.target_right_speed == 0)

	state.emergency_stop()
	assert(state.estop_latched)
	assert(not state.driving_enabled)
	assert(state.parking_brake)

	assert(state.update_motor_status({"node": 1, "speed": 100, "alive": true}, 3000))
	assert(state.update_motor_status({"node": 2, "speed": 200, "alive": true}, 3000))
	assert(state.left_motor.speed == 100)
	assert(state.right_motor.speed == 200)
	assert(not state.update_motor_status({"node": 3, "speed": 300}, 3000))
	print("ant_control_state_test: PASS")
	quit()
