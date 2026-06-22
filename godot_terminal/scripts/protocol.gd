## UDP通信协议构建器 - protocol.gd
## 作用: 构建和解析与ESP32 CAN网关通信的JSON消息
## 支持: 心跳、SDO读写、电机使能/失能、点动、OTA升级等命令
## 独立模块，不依赖其他脚本

extends RefCounted
class_name Protocol

const CommandSchema = preload("res://scripts/protocol/command_schema.gd")

static var _seq_counter = 0

static func _next_seq() -> int:
	_seq_counter += 1
	return _seq_counter


static func _build(cmd: String, payload: Dictionary = {}) -> String:
	var msg = CommandSchema.build_envelope(
		cmd,
		_next_seq(),
		int(Time.get_unix_time_from_system()),
		payload
	)
	return JSON.stringify(msg)


static func heartbeat() -> String:
	return _build("heartbeat")


static func sdo_read(node: int, index: int, sub: int = 0) -> String:
	return _build("sdo_read", {
		"node": node,
		"index": index,
		"sub": sub,
	})


static func sdo_write(node: int, index: int, sub: int, data: int) -> String:
	return _build("sdo_write", {
		"node": node,
		"index": index,
		"sub": sub,
		"data": data,
	})


static func enable(node: int) -> String:
	return _build("enable", {"node": node})


static func disable(node: int) -> String:
	return _build("disable", {"node": node})


static func estop() -> String:
	return _build("estop")


static func jog_start(node: int, direction: String = "cw", speed: int = 50000) -> String:
	return _build("jog_start", {
		"node": node,
		"direction": direction,
		"speed": speed,
	})


static func jog_stop(node: int) -> String:
	return _build("jog_stop", {"node": node})


static func set_speed(node: int, speed: int) -> String:
	return _build("set_speed", {
		"node": node,
		"speed": speed,
	})


static func move_position(node: int, position: int, speed: int) -> String:
	return _build("move_position", {
		"node": node,
		"position": position,
		"speed": speed,
	})


static func ota_start(size: int, md5: String) -> String:
	return _build("ota_start", {
		"size": size,
		"md5": md5,
	})


static func ota_chunk(offset: int, data_b64: String) -> String:
	return _build("ota_chunk", {
		"offset": offset,
		"data": data_b64,
	})


static func ota_verify() -> String:
	return _build("ota_verify")


static func ota_flash(node: int = 1) -> String:
	return _build("ota_flash", {"node": node})


static func car_move(left_node: int, right_node: int, left_speed: int, right_speed: int) -> String:
	return _build("car_move", {
		"left_node": left_node,
		"right_node": right_node,
		"left_speed": left_speed,
		"right_speed": right_speed,
	})


static func parse(data: String) -> Dictionary:
	var parsed = JSON.parse_string(data)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {
		"cmd": "unknown",
		"error": "json_parse_failed",
	}


static func payload(data: Dictionary) -> Dictionary:
	if data.has("payload") and typeof(data["payload"]) == TYPE_DICTIONARY:
		return data["payload"]
	return data


static func message_node(data: Dictionary) -> int:
	for key in ["node", "node_id", "nodeId"]:
		if data.has(key):
			return int(data.get(key, 0))
	return 0


static func matches_node(data: Dictionary, selected_node: int) -> bool:
	var node = message_node(data)
	return node == 0 or node == selected_node
