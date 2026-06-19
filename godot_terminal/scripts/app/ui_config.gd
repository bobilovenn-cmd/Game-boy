extends RefCounted

const UiText = preload("res://scripts/ui_text.gd")

const LANGUAGE_OPTIONS = [UiText.LANG_ZH, UiText.LANG_EN]
const TAB_KEYS = ["tab_monitor", "tab_config", "tab_ota", "tab_can"]
const MONITOR_ITEM_KEYS = ["cmd_enable", "cmd_disable", "cmd_estop", "cmd_jog_cw", "cmd_jog_ccw", "cmd_position_mode", "cmd_speed_set"]

const CONFIG_ITEMS = [
	["cfg_mode", 0x6060, 0, "cfg_drive_mode"],
	["cfg_control_word", 0x6040, 0, "cfg_cia_402"],
	["cfg_target_speed", 0x60FF, 0, "cfg_rpm"],
	["cfg_target_torque", 0x6071, 0, "cfg_permille"],
	["cfg_pid_kp", 0x2010, 0, "cfg_proportional"],
	["cfg_pid_ki", 0x2011, 0, "cfg_integral"],
	["cfg_pid_kd", 0x2012, 0, "cfg_derivative"],
	["cfg_current_limit", 0x2013, 0, "cfg_amps"],
	["cfg_save_eeprom", 0x1010, 1, "cfg_persist"],
]

const OTA_ITEM_KEYS = ["ota_upload", "ota_load", "ota_send", "ota_verify", "ota_flash"]
const CAN_ITEM_KEYS = ["can_filter", "can_reset", "can_pause"]

const NODE_KEY_ROWS = [
	["1", "2", "3"],
	["4", "5", "6"],
	["7", "8", "9"],
	["BACK", "0", "DEL"],
	["OK"],
]

const KEYBOARD_ROWS = [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
	["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
	["A", "S", "D", "F", "G", "H", "J", "K", "L"],
	["Z", "X", "C", "V", "B", "N", "M"],
	["SHIFT", "-", "_", ":", ".", "SP", "DEL", "CLR", "OK"],
]

const NUMERIC_KEY_ROWS = [
	["1", "2", "3"],
	["4", "5", "6"],
	["7", "8", "9"],
	["-", "0", "DEL"],
	["BACK", "CLR", "OK"],
]
