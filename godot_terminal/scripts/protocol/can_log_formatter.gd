extends RefCounted


static func should_record(data: Dictionary) -> bool:
	var cmd = str(data.get("cmd", "packet"))
	var payload = payload_from_message(data)
	if cmd == "ack" and str(payload.get("msg", "")) == "alive":
		return false
	if cmd == "motor_status":
		return false
	return true


static func format_line(raw: String, data: Dictionary) -> String:
	var cmd = str(data.get("cmd", "packet"))
	var payload = payload_from_message(data)
	return "%s  %s" % [Time.get_time_string_from_system(), packet_summary(cmd, payload, raw)]


static func payload_from_message(data: Dictionary) -> Dictionary:
	if data.has("payload") and typeof(data["payload"]) == TYPE_DICTIONARY:
		return data["payload"]
	return data


static func packet_summary(cmd: String, payload: Dictionary, raw: String) -> String:
	var can_id = str(payload.get("can_id", payload.get("id", "")))
	var dlc = str(payload.get("dlc", ""))
	var data_bytes = str(payload.get("data", payload.get("bytes", "")))
	if can_id != "" or data_bytes != "":
		var id_str = can_id if can_id != "" else "---"
		var dlc_str = dlc if dlc != "" else str(len(data_bytes) / 3 if data_bytes != "" else "0")
		return "%s  [%s]  %s" % [id_str, dlc_str, data_bytes]
	match cmd:
		"motor_status":
			var fresh_mask = int(payload.get("fresh_mask", 0x3F))
			return "STATUS I=%s V=%s SPD=%s POS=%s T=%s STATE=%s" % [
				_fresh_metric(payload, fresh_mask, 1 << 2, "current", "A"),
				_fresh_metric(payload, fresh_mask, 1 << 3, "voltage", "V"),
				_fresh_metric(payload, fresh_mask, 1 << 0, "speed", ""),
				_fresh_metric(payload, fresh_mask, 1 << 1, "position", ""),
				_fresh_metric(payload, fresh_mask, 1 << 4, "torque", ""),
				str(payload.get("display_status", "")),
			]
		"ack":
			return "ack %s %s" % [str(payload.get("status", "")), str(payload.get("msg", ""))]
		"sdo_read_result":
			return "sdo_read 0x%s = %s" % [_hex(int(payload.get("index", 0))), str(payload.get("data", ""))]
		"ota_status":
			return "ota_status " + str(payload.get("state", ""))
	if raw.length() > 64:
		return cmd + " " + raw.substr(0, 64)
	return cmd + " " + raw


static func _fresh_metric(payload: Dictionary, fresh_mask: int, field_bit: int, key: String, unit: String) -> String:
	if (fresh_mask & field_bit) == 0:
		return "--"
	return "%s%s" % [str(payload.get(key, "--")), unit]


static func _hex(value: int, width: int = 4) -> String:
	return ("%X" % value).pad_zeros(width)
