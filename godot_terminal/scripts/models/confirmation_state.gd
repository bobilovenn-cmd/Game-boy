extends RefCounted

const DEFAULT_TIMEOUT_MSEC := 5000

var message_key := ""
var action: Dictionary = {}
var deadline_msec := 0


func arm(key: String, confirmed_action: Dictionary, now: int, timeout_msec: int = DEFAULT_TIMEOUT_MSEC) -> void:
	message_key = key
	action = confirmed_action.duplicate(true)
	deadline_msec = now + timeout_msec


func cancel() -> void:
	message_key = ""
	action.clear()
	deadline_msec = 0


func is_active(now: int = Time.get_ticks_msec()) -> bool:
	if deadline_msec > 0 and now > deadline_msec:
		cancel()
	return message_key != "" and not action.is_empty()


func consume(now: int = Time.get_ticks_msec()) -> Dictionary:
	if not is_active(now):
		return {}
	var confirmed = action.duplicate(true)
	cancel()
	return confirmed
