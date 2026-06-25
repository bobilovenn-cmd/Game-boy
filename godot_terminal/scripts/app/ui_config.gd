extends RefCounted

const UiText = preload("res://scripts/ui_text.gd")

const LANGUAGE_OPTIONS = [UiText.LANG_ZH, UiText.LANG_EN]
const MODE_OPTIONS = [
	{
		"id": "single_motor",
		"title_key": "mode_single_motor",
		"desc_key": "mode_single_motor_desc",
		"requires_node_selection": true,
	},
]
const TAB_KEYS = ["tab_monitor", "tab_config", "tab_ota", "tab_can"]
const MONITOR_ITEM_KEYS = ["cmd_enable", "cmd_disable", "cmd_estop", "cmd_jog_cw", "cmd_jog_ccw", "cmd_position_mode", "cmd_speed_set"]

const CONFIG_ITEMS = [
	["cfg_change_node", 0x2001, 1, "cfg_node_transaction"],
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

# Shared 720x720 application layout.
const CONTENT_TOP: float = 140.0
const CONTENT_LEFT: float = 18.0
const CONTENT_RIGHT: float = 702.0
const CONTENT_WIDTH: float = CONTENT_RIGHT - CONTENT_LEFT
const LEFT_RAIL_WIDTH: float = 188.0
const CONTENT_GAP: float = 18.0
const MAIN_CONTENT_X: float = CONTENT_LEFT + LEFT_RAIL_WIDTH + CONTENT_GAP
const MAIN_CONTENT_WIDTH: float = CONTENT_RIGHT - MAIN_CONTENT_X

const MONITOR_COMMAND_RAIL_RECT := Rect2(CONTENT_LEFT, CONTENT_TOP, LEFT_RAIL_WIDTH, 360)
const MONITOR_TELEMETRY_RECT := Rect2(MAIN_CONTENT_X, CONTENT_TOP, MAIN_CONTENT_WIDTH, 190)
const MONITOR_WAVEFORM_RECT := Rect2(MAIN_CONTENT_X, 346, MAIN_CONTENT_WIDTH, 196)
const MONITOR_HOTKEY_RECT := Rect2(CONTENT_LEFT, 516, LEFT_RAIL_WIDTH, 88)
const MONITOR_INPUT_DEBUG_RECT := Rect2(MAIN_CONTENT_X, 558, MAIN_CONTENT_WIDTH, 46)

const CONFIG_PANEL_RECT := Rect2(CONTENT_LEFT, CONTENT_TOP, CONTENT_WIDTH, 386)
const CONFIG_RESULT_RECT := Rect2(CONTENT_LEFT, 542, CONTENT_WIDTH, 62)

const CAN_HEADER_RECT := Rect2(CONTENT_LEFT, CONTENT_TOP, CONTENT_WIDTH, 108)
const CAN_FILTER_RECT := Rect2(112, 188, 474, 30)
const CAN_ACTION_RAIL_RECT := Rect2(CONTENT_LEFT, 268, LEFT_RAIL_WIDTH, 226)
const CAN_LOG_RECT := Rect2(MAIN_CONTENT_X, 268, MAIN_CONTENT_WIDTH, 372)

const OTA_FIRMWARE_RECT := Rect2(CONTENT_LEFT, CONTENT_TOP, CONTENT_WIDTH, 120)
const OTA_UPLOAD_ROW_RECT := Rect2(36, 206, 650, 36)
const OTA_ACTION_RAIL_RECT := Rect2(CONTENT_LEFT, 284, 260, 226)
const OTA_TRANSFER_RECT := Rect2(300, 284, 402, 226)
const OTA_PROGRESS_RECT := Rect2(318, 382, 360, 30)
const OTA_LOG_RECT := Rect2(CONTENT_LEFT, 548, CONTENT_WIDTH, 92)

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
