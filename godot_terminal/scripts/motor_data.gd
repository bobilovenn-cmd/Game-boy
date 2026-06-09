extends RefCounted
class_name MotorData

const AppSettings = preload("res://scripts/settings.gd")

var current = 0.0
var voltage = 0.0
var speed = 0
var position = 0.0
var torque = 0.0
var status_word = 0
var fault_code = 0
var mode = 0
var alive = false
var wdg_ms = 0

var timestamps: Array[float] = []
var current_history: Array[float] = []
var speed_history: Array[float] = []
var torque_history: Array[float] = []

var _start_msec = Time.get_ticks_msec()


func update_from_dict(data: Dictionary) -> void:
	if data.has("current"):
		current = float(data["current"])
	if data.has("voltage"):
		voltage = float(data["voltage"])
	if data.has("speed"):
		speed = int(data["speed"])
	if data.has("position"):
		position = float(data["position"])
	if data.has("torque"):
		torque = float(data["torque"])
	if data.has("fault"):
		fault_code = int(data["fault"])
	if data.has("mode"):
		mode = int(data["mode"])
	if data.has("alive"):
		alive = bool(data["alive"])
	if data.has("wdg_ms"):
		wdg_ms = int(data["wdg_ms"])
	if data.has("status_word"):
		status_word = _parse_status_word(data["status_word"])

	var t = float(Time.get_ticks_msec() - _start_msec) / 1000.0
	_push_history(timestamps, t)
	_push_history(current_history, current)
	_push_history(speed_history, float(speed))
	_push_history(torque_history, torque)


func get_waveform_data(param: String) -> Array:
	match param:
		"current":
			return [timestamps, current_history]
		"speed":
			return [timestamps, speed_history]
		"torque":
			return [timestamps, torque_history]
	return [timestamps, []]


func get_status_text() -> String:
	var sw = status_word
	if sw & 0x004F == 0x0000:
		return "Not Ready"
	if sw & 0x004F == 0x0040:
		return "Switch Off"
	if sw & 0x006F == 0x0021:
		return "Ready"
	if sw & 0x006F == 0x0023:
		return "Switched On"
	if sw & 0x006F == 0x0027:
		return "Enabled"
	if sw & 0x004F == 0x0008:
		return "FAULT"
	return "0x%s" % _hex(sw)


func is_fault() -> bool:
	return (status_word & 0x0008) != 0 or fault_code != 0


func _push_history(target: Array, value: float) -> void:
	target.append(value)
	while target.size() > AppSettings.WAVEFORM_HISTORY:
		target.pop_front()


func _parse_status_word(value) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	var s = str(value).strip_edges()
	if s.begins_with("0x") or s.begins_with("0X"):
		return s.substr(2).hex_to_int()
	return int(s)


func _hex(value: int, width: int = 4) -> String:
	return ("%X" % value).pad_zeros(width)
