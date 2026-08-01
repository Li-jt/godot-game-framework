# tests/integration/test_input_to_action_flow.gd
extends GutTest


func test_key_press_to_action_just_pressed() -> void:
	var resolver := GF_ActionResolver.new()
	var policy := GF_InputPolicy.new()
	resolver.set_policy(policy)

	var def := GF_InputActionDef.new("jump", GF_InputActionDef.ActionType.BINARY)
	def.bind_key(KEY_SPACE, 1.0, GF_InputBinding.Mode.IMPULSE)
	resolver.register_action_def(def)

	resolver.begin_frame()

	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	resolver.feed_event(event)

	resolver.end_frame(0.016)
	assert_true(resolver.is_just_pressed("jump"))


func test_axis_from_key_pair() -> void:
	var resolver := GF_ActionResolver.new()
	var policy := GF_InputPolicy.new()
	resolver.set_policy(policy)

	var move_right := GF_InputActionDef.new("move_right", GF_InputActionDef.ActionType.AXIS_1D)
	move_right.bind_key(KEY_D, 1.0, GF_InputBinding.Mode.IMPULSE)
	resolver.register_action_def(move_right)

	var move_left := GF_InputActionDef.new("move_left", GF_InputActionDef.ActionType.AXIS_1D)
	move_left.bind_key(KEY_A, 1.0, GF_InputBinding.Mode.IMPULSE)
	resolver.register_action_def(move_left)

	resolver.begin_frame()

	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.pressed = true
	resolver.feed_event(event)

	resolver.end_frame(0.016)
	assert_true(resolver.read_axis("move_right") > 0.0)
	assert_eq(resolver.read_axis("move_left"), 0.0)
