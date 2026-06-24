extends SceneTree

const AntControlScreen = preload("res://scripts/screens/ant_control_screen.gd")


func _init() -> void:
	var center := Vector2(574, 177)
	_assert_direction(Vector2(0.6, 0.8), center, true, true)
	_assert_direction(Vector2(-0.6, 0.8), center, false, true)
	_assert_direction(Vector2(0.6, -0.8), center, true, false)
	_assert_direction(Vector2(-0.6, -0.8), center, false, false)
	_assert_wheel_directions(center)
	print("ant_trajectory_test: PASS")
	quit()


func _assert_direction(
	joystick: Vector2,
	center: Vector2,
	expect_right: bool,
	expect_forward: bool
) -> void:
	var points := AntControlScreen.trajectory_points(joystick, center)
	assert(points.size() == 13)
	var start: Vector2 = points[0]
	var end: Vector2 = points[points.size() - 1]
	assert((end.x > start.x) == expect_right)
	assert((end.y < start.y) == expect_forward)
	for point in points:
		assert(point.x >= 326.0 and point.x <= 714.0)
		assert(point.y >= 54.0 and point.y <= 282.0)


func _assert_wheel_directions(center: Vector2) -> void:
	var forward_right := AntControlScreen.wheel_direction_segments(
		Vector2(0.6, 0.8), center
	)
	assert(forward_right.size() == 2)
	assert(forward_right[0]["end"].y < forward_right[0]["start"].y)
	assert(forward_right[1]["end"].y < forward_right[1]["start"].y)
	assert(forward_right[0]["end"].x > forward_right[0]["start"].x)
	assert(forward_right[1]["end"].x > forward_right[1]["start"].x)
	var turn_right := AntControlScreen.wheel_direction_segments(Vector2(1.0, 0.0), center)
	assert(turn_right[0]["end"].y < turn_right[0]["start"].y)
	assert(turn_right[1]["end"].y > turn_right[1]["start"].y)
