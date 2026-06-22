extends RefCounted

const InputMapper = preload("res://scripts/input/input_mapper.gd")

var last_input_label = "none"
var last_raw_button = -1
var godot_axis_active = {}


func route_raw(raw: int, release_offset: int) -> Dictionary:
	if raw >= release_offset:
		var release_id = raw - release_offset
		last_raw_button = release_id
		last_input_label = "raw %d -> jog_stop" % release_id
		return {"action": "jog_stop"}

	last_raw_button = raw
	var action = InputMapper.raw_action(raw)
	last_input_label = "raw %d -> %s" % [raw, action if action != "" else "unmapped"]
	if action == "":
		return {"unmapped_button": raw}
	return {"action": action}


func route_raw_axis(axis: int, value: float) -> Dictionary:
	last_input_label = "raw axis %d -> %.3f" % [axis, value]
	return {"axis": axis, "value": clamp(value, -1.0, 1.0)}


func route_godot_button(button_index: int, pressed: bool) -> Dictionary:
	var action = InputMapper.godot_button_action(button_index)
	if action == "":
		return {}
	last_input_label = "godot %d -> %s" % [button_index, action]
	if pressed:
		return {"action": action}
	if action == "jog_cw" or action == "jog_ccw":
		return {"action": "jog_stop"}
	return {}


func route_godot_axis(axis: int, value: float) -> Dictionary:
	if axis == 0 or axis == 1:
		last_input_label = "godot axis %d -> %.3f" % [axis, value]
		return {"axis": axis, "value": clamp(value, -1.0, 1.0)}
	var action = InputMapper.godot_axis_action(axis)
	if action == "":
		return {}
	var is_pressed = value > 0.55
	var was_pressed = bool(godot_axis_active.get(axis, false))
	if is_pressed == was_pressed:
		return {}
	godot_axis_active[axis] = is_pressed
	last_input_label = "axis %d %.2f -> %s" % [axis, value, action if is_pressed else "release"]
	if is_pressed:
		return {"action": action}
	return {}


func route_keyboard(keycode: int) -> Dictionary:
	var action = InputMapper.keyboard_action(keycode)
	if action == "":
		return {}
	return {"action": action}
