extends RefCounted


func resolve(action: String, motor_controller) -> Dictionary:
	match action:
		"menu", "up", "down", "left", "right", "confirm":
			return {"event": "navigate", "action": action}
		"back":
			return _send(motor_controller.jog_stop(), "Jog stopped")
		"enable":
			return _send(motor_controller.enable(), "Enable sent")
		"disable":
			return _send(motor_controller.disable(), "Disable sent")
		"estop":
			return _send(motor_controller.estop(), "E-STOP sent", "error")
		"jog_cw":
			return _send(motor_controller.jog_cw(), "Jog CW %d" % motor_controller.target_speed)
		"jog_ccw":
			return _send(motor_controller.jog_ccw(), "Jog CCW %d" % motor_controller.target_speed)
		"jog_stop":
			return _send(motor_controller.jog_stop(), "Jog stopped")
		"r2":
			return {"event": "status", "message": "R2 reserved"}
		"language_select":
			return {"event": "language_select"}
	return {}


func _send(message: String, ui_message: String, kind: String = "info") -> Dictionary:
	return {
		"event": "send",
		"message": message,
		"ui_message": ui_message,
		"kind": kind,
	}
