extends RefCounted

const Protocol = preload("res://scripts/protocol.gd")


func resolve(tab: int, selected_index: int, node_id: int, config_items: Array, motor_controller) -> Dictionary:
	match tab:
		0:
			return _monitor_command(selected_index, motor_controller)
		1:
			return _config_command(selected_index, node_id, config_items)
		2:
			return _ota_command(selected_index, node_id)
		3:
			return _can_command(selected_index)
	return {}


func _monitor_command(index: int, motor_controller) -> Dictionary:
	match index:
		0:
			return _send(motor_controller.enable(), "Enable sent")
		1:
			return _send(motor_controller.disable(), "Disable sent")
		2:
			return _send(motor_controller.estop(), "E-STOP sent", "error")
		3:
			return _send(motor_controller.jog_cw(), "Jog CW %d" % motor_controller.target_speed)
		4:
			return _send(motor_controller.jog_ccw(), "Jog CCW %d" % motor_controller.target_speed)
		5:
			return {"event": "open_numeric", "kind": "position"}
		6:
			return {"event": "open_numeric", "kind": "speed"}
	return {}


func _config_command(selected_index: int, node_id: int, config_items: Array) -> Dictionary:
	if selected_index < 0 or selected_index >= config_items.size():
		return {}
	var item: Array = config_items[selected_index]
	var name_key = str(item[0])
	var object_index = int(item[1])
	var sub_index = int(item[2])
	if name_key == "cfg_save_eeprom":
		return _send(Protocol.sdo_write(node_id, object_index, sub_index, 0x65766173), "Save EEPROM")
	var result_msg = "Reading 0x%s..." % _hex(object_index)
	return {
		"event": "send",
		"message": Protocol.sdo_read(node_id, object_index, sub_index),
		"ui_message": result_msg,
		"result_msg": result_msg,
	}


func _ota_command(index: int, node_id: int) -> Dictionary:
	match index:
		0:
			return {"event": "open_upload"}
		1:
			return {"event": "load_firmware"}
		2:
			return {"event": "start_ota"}
		3:
			return {
				"event": "send",
				"message": Protocol.ota_verify(),
				"ui_message": "Verify requested",
				"ota_log": "Requesting MD5 verify",
			}
		4:
			return {
				"event": "send",
				"message": Protocol.ota_flash(node_id),
				"ui_message": "Flash command sent",
				"ota_log": "Flash command sent",
			}
	return {}


func _can_command(index: int) -> Dictionary:
	match index:
		0:
			return {"event": "open_filter"}
		1:
			return {"event": "clear_can_log"}
		2:
			return {"event": "toggle_can_pause"}
	return {}


func _send(message: String, ui_message: String, kind: String = "info") -> Dictionary:
	return {
		"event": "send",
		"message": message,
		"ui_message": ui_message,
		"kind": kind,
	}


func _hex(value: int, width: int = 4) -> String:
	return ("%X" % value).pad_zeros(width)
