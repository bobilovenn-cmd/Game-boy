extends RefCounted

var open = false
var state = "dongle"
var network_mode = "wifi"
var ssid = "same_wifi"
var password = ""
var url = "http://RGB30_IP:8080"
var status = ""


func open_upload(script_path: String, starting_text: String, missing_text: String, ready_text: String) -> void:
	open = true
	state = "upload"
	status = starting_text
	_start_service(script_path, missing_text, ready_text)


func close_upload(script_path: String) -> void:
	_stop_service(script_path)
	open = false
	state = "dongle"


func _start_service(script_path: String, missing_text: String, ready_text: String) -> void:
	if not FileAccess.file_exists(script_path):
		network_mode = "mock"
		ssid = "same_wifi"
		password = ""
		url = "http://RGB30_IP:8080"
		status = missing_text
		return
	var output: Array = []
	var code = OS.execute("/bin/sh", [script_path, "start"], output, true, false)
	var line = "\n".join(output).strip_edges()
	_apply_service_output(line)
	if code == 0:
		status = ready_text
	else:
		status = "start failed: %d" % code


func _stop_service(script_path: String) -> void:
	if not FileAccess.file_exists(script_path):
		return
	var output: Array = []
	OS.execute("/bin/sh", [script_path, "stop"], output, true, false)


func _apply_service_output(line: String) -> void:
	var parts = line.split(" ", false)
	for part in parts:
		var eq = part.find("=")
		if eq <= 0:
			continue
		var key = part.substr(0, eq)
		var value = part.substr(eq + 1)
		match key:
			"mode":
				network_mode = value
			"ssid":
				if value != "":
					ssid = value
			"password":
				password = value
			"url":
				if value != "":
					url = value
