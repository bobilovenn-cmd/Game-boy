extends RefCounted

var udp_ready = false
var last_heartbeat_msec = 0
var last_rx_msec = 0


func set_udp_ready(value: bool) -> void:
	udp_ready = value


func mark_received(now: int) -> void:
	last_rx_msec = now


func should_send_heartbeat(now: int, interval_msec: int) -> bool:
	if not udp_ready or now - last_heartbeat_msec < interval_msec:
		return false
	last_heartbeat_msec = now
	return true


func update_motor_alive(now: int, motor, timeout_msec: int = 1500) -> void:
	if last_rx_msec > 0 and now - last_rx_msec > timeout_msec:
		motor.alive = false


func reset_received() -> void:
	last_rx_msec = 0
