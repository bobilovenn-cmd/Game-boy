extends SceneTree

const Protocol = preload("res://scripts/protocol.gd")


func _init() -> void:
	assert(Protocol.is_valid_inbound({"cmd": "motor_status", "payload": {}}))
	assert(Protocol.is_valid_inbound({"cmd": "ack", "payload": {"status": "ok"}}))
	assert(not Protocol.is_valid_inbound({"cmd": "unknown"}))
	assert(not Protocol.is_valid_inbound({"cmd": "ack", "payload": "invalid"}))
	assert(not Protocol.is_valid_inbound(Protocol.parse("{not-json")))
	print("protocol_validation_test: PASS")
	quit()
