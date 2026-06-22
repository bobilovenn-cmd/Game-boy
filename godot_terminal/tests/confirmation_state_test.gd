extends SceneTree

const ConfirmationState = preload("res://scripts/models/confirmation_state.gd")


func _init() -> void:
	var confirmation = ConfirmationState.new()
	confirmation.arm("confirm_shutdown", {"event": "shutdown_confirmed"}, 1000, 500)
	assert(confirmation.is_active(1200))
	assert(confirmation.consume(1200).get("event") == "shutdown_confirmed")
	assert(not confirmation.is_active(1200))

	confirmation.arm("confirm_shutdown", {"event": "shutdown_confirmed"}, 1000, 100)
	assert(not confirmation.is_active(1200))
	assert(confirmation.consume(1200).is_empty())
	print("confirmation_state_test: PASS")
	quit()
