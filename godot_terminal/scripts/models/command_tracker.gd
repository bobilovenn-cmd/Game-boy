extends RefCounted

const Protocol = preload("res://scripts/protocol.gd")
const DEFAULT_TIMEOUT_MSEC := 2500
const LONG_TIMEOUT_MSEC := 8000
const MAX_PENDING := 128
const SILENT_TIMEOUT_COMMANDS = {
	"heartbeat": true,
	"ota_chunk": true,
}
const LONG_TIMEOUT_COMMANDS = {
	"enable": true,
	"disable": true,
	"ota_flash": true,
	"ota_start": true,
	"ota_verify": true,
	"config_node_change_commit": true,
}

var pending: Dictionary = {}


func track(message: String, now: int) -> Dictionary:
	var envelope = Protocol.parse(message)
	if envelope.has("error"):
		return {"tracked": false, "reason": "invalid_json"}
	var seq = int(envelope.get("seq", 0))
	var cmd = str(envelope.get("cmd", ""))
	if seq <= 0 or cmd == "":
		return {"tracked": false, "reason": "missing_identity"}
	var timeout = LONG_TIMEOUT_MSEC if LONG_TIMEOUT_COMMANDS.has(cmd) else DEFAULT_TIMEOUT_MSEC
	pending[seq] = {
		"seq": seq,
		"cmd": cmd,
		"deadline_msec": now + timeout,
		"report_timeout": not SILENT_TIMEOUT_COMMANDS.has(cmd),
	}
	_trim_oldest()
	return {"tracked": true, "seq": seq, "cmd": cmd}


func resolve(response: Dictionary, response_cmd: String) -> Dictionary:
	var seq = int(response.get("seq", 0))
	if seq <= 0:
		return {"status": "legacy_unsequenced"}
	if not pending.has(seq):
		return {"status": "unknown_seq", "seq": seq}
	var command: Dictionary = pending[seq]
	var command_name = str(command.get("cmd", ""))
	var terminal = true
	if response_cmd == "ack" and command_name in ["sdo_read", "config_node_change_commit"]:
		terminal = false
	if response_cmd == "config_status" and command_name == "config_node_change_commit":
		terminal = false
	if response_cmd == "config_result":
		terminal = true
	if terminal:
		pending.erase(seq)
	return {
		"status": "matched" if terminal else "matched_nonterminal",
		"seq": seq,
		"cmd": command_name,
	}


func expire(now: int) -> Array[Dictionary]:
	var expired: Array[Dictionary] = []
	var sequences = pending.keys()
	sequences.sort()
	for sequence in sequences:
		var command: Dictionary = pending[sequence]
		if now <= int(command.get("deadline_msec", 0)):
			continue
		pending.erase(sequence)
		if bool(command.get("report_timeout", false)):
			expired.append(command)
	return expired


func clear() -> void:
	pending.clear()


func _trim_oldest() -> void:
	if pending.size() <= MAX_PENDING:
		return
	var sequences = pending.keys()
	sequences.sort()
	while pending.size() > MAX_PENDING:
		pending.erase(sequences.pop_front())
