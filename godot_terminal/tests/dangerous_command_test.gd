extends SceneTree

const PageCommandController = preload("res://scripts/controllers/page_command_controller.gd")


func _init() -> void:
	var controller = PageCommandController.new()
	var config_items = [
		["cfg_save_eeprom", 0x1010, 1, "cfg_persist"],
	]
	var save = controller.resolve(1, 0, 2, config_items, null)
	assert(save.get("event") == "confirm_required")
	assert(save.get("message_key") == "confirm_save_eeprom")
	assert(save.get("confirmed_action", {}).get("event") == "send")

	var flash = controller.resolve(2, 4, 2, [], null)
	assert(flash.get("event") == "confirm_required")
	assert(flash.get("message_key") == "confirm_ota_flash")
	assert(flash.get("confirmed_action", {}).get("event") == "send")
	print("dangerous_command_test: PASS")
	quit()
