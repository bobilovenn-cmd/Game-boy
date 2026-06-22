extends RefCounted

const Protocol = preload("res://scripts/protocol.gd")


func handle(data: Dictionary, selected_node_id: int, motor, ota) -> Dictionary:
	var cmd = str(data.get("cmd", ""))
	var payload = Protocol.payload(data)
	if payload != data:
		payload["cmd"] = cmd

	match cmd:
		"motor_status":
			if not Protocol.matches_node(payload, selected_node_id):
				return {"event": "ignored"}
			motor.update_from_dict(payload)
			return {"event": "motor_status"}
		"sdo_read_result":
			if not Protocol.matches_node(payload, selected_node_id):
				return {"event": "ignored"}
			var result_msg = _format_sdo_result(payload)
			return {
				"event": "sdo_result",
				"result_msg": result_msg,
				"status_message": result_msg,
				"status_kind": "info",
			}
		"ota_status":
			var state = str(payload.get("state", ""))
			ota.apply_status(state)
			return {"event": "ota_status"}
		"ack":
			if not Protocol.matches_node(payload, selected_node_id):
				return {"event": "ignored"}
			var status = str(payload.get("status", ""))
			var msg = str(payload.get("msg", ""))
			var text = "OK: %s" % msg if status == "ok" else "ERR: %s" % msg
			return {
				"event": "ack",
				"result_msg": text,
				"status_message": text,
				"status_kind": "info" if status == "ok" else "error",
				"ota_log": text,
			}
	return {"event": ""}


func _format_sdo_result(data: Dictionary) -> String:
	var index = int(data.get("index", 0))
	var result = str(data.get("data", ""))
	var val_text = result
	if result.is_valid_hex_number():
		val_text = "0x%s (%d)" % [result, result.hex_to_int()]
	return "0x%s = %s" % [_hex(index), val_text]


func _hex(value: int, width: int = 4) -> String:
	return ("%X" % value).pad_zeros(width)
