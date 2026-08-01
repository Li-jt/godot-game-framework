# tests/unit/input/test_input_action_state.gd
extends GutTest

var _state: GF_InputActionState
var _def: GF_InputActionDef


func before_each() -> void:
	_state = GF_InputActionState.new()
	_def = GF_InputActionDef.new("test_action", GF_InputActionDef.ActionType.BINARY)


func after_each() -> void:
	_state = null
	_def = null


func test_accumulate_impulse_sums() -> void:
	_state.accumulate_impulse(1.0)
	_state.accumulate_impulse(1.0)
	_state.finalize(_def, 0.016)
	assert_true(_state.value > 0.0)


func test_finalize_applies_deadzone() -> void:
	var def := GF_InputActionDef.new("test", GF_InputActionDef.ActionType.BINARY)
	def.deadzone = 0.2
	var s := GF_InputActionState.new()
	s.accumulate_analog(0.1)
	s.finalize(def, 0.016)
	assert_eq(s.value, 0.0)


func test_finalize_applies_sensitivity() -> void:
	var def := GF_InputActionDef.new("test", GF_InputActionDef.ActionType.BINARY)
	def.sensitivity = 2.0
	var s := GF_InputActionState.new()
	s.accumulate_analog(0.5)
	s.finalize(def, 0.016)
	assert_eq(s.value, 1.0)


func test_begin_frame_resets_per_frame_state() -> void:
	_state.accumulate_impulse(1.0)
	_state.finalize(_def, 0.016)
	assert_true(_state.value > 0.0)
	_state.begin_frame()
	assert_eq(_state.value, 0.0)


func test_just_pressed_true_only_first_frame() -> void:
	var def := GF_InputActionDef.new("test", GF_InputActionDef.ActionType.BINARY)
	var s := GF_InputActionState.new()
	s.accumulate_impulse(1.0)
	s.finalize(def, 0.016)
	assert_true(s.just_pressed)
	s.begin_frame()
	s.finalize(def, 0.016)
	assert_false(s.just_pressed)


func test_just_released_true_on_release() -> void:
	var def := GF_InputActionDef.new("test", GF_InputActionDef.ActionType.BINARY)
	var s := GF_InputActionState.new()
	s.accumulate_impulse(1.0)
	s.finalize(def, 0.016)
	s.begin_frame()
	s.finalize(def, 0.016)
	assert_true(s.just_released)


func test_pressed_while_held() -> void:
	var def := GF_InputActionDef.new("test", GF_InputActionDef.ActionType.BINARY)
	var s := GF_InputActionState.new()
	s.accumulate_impulse(1.0)
	s.finalize(def, 0.016)
	assert_true(s.pressed)
