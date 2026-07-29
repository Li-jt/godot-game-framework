# tests/integration/test_input_to_action_flow.gd
extends GutTest


func test_key_press_to_action_just_pressed() -> void:
	var resolver := ActionResolver.new()
	var policy := InputPolicy.new()
	resolver.set_policy(policy)

	var def := InputActionDef.new("jump", InputActionDef.ActionType.BINARY)
	resolver.register_action_def(def)

	# 模拟按键 — feed_event 需要 Godot InputEvent
	resolver.begin_frame()

	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	resolver.feed_event(event)

	resolver.end_frame(0.016)
	assert_true(resolver.is_just_pressed("jump"))


func test_axis_from_key_pair() -> void:
	var resolver := ActionResolver.new()
	var policy := InputPolicy.new()
	resolver.set_policy(policy)

	var move_right := InputActionDef.new("move_right", InputActionDef.ActionType.AXIS_1D)
	resolver.register_action_def(move_right)

	var move_left := InputActionDef.new("move_left", InputActionDef.ActionType.AXIS_1D)
	resolver.register_action_def(move_left)

	resolver.begin_frame()

	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.pressed = true
	resolver.feed_event(event)

	resolver.end_frame(0.016)
	assert_true(resolver.read_axis("move_right") > 0.0)
	assert_eq(resolver.read_axis("move_left"), 0.0)
