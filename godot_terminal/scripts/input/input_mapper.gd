extends RefCounted

const RGB30_RAW_BUTTONS = {
	0: "back",
	1: "confirm",
	2: "enable",
	3: "disable",
	4: "jog_ccw",
	5: "jog_cw",
	6: "language_select",
	7: "stick_press",
	8: "language_select",
	9: "menu",
	13: "up",
	14: "down",
	15: "left",
	16: "right",
}

const GODOT_STANDARD_BUTTONS = {
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

static func raw_action(button_id: int) -> String:
	return str(RGB30_RAW_BUTTONS.get(button_id, ""))


static func godot_button_action(button_index: int) -> String:
	return str(GODOT_STANDARD_BUTTONS.get(button_index, ""))
