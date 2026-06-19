extends RefCounted

var message = ""
var kind = "info"
var until_msec = 0


func set_message(value: String, value_kind: String = "info") -> void:
	message = value
	kind = value_kind
	until_msec = Time.get_ticks_msec() + (2600 if kind == "error" else 1800)


func clear() -> void:
	message = ""
	until_msec = 0


func is_visible() -> bool:
	return message != "" and Time.get_ticks_msec() <= until_msec
