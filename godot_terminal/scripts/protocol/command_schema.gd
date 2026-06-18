extends RefCounted

# Canonical payload field table shared by current motor commands and future car mode.
# Wire messages stay compact: defaults are documentation/validation values and are
# only emitted when include_defaults is explicitly requested.
const PAYLOAD_DEFAULTS = {
	"node": 0,
	"nodes": [],
	"direction": "",
	"speed": 0,
	"position": 0,
	"index": 0,
	"sub": 0,
	"data": null,
	"size": 0,
	"md5": "",
	"offset": 0,
	"state": "",
	"status": "",
	"msg": "",
	"left_node": 0,
	"right_node": 0,
	"left_speed": 0,
	"right_speed": 0,
}

const COMMAND_FIELDS = {
	"heartbeat": ["node"],
	"enable": ["node"],
	"disable": ["node"],
	"estop": ["node", "nodes"],
	"jog_start": ["node", "direction", "speed"],
	"jog_stop": ["node"],
	"set_speed": ["node", "speed"],
	"move_position": ["node", "position", "speed"],
	"sdo_read": ["node", "index", "sub"],
	"sdo_write": ["node", "index", "sub", "data"],
	"ota_start": ["size", "md5"],
	"ota_chunk": ["offset", "data"],
	"ota_verify": [],
	"ota_flash": ["node"],
	"car_move": ["left_node", "right_node", "left_speed", "right_speed"],
}


static func build_payload(cmd: String, values: Dictionary = {}, include_defaults: bool = false) -> Dictionary:
	var fields: Array = COMMAND_FIELDS.get(cmd, values.keys())
	var payload = {}
	for field in fields:
		var key = str(field)
		if values.has(key):
			payload[key] = values[key]
		elif include_defaults and PAYLOAD_DEFAULTS.has(key):
			payload[key] = PAYLOAD_DEFAULTS[key]
	return payload


static func build_envelope(cmd: String, seq: int, timestamp: int, values: Dictionary = {}, include_defaults: bool = false) -> Dictionary:
	var message = {
		"cmd": cmd,
		"seq": seq,
		"ts": timestamp,
	}
	var payload = build_payload(cmd, values, include_defaults)
	if not payload.is_empty():
		message["payload"] = payload
	return message
