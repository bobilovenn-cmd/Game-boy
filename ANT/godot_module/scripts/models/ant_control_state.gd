extends RefCounted

const LEFT_NODE_ID := 1
const RIGHT_NODE_ID := 2
const JOYSTICK_TIMEOUT_MSEC := 200
const JOYSTICK_DEADZONE := 0.08
const SPEED_LIMIT_RATIO := 0.30
const MAX_WHEEL_SPEED := 300000

var left_motor
var right_motor
var joystick := Vector2.ZERO
var last_joystick_msec := 0
var driving_enabled := false
var parking_brake := true
var estop_latched := false
var protocol_ready := false
var target_left_speed := 0
var target_right_speed := 0
var left_last_rx_msec := 0
var right_last_rx_msec := 0


func _init(motor_data_script) -> void:
	left_motor = motor_data_script.new()
	right_motor = motor_data_script.new()


func update_axis(axis: int, value: float, now: int) -> void:
	if axis == 0:
		joystick.x = clamp(value, -1.0, 1.0)
	elif axis == 1:
		joystick.y = clamp(-value, -1.0, 1.0)
	else:
		return
	last_joystick_msec = now
	_apply_deadzone()
	_recalculate_targets()


func set_driving_enabled(enabled: bool) -> void:
	driving_enabled = enabled and not estop_latched
	parking_brake = not driving_enabled
	if not driving_enabled:
		stop_motion()


func emergency_stop() -> void:
	estop_latched = true
	driving_enabled = false
	parking_brake = true
	stop_motion()


func clear_estop_for_preview() -> void:
	estop_latched = false


func enforce_joystick_timeout(now: int) -> bool:
	if last_joystick_msec <= 0 or now - last_joystick_msec <= JOYSTICK_TIMEOUT_MSEC:
		return false
	if joystick == Vector2.ZERO and target_left_speed == 0 and target_right_speed == 0:
		return false
	joystick = Vector2.ZERO
	stop_motion()
	return true


func update_motor_status(payload: Dictionary, now: int) -> bool:
	var node = int(payload.get("node", 0))
	if node == LEFT_NODE_ID:
		left_motor.update_from_dict(payload)
		left_last_rx_msec = now
		return true
	if node == RIGHT_NODE_ID:
		right_motor.update_from_dict(payload)
		right_last_rx_msec = now
		return true
	return false


func enforce_motor_timeout(now: int, timeout_msec: int) -> void:
	if left_last_rx_msec > 0 and now - left_last_rx_msec > timeout_msec:
		left_motor.alive = false
	if right_last_rx_msec > 0 and now - right_last_rx_msec > timeout_msec:
		right_motor.alive = false


func motion_label() -> String:
	if estop_latched:
		return "ant_motion_estop"
	if parking_brake:
		return "ant_motion_brake"
	if joystick.length() <= JOYSTICK_DEADZONE:
		return "ant_motion_standby"
	if abs(joystick.y) > abs(joystick.x):
		if joystick.y > 0.0:
			return "ant_motion_forward_right" if joystick.x > 0.15 else (
				"ant_motion_forward_left" if joystick.x < -0.15 else "ant_motion_forward"
			)
		return "ant_motion_reverse_right" if joystick.x > 0.15 else (
			"ant_motion_reverse_left" if joystick.x < -0.15 else "ant_motion_reverse"
		)
	return "ant_motion_turn_right" if joystick.x > 0.0 else "ant_motion_turn_left"


func stop_motion() -> void:
	target_left_speed = 0
	target_right_speed = 0


func _apply_deadzone() -> void:
	if abs(joystick.x) < JOYSTICK_DEADZONE:
		joystick.x = 0.0
	if abs(joystick.y) < JOYSTICK_DEADZONE:
		joystick.y = 0.0


func _recalculate_targets() -> void:
	if not driving_enabled or estop_latched:
		stop_motion()
		return
	var limited_speed = int(MAX_WHEEL_SPEED * SPEED_LIMIT_RATIO)
	var left_mix = clamp(joystick.y + joystick.x, -1.0, 1.0)
	var right_mix = clamp(joystick.y - joystick.x, -1.0, 1.0)
	target_left_speed = int(left_mix * limited_speed)
	target_right_speed = int(right_mix * limited_speed)
