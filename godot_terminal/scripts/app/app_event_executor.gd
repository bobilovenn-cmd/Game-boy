extends RefCounted


func send(
	udp_client,
	connection,
	command_tracker,
	message: String,
	now: int
) -> Dictionary:
	if not connection.udp_ready:
		return {"ok": false, "error": "udp_not_ready"}
	var err = udp_client.send_text(message)
	if err != OK:
		return {"ok": false, "error": "send_failed", "code": err}
	var tracking = command_tracker.track(message, now)
	return {"ok": true, "tracking": tracking}


func shutdown() -> Dictionary:
	var output: Array = []
	var code = OS.execute("poweroff", [], output, true, false)
	return {
		"ok": code == 0,
		"code": code,
		"output": "\n".join(output).strip_edges(),
	}
