extends RefCounted

const Protocol = preload("res://scripts/protocol.gd")

var node_id = 1
var target_speed = 50000


func configure_node(value: int) -> void:
	node_id = value


func enable() -> String:
	return Protocol.enable(node_id)


func disable() -> String:
	return Protocol.disable(node_id)


func estop() -> String:
	return Protocol.estop()


func jog_cw() -> String:
	return Protocol.jog_start(node_id, "cw", target_speed)


func jog_ccw() -> String:
	return Protocol.jog_start(node_id, "ccw", target_speed)


func jog_stop() -> String:
	return Protocol.jog_stop(node_id)


func set_target_speed(value: int) -> String:
	target_speed = value
	return Protocol.set_speed(node_id, target_speed)


func move_position(position: int) -> String:
	return Protocol.move_position(node_id, position, target_speed)
