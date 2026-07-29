# tests/unit/input/test_input_policy.gd
extends GutTest

var _policy: InputPolicy


func before_each() -> void:
	_policy = InputPolicy.new()


func after_each() -> void:
	_policy = null


func test_empty_stack_does_not_block() -> void:
	# 空上下文栈时，动作不被 can_be_blocked 明确阻挡
	var dummy_event := InputEventKey.new()
	assert_false(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))


func test_allowlist_allows_action() -> void:
	var ctx := InputContext.new()
	ctx.allowed_actions = ["jump", "move"]
	_policy.get_context_stack().append(ctx)

	var dummy_event := InputEventKey.new()
	# allowed 里的动作不会被 context 阻挡
	assert_false(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))


func test_block_all_game_actions_blocks() -> void:
	var ctx := InputContext.new()
	ctx.block_all_game_actions = true
	_policy.get_context_stack().append(ctx)

	var dummy_event := InputEventKey.new()
	assert_true(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))


func test_blocked_action_ids_blocks_specific() -> void:
	var ctx := InputContext.new()
	ctx.blocked_action_ids = ["ui_click"]
	_policy.get_context_stack().append(ctx)

	var dummy_event := InputEventKey.new()
	assert_true(_policy.is_action_blocked("ui_click", dummy_event, Vector2.INF))
	assert_false(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))


func test_wildcard_blocks_all() -> void:
	var ctx := InputContext.new()
	ctx.blocked_action_ids = ["*"]
	_policy.get_context_stack().append(ctx)

	var dummy_event := InputEventKey.new()
	assert_true(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))
	assert_true(_policy.is_action_blocked("any_action", dummy_event, Vector2.INF))


func test_pop_context_restores() -> void:
	var ctx1 := InputContext.new()
	ctx1.blocked_action_ids = ["jump"]
	_policy.get_context_stack().append(ctx1)

	var ctx2 := InputContext.new()
	ctx2.block_all_game_actions = true
	_policy.get_context_stack().append(ctx2)

	var dummy_event := InputEventKey.new()
	assert_true(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))

	_policy.get_context_stack().pop_back()
	# ctx1 只 blocked jump
	assert_true(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))

	_policy.get_context_stack().pop_back()
	assert_false(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))
