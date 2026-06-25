extends RefCounted

const Protocol = preload("res://scripts/protocol.gd")


func handle(data: Dictionary, selected_node_id: int, motor, ota, command_tracker) -> Dictionary:
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
			var sdo_correlation = command_tracker.resolve(data, cmd)
			if str(sdo_correlation.get("status", "")) == "unknown_seq":
				return {"event": "ignored_stale_response"}
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
		"config_status":
			var config_correlation = command_tracker.resolve(data, cmd)
			if str(config_correlation.get("status", "")) == "unknown_seq":
				return {"event": "ignored_stale_response"}
			return {
				"event": "config_status",
				"phase": str(payload.get("state", "")),
				"old_node": int(payload.get("old_node", 0)),
				"new_node": int(payload.get("new_node", 0)),
				"progress": int(payload.get("progress", 0)),
			}
		"config_result":
			var result_correlation = command_tracker.resolve(data, cmd)
			if str(result_correlation.get("status", "")) == "unknown_seq":
				return {"event": "ignored_stale_response"}
			var result_status = str(payload.get("status", ""))
			var result_code = str(payload.get("code", ""))
			return {
				"event": "config_result",
				"ok": result_status == "ok",
				"code": result_code,
				"old_node": int(payload.get("old_node", 0)),
				"new_node": int(payload.get("new_node", 0)),
				"active_node": int(payload.get("active_node", 0)),
				"verified": bool(payload.get("verified", false)),
				"message": str(payload.get("msg", result_code)),
			}
		"ack":
			var correlation = command_tracker.resolve(data, cmd)
			if str(correlation.get("status", "")) == "unknown_seq":
				return {"event": "ignored_stale_response"}
			if (
				str(correlation.get("status", "")) == "legacy_unsequenced"
				and not Protocol.matches_node(payload, selected_node_id)
			):
				return {"event": "ignored"}
			var status = str(payload.get("status", ""))
			var msg = str(payload.get("msg", ""))
			var text = "OK: %s" % msg if status == "ok" else "ERR: %s" % msg
			var source_cmd = str(correlation.get("cmd", ""))
			if source_cmd == "config_node_change_prepare":
				return {
					"event": "config_prepare_ack",
					"ok": status == "ok",
					"message": text,
					"status_message": text,
					"status_kind": "info" if status == "ok" else "error",
				}
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
