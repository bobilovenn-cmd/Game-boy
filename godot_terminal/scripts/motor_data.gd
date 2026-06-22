## 电机数据模型 - motor_data.gd
## 作用: 存储电机实时状态数据(电流、电压、速度、位置、转矩等)
## 维护历史数据用于波形显示，解析CiA 402状态字
## 依赖: settings.gd (WAVEFORM_HISTORY常量)

extends RefCounted
class_name MotorData

const AppSettings = preload("res://scripts/settings.gd")

const FIELD_SPEED := 1 << 0
const FIELD_POSITION := 1 << 1
const FIELD_CURRENT := 1 << 2
const FIELD_VOLTAGE := 1 << 3
const FIELD_TORQUE := 1 << 4
const FIELD_STATUS := 1 << 5
const ALL_FIELDS := (1 << 6) - 1

var current: float = 0.0
var voltage: float = 0.0
var speed: int = 0
var position: float = 0.0
var torque: float = 0.0
var status_word: int = 0
var fault_code: int = 0
var drive_fault: bool = false
var estop_latched: bool = false
var display_status: String = "offline"
var valid_mask: int = 0
var fresh_mask: int = 0
var mode: int = 0
var alive: bool = false
var wdg_ms: int = 0

var timestamps: Array[float] = []
var current_history: Array[float] = []
var speed_history: Array[float] = []
var torque_history: Array[float] = []

var _start_msec: int = Time.get_ticks_msec()


func update_from_dict(data: Dictionary) -> void:
	valid_mask = int(data.get("valid_mask", ALL_FIELDS))
	fresh_mask = int(data.get("fresh_mask", valid_mask))
	if data.has("current") and is_field_fresh(FIELD_CURRENT):
		current = float(data["current"])
	if data.has("voltage") and is_field_fresh(FIELD_VOLTAGE):
		voltage = float(data["voltage"])
	if data.has("speed") and is_field_fresh(FIELD_SPEED):
		speed = int(data["speed"])
	if data.has("position") and is_field_fresh(FIELD_POSITION):
		position = float(data["position"])
	if data.has("torque") and is_field_fresh(FIELD_TORQUE):
		torque = float(data["torque"])
	if data.has("fault"):
		fault_code = int(data["fault"])
	drive_fault = bool(data.get("drive_fault", fault_code != 0))
	estop_latched = bool(data.get("estop_latched", false))
	display_status = str(data.get("display_status", ""))
	if data.has("mode"):
		mode = int(data["mode"])
	if data.has("alive"):
		alive = bool(data["alive"])
	if data.has("wdg_ms"):
		wdg_ms = int(data["wdg_ms"])
	if is_field_fresh(FIELD_STATUS):
		if data.has("drive_status_word"):
			status_word = _parse_status_word(data["drive_status_word"])
		elif data.has("status_word"):
			status_word = _parse_status_word(data["status_word"])
	if display_status == "":
		display_status = _resolve_legacy_display_status()

	if is_field_fresh(FIELD_SPEED):
		var elapsed_seconds: float = float(Time.get_ticks_msec() - _start_msec) / 1000.0
		_push_history(timestamps, elapsed_seconds)
		_push_history(speed_history, float(speed))


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
	if estop_latched:
		return "E-STOP"
	if not alive or display_status == "offline":
		return "OFFLINE"
	if not is_field_fresh(FIELD_STATUS):
		return "--"
	if drive_fault:
		return "FAULT"
	var sw: int = status_word
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
	return drive_fault


func is_alert() -> bool:
	return estop_latched or drive_fault


func is_field_fresh(field_bit: int) -> bool:
	return (fresh_mask & field_bit) != 0


func is_field_valid(field_bit: int) -> bool:
	return (valid_mask & field_bit) != 0


func _resolve_legacy_display_status() -> String:
	if estop_latched:
		return "estop"
	if not alive:
		return "offline"
	if not is_field_fresh(FIELD_STATUS):
		return "stale"
	if drive_fault:
		return "drive_fault"
	return "ready"


func _push_history(target: Array[float], value: float) -> void:
	target.append(value)
	while target.size() > AppSettings.WAVEFORM_HISTORY:
		target.pop_front()


func _parse_status_word(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	var text: String = str(value).strip_edges()
	if text.begins_with("0x") or text.begins_with("0X"):
		return text.substr(2).hex_to_int()
	return int(text)


func _hex(value: int, width: int = 4) -> String:
	return ("%X" % value).pad_zeros(width)
