extends SceneTree

const CommandTracker = preload("res://scripts/models/command_tracker.gd")
const Protocol = preload("res://scripts/protocol.gd")


func _init() -> void:
	var tracker = CommandTracker.new()
	var message = Protocol.enable(2)
	var envelope = Protocol.parse(message)
	var seq = int(envelope.get("seq", 0))
	assert(bool(tracker.track(message, 1000).get("tracked", false)))
	assert(tracker.resolve({"cmd": "ack", "seq": seq}, "ack").get("status") == "matched")
	assert(tracker.resolve({"cmd": "ack", "seq": seq}, "ack").get("status") == "unknown_seq")

	var legacy = tracker.resolve({"cmd": "ack"}, "ack")
	assert(legacy.get("status") == "legacy_unsequenced")

	var timeout_message = Protocol.sdo_read(2, 0x6041, 0)
	var timeout_envelope = Protocol.parse(timeout_message)
	var timeout_seq = int(timeout_envelope.get("seq", 0))
	assert(bool(tracker.track(timeout_message, 1000).get("tracked", false)))
	assert(
		tracker.resolve({"cmd": "ack", "seq": timeout_seq}, "ack").get("status")
		== "matched_nonterminal"
	)
	assert(
		tracker.resolve(
			{"cmd": "sdo_read_result", "seq": timeout_seq}, "sdo_read_result"
		).get("status")
		== "matched"
	)

	timeout_message = Protocol.sdo_read(2, 0x6041, 0)
	assert(bool(tracker.track(timeout_message, 1000).get("tracked", false)))
	var expired = tracker.expire(4000)
	assert(expired.size() == 1)
	assert(str(expired[0].get("cmd", "")) == "sdo_read")

	var heartbeat = Protocol.heartbeat()
	assert(bool(tracker.track(heartbeat, 1000).get("tracked", false)))
	assert(tracker.expire(4000).is_empty())
	print("command_tracker_test: PASS")
	quit()
