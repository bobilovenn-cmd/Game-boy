extends RefCounted

const RGB30_RAW_BUTTONS = {
	0: "back",
	1: "confirm",
	2: "enable",
	3: "disable",
	4: "jog_ccw",
	5: "jog_cw",
	6: "estop",
	7: "stick_press",
	8: "language_select",
	9: "menu",
	13: "up",
	14: "down",
	15: "left",
	16: "right",
}

const GODOT_STANDARD_BUTTONS = {
	# Emergency fallback only. Normal RGB30 operation uses the stable event
	# bridge, so reboot-dependent SDL numbering never controls A/B.
	0: "confirm",
	1: "back",
	2: "enable",
	3: "disable",
	4: "language_select",
	6: "menu",
	7: "stick_press",
	9: "jog_ccw",
	10: "jog_cw",
	11: "up",
	12: "down",
	13: "left",
	14: "right",
}

const GODOT_AXIS_ACTIONS = {
	4: "estop",
	5: "r2",
}

static func raw_action(button_id: int) -> String:
	return str(RGB30_RAW_BUTTONS.get(button_id, ""))


static func godot_button_action(button_index: int) -> String:
	return str(GODOT_STANDARD_BUTTONS.get(button_index, ""))


static func godot_axis_action(axis: int) -> String:
	return str(GODOT_AXIS_ACTIONS.get(axis, ""))


static func keyboard_action(keycode: int) -> String:
	match keycode:
		KEY_TAB:
			return "menu"
		KEY_UP:
			return "up"
		KEY_DOWN:
			return "down"
		KEY_LEFT:
			return "left"
		KEY_RIGHT:
			return "right"
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			return "confirm"
		KEY_ESCAPE:
			return "back"
		KEY_X:
			return "enable"
		KEY_Y:
			return "disable"
		KEY_Q:
			return "jog_ccw"
		KEY_E:
			return "jog_cw"
		KEY_S:
			return "estop"
		KEY_BACKSPACE:
			return "language_select"
	return ""
