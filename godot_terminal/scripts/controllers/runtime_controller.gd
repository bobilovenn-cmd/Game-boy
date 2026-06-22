extends RefCounted

const Protocol = preload("res://scripts/protocol.gd")
const CanLogFormatter = preload("res://scripts/protocol/can_log_formatter.gd")
const MessageDispatcher = preload("res://scripts/protocol/message_dispatcher.gd")

var message_dispatcher = MessageDispatcher.new()


func process_frame(
	now: int,
	udp_client,
	connection,
	motor,
	ota,
	ota_transfer,
	can_log,
	selected_node_id: int,
	heartbeat_interval_msec: int
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	if connection.udp_ready:
		for raw in udp_client.poll_text_packets():
			var data = Protocol.parse(raw)
			_record_can_row(raw, data, can_log)
			if not Protocol.is_valid_inbound(data):
				continue
			connection.mark_received(now)
			events.append(message_dispatcher.handle(data, selected_node_id, motor, ota))

	if connection.should_send_heartbeat(now, heartbeat_interval_msec):
		events.append({
			"event": "send",
			"message": Protocol.heartbeat(),
		})

	connection.update_motor_alive(now, motor)

	for message in ota_transfer.process(ota, now):
		events.append({
			"event": "send",
			"message": message,
		})

	return events


func _record_can_row(raw: String, data: Dictionary, can_log) -> void:
	if can_log.paused or not CanLogFormatter.should_record(data):
		return
	can_log.append_line(CanLogFormatter.format_line(raw, data), raw)
