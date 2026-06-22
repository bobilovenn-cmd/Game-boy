extends SceneTree

const CommandTracker = preload("res://scripts/models/command_tracker.gd")
const MessageDispatcher = preload("res://scripts/protocol/message_dispatcher.gd")
const Protocol = preload("res://scripts/protocol.gd")


func _init() -> void:
	var tracker = CommandTracker.new()
	var dispatcher = MessageDispatcher.new()

	var estop = Protocol.estop()
	var envelope = Protocol.parse(estop)
	var seq = int(envelope.get("seq", 0))
	tracker.track(estop, 1000)
	var matched = dispatcher.handle({
		"cmd": "ack",
		"seq": seq,
		"payload": {"status": "ok", "msg": "estop", "node": 1},
	}, 2, null, null, tracker)
	assert(matched.get("event") == "ack")

	var stale = dispatcher.handle({
		"cmd": "ack",
		"seq": seq,
		"payload": {"status": "ok", "msg": "duplicate", "node": 1},
	}, 2, null, null, tracker)
	assert(stale.get("event") == "ignored_stale_response")

	var legacy_wrong_node = dispatcher.handle({
		"cmd": "ack",
		"payload": {"status": "ok", "msg": "legacy", "node": 1},
	}, 2, null, null, tracker)
	assert(legacy_wrong_node.get("event") == "ignored")
	print("message_dispatcher_test: PASS")
	quit()
