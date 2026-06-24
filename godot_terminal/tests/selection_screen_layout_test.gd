extends SceneTree

const AppChrome = preload("res://scripts/screens/app_chrome.gd")
const LanguageScreen = preload("res://scripts/screens/language_screen.gd")
const ModeSelectScreen = preload("res://scripts/screens/mode_select_screen.gd")
const NodeSelectScreen = preload("res://scripts/screens/node_select_screen.gd")


func _init() -> void:
	assert(AppChrome.PANEL_RADIUS >= 8.0)
	assert(LanguageScreen.HINT_FONT_SIZE >= 15)
	assert(ModeSelectScreen.OPTION_TITLE_FONT_SIZE == 24)
	assert(ModeSelectScreen.OPTION_DESCRIPTION_FONT_SIZE >= 13)
	assert(ModeSelectScreen.HINT_FONT_SIZE >= 15)
	assert(NodeSelectScreen.HINT_FONT_SIZE >= 14)
	print("selection_screen_layout_test: PASS")
	quit()
