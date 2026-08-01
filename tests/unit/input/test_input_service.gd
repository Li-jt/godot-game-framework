# tests/unit/input/test_input_service.gd
extends GutTest

var _service: GF_InputService


func before_each() -> void:
	_service = GF_InputService.new()
	_service.module_name = "InputService"
	_service.init_module()


func after_each() -> void:
	_service = null


func test_register_action_def_adds_to_resolver() -> void:
	var def := GF_InputActionDef.new("jump")
	_service.register_action_def(def)
	assert_not_null(_service.get_action_def("jump"))


func test_get_action_def_returns_correct() -> void:
	var def := GF_InputActionDef.new("move_left")
	_service.register_action_def(def)
	var retrieved := _service.get_action_def("move_left")
	assert_eq(retrieved, def)


func test_get_all_action_ids_returns_all() -> void:
	_service.register_action_def(GF_InputActionDef.new("jump"))
	_service.register_action_def(GF_InputActionDef.new("move_left"))
	var ids := _service.get_all_action_ids()
	assert_eq(ids.size(), 2)


func test_read_axis_default_zero() -> void:
	_service.register_action_def(GF_InputActionDef.new("move_right"))
	assert_eq(_service.read_axis("move_right"), 0.0)


func test_is_pressed_default_false() -> void:
	_service.register_action_def(GF_InputActionDef.new("jump"))
	assert_false(_service.is_pressed("jump"))


func test_is_just_pressed_default_false() -> void:
	_service.register_action_def(GF_InputActionDef.new("jump"))
	assert_false(_service.is_just_pressed("jump"))


func test_push_and_pop_context() -> void:
	var ctx := GF_InputContext.new()
	ctx.block_all_game_actions = true
	_service.push_context(ctx)
	_service.pop_context()


func test_clear_contexts_resets() -> void:
	var ctx := GF_InputContext.new()
	_service.push_context(ctx)
	_service.clear_contexts()
