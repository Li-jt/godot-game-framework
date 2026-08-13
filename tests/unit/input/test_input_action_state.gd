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


func test_begin_frame_preserves_value_output() -> void:
	# begin 只清累积器（供下一帧重新累积），value 是 finalize 的输出
	# （router 每帧 end→begin 后，Game 层任意时点查询仍读到最近结算值）
	_state.accumulate_impulse(1.0)
	_state.finalize(_def, 0.016)
	assert_true(_state.value > 0.0)
	_state.begin_frame()
	assert_eq(_state.value, 1.0, "begin 不应清零 value")
	# 累积器已清：无新输入的帧结算为 0
	_state.finalize(_def, 0.016)
	assert_eq(_state.value, 0.0, "累积器清零后结算应为 0")


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


func test_just_pressed_not_sticky_while_held() -> void:
	# 模拟按住期间的帧循环：HELD 每帧累积，just_pressed 只在按下帧为 true
	var def := GF_InputActionDef.new("run", GF_InputActionDef.ActionType.BINARY)
	var s := GF_InputActionState.new()

	# 帧 N：按下
	s.begin_frame()
	s.accumulate_held(1.0)
	s.finalize(def, 0.016)
	assert_true(s.pressed, "按住帧 pressed 应为 true")
	assert_true(s.just_pressed, "按下帧 just_pressed 应为 true")

	# 帧 N+1：按住中（held 继续累积）
	s.begin_frame()
	s.accumulate_held(1.0)
	s.finalize(def, 0.016)
	assert_true(s.pressed, "按住期间 pressed 应持续")
	assert_false(s.just_pressed, "按住期间 just_pressed 不应粘住")

	# 帧 N+2：松开（无任何累积）
	s.begin_frame()
	s.finalize(def, 0.016)
	assert_false(s.pressed, "松开后 pressed 应为 false")
	assert_true(s.just_released, "松开帧 just_released 应为 true")
