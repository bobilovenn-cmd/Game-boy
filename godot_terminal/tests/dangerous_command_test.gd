extends SceneTree

const PageCommandController = preload("res://scripts/controllers/page_command_controller.gd")
const ConfigTransactionState = preload("res://scripts/models/config_transaction_state.gd")


func _init() -> void:
	var controller = PageCommandController.new()
	var config_items = [
		["cfg_change_node", 0x2001, 1, "cfg_node_transaction"],
		["cfg_save_eeprom", 0x1010, 1, "cfg_persist"],
	]
	var node_open = controller.resolve(1, 0, 2, config_items, null)
	assert(node_open.get("event") == "open_numeric")
	assert(node_open.get("kind") == "node_change")

	var config_state = ConfigTransactionState.new()
	config_state.start_prepare(2, 3)
	config_state.apply_prepare_ack(true, "ok")
	var node_commit = controller.resolve(1, 0, 2, config_items, null, config_state)
	assert(node_commit.get("event") == "confirm_required")
	assert(node_commit.get("message_key") == "confirm_change_node")
	assert(node_commit.get("confirmed_action", {}).get("event") == "commit_node_change")

	var high_node_state = ConfigTransactionState.new()
	high_node_state.start_prepare(100, 1)
	high_node_state.apply_prepare_ack(true, "ok")
	var high_node_commit = controller.resolve(1, 0, 2, config_items, null, high_node_state)
	assert(high_node_commit.get("event") == "confirm_required")
	assert(high_node_commit.get("confirmed_action", {}).get("event") == "commit_node_change")

	var save = controller.resolve(1, 1, 2, config_items, null)
	assert(save.get("event") == "confirm_required")
	assert(save.get("message_key") == "confirm_save_eeprom")
	assert(save.get("confirmed_action", {}).get("event") == "send")

	var flash = controller.resolve(2, 4, 2, [], null)
	assert(flash.get("event") == "confirm_required")
	assert(flash.get("message_key") == "confirm_ota_flash")
	assert(flash.get("confirmed_action", {}).get("event") == "send")
	print("dangerous_command_test: PASS")
	quit()
