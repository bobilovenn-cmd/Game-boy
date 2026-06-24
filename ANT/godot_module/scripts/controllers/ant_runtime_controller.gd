extends RefCounted

const Protocol = preload("res://scripts/protocol.gd")

const MOTOR_TIMEOUT_MSEC := 1500


func process_frame(
	now: int,
	udp_client,
	connection,
	ant_state,
	command_tracker,
	heartbeat_interval_msec: int
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if connection.udp_ready:
		for raw in udp_client.poll_text_packets():
			var data = Protocol.parse(raw)
			if not Protocol.is_valid_inbound(data):
				continue
			connection.mark_received(now)
			var payload = Protocol.payload(data)
			if str(data.get("cmd", "")) == "motor_status":
				ant_state.update_motor_status(payload, now)
			elif str(data.get("cmd", "")) == "ack":
				command_tracker.resolve(data, "ack")

	if connection.should_send_heartbeat(now, heartbeat_interval_msec):
		events.append({"event": "send", "message": Protocol.heartbeat()})

	ant_state.enforce_motor_timeout(now, MOTOR_TIMEOUT_MSEC)
	if ant_state.enforce_joystick_timeout(now):
		events.append({"event": "ant_joystick_timeout"})
	return events
