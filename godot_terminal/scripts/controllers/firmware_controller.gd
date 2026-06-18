extends RefCounted


func load_default(ota, firmware_paths: Array) -> Dictionary:
	if ota.load_from_paths(firmware_paths):
		return {
			"ok": true,
			"status_message": "Firmware loaded",
			"status_kind": "info",
		}
	return {
		"ok": false,
		"status_message": "No firmware found",
		"status_kind": "warn",
	}


func start_transfer(ota, firmware_paths: Array, now: int) -> Dictionary:
	var result = {}
	if ota.firmware_data.is_empty():
		result = load_default(ota, firmware_paths)
		if not bool(result.get("ok", false)):
			return result
	ota.start_transfer(now)
	result["ok"] = true
	result["started"] = true
	return result
