extends RefCounted

var firmware_data = PackedByteArray()
var firmware_md5 = ""
var firmware_name = ""
var firmware_size = 0

var state = "idle"
var progress = 0
var speed_kbps = 0.0
var log: Array[String] = []
var offset = 0
var started = false
var start_msec = 0
var last_send_msec = 0


func load_from_paths(paths: Array) -> bool:
	for path in paths:
		if FileAccess.file_exists(path):
			var bytes = FileAccess.get_file_as_bytes(path)
			if bytes.is_empty():
				continue
			firmware_data = bytes
			firmware_size = firmware_data.size()
			firmware_name = path.get_file()
			firmware_md5 = FileAccess.get_md5(path)
			state = "ready"
			progress = 0
			add_log("Loaded %s (%d KB)" % [firmware_name, firmware_size / 1024])
			return true
	add_log("No firmware found in /storage")
	return false


func start_transfer(now: int) -> void:
	state = "sending"
	progress = 0
	offset = 0
	started = false
	start_msec = now
	last_send_msec = 0
	add_log("Starting transfer")


func mark_transfer_done() -> void:
	state = "verify"
	progress = 100
	add_log("Transfer done %.1f KB/s" % speed_kbps)


func apply_status(value: String) -> void:
	if value == "done":
		state = "done"
		progress = 100
		add_log("Flash complete")
	elif value == "error":
		state = "error"
		add_log("OTA error")
	else:
		add_log("OTA: %s" % value)


func add_log(message: String) -> void:
	var ts = Time.get_time_string_from_system()
	log.append("[%s] %s" % [ts, message])
	while log.size() > 4:
		log.pop_front()
