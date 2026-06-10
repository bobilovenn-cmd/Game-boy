## UDP通信协议构建器 - protocol.gd
## 作用: 构建和解析与ESP32 CAN网关通信的JSON消息
## 支持: 心跳、SDO读写、电机使能/失能、点动、OTA升级等命令
## 独立模块，不依赖其他脚本

extends RefCounted
class_name Protocol

static var _seq_counter = 0

static func _next_seq() -> int:
	_seq_counter += 1
	return _seq_counter


static func _build(cmd: String, payload: Dictionary = {}) -> String:
	var msg = {
		"cmd": cmd,
		"seq": _next_seq(),
		"ts": int(Time.get_unix_time_from_system()),
	}
	if not payload.is_empty():
		msg["payload"] = payload
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


static func jog_start(node: int, direction: String = "cw", speed: int = 500) -> String:
	return _build("jog_start", {
		"node": node,
		"direction": direction,
		"speed": speed,
	})


static func jog_stop(node: int) -> String:
	return _build("jog_stop", {"node": node})


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


static func parse(data: String) -> Dictionary:
	var parsed = JSON.parse_string(data)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {
		"cmd": "unknown",
		"error": "json_parse_failed",
	}

