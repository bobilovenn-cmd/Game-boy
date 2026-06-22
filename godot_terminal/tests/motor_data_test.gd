extends SceneTree

const MotorData = preload("res://scripts/motor_data.gd")


func _init() -> void:
	var motor = MotorData.new()
	motor.update_from_dict({
		"current": 1.25,
		"voltage": 48.0,
		"speed": 50000,
		"position": 90.0,
		"torque": -0.25,
		"drive_status_word": 0x0027,
		"drive_fault": false,
		"estop_latched": false,
		"display_status": "ready",
		"valid_mask": MotorData.ALL_FIELDS,
		"fresh_mask": MotorData.ALL_FIELDS,
		"alive": true,
	})
	assert(motor.speed == 50000)
	assert(motor.torque == -0.25)
	assert(motor.get_status_text() == "Enabled")

	motor.update_from_dict({
		"speed": 123,
		"drive_status_word": 0x0008,
		"drive_fault": true,
		"estop_latched": false,
		"display_status": "stale",
		"valid_mask": MotorData.ALL_FIELDS,
		"fresh_mask": MotorData.FIELD_CURRENT,
		"alive": true,
	})
	assert(motor.speed == 50000)
	assert(motor.get_status_text() == "--")
	assert(motor.is_fault())

	motor.update_from_dict({
		"drive_status_word": 0x0021,
		"drive_fault": false,
		"estop_latched": true,
		"display_status": "estop",
		"valid_mask": MotorData.ALL_FIELDS,
		"fresh_mask": MotorData.ALL_FIELDS,
		"alive": true,
	})
	assert(motor.status_word == 0x0021)
	assert(motor.get_status_text() == "E-STOP")
	assert(not motor.is_fault())
	assert(motor.is_alert())

	print("motor_data_test: PASS")
	quit()
