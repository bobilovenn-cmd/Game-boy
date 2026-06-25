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

	var prepare = Protocol.config_node_change_prepare(2, 3)
	var prepare_seq = int(Protocol.parse(prepare).get("seq", 0))
	tracker.track(prepare, 1000)
	var prepare_ack = dispatcher.handle({
		"cmd": "ack",
		"seq": prepare_seq,
		"payload": {"status": "ok", "msg": "node change can proceed"},
	}, 2, null, null, tracker)
	assert(prepare_ack.get("event") == "config_prepare_ack")
	assert(prepare_ack.get("ok") == true)

	var commit = Protocol.config_node_change_commit(2, 3)
	var commit_seq = int(Protocol.parse(commit).get("seq", 0))
	tracker.track(commit, 1000)
	var status = dispatcher.handle({
		"cmd": "config_status",
		"seq": commit_seq,
		"payload": {"state": "writing_node", "old_node": 2, "new_node": 3, "progress": 35},
	}, 2, null, null, tracker)
	assert(status.get("event") == "config_status")
	assert(status.get("progress") == 35)
	var result = dispatcher.handle({
		"cmd": "config_result",
		"seq": commit_seq,
		"payload": {"status": "ok", "active_node": 3, "verified": true, "msg": "OK"},
	}, 2, null, null, tracker)
	assert(result.get("event") == "config_result")
	assert(result.get("ok") == true)
	assert(result.get("verified") == true)
	print("message_dispatcher_test: PASS")
	quit()
