extends SceneTree

const Protocol = preload("res://scripts/protocol.gd")


func _init() -> void:
	assert(Protocol.is_valid_inbound({"cmd": "motor_status", "payload": {}}))
	assert(Protocol.is_valid_inbound({"cmd": "ack", "payload": {"status": "ok"}}))
	assert(Protocol.is_valid_inbound({"cmd": "config_status", "payload": {}}))
	assert(Protocol.is_valid_inbound({"cmd": "config_result", "payload": {}}))
	assert(not Protocol.is_valid_inbound({"cmd": "unknown"}))
	assert(not Protocol.is_valid_inbound({"cmd": "ack", "payload": "invalid"}))
	assert(not Protocol.is_valid_inbound(Protocol.parse("{not-json")))
	var prepare = Protocol.parse(Protocol.config_node_change_prepare(2, 3))
	assert(prepare.get("cmd") == "config_node_change_prepare")
	assert(Protocol.payload(prepare).get("old_node") == 2)
	assert(Protocol.payload(prepare).get("new_node") == 3)
	print("protocol_validation_test: PASS")
	quit()
