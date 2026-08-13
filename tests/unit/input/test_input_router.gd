# tests/unit/input/test_input_router.gd
## GF_InputRouter 帧语义单元测试。
## 覆盖：just_pressed 只在按下帧为 true（不粘住）、HELD 动作按住期间持续、read_axis 时点安全。
## 手动驱动 _unhandled_input/_process 模拟帧序列，不依赖真实帧循环。
extends GutTest

var _resolver: GF_ActionResolver
var _router: GF_InputRouter


func before_each() -> void:
	_resolver = GF_ActionResolver.new()
	_router = GF_InputRouter.new()
	_router.configure(_resolver)
	# 不挂树：_process 不会被引擎自动调用，由测试手动驱动


func after_each() -> void:
	_router.set_enabled(false)
	_router.free()
	_resolver = null


func _register_impulse(p_id: String, p_key: Key) -> void:
	_resolver.register_action_def(
		GF_InputActionDef.new(p_id, GF_InputActionDef.ActionType.BINARY)
			.bind_key(p_key, 1.0, GF_InputBinding.Mode.IMPULSE))


func _key_event(p_key: Key, p_pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = p_key
	ev.pressed = p_pressed
	return ev


func _tick(p_delta: float = 0.016) -> void:
	_router._process(p_delta)


# ============================================================
# just_pressed 帧语义
# ============================================================

func test_just_pressed_true_only_on_press_frame() -> void:
	_register_impulse("toggle", KEY_E)

	# 帧 N：KeyDown → 结算
	_router._unhandled_input(_key_event(KEY_E, true))
	_tick()
	assert_true(_resolver.is_just_pressed("toggle"), "按下帧 just_pressed 应为 true")

	# 帧 N+1：无事件（按住中）→ just_pressed 不得粘住；
	# IMPULSE 是帧脉冲语义，released 在脉冲消失的第一帧触发（持续态动作应使用 HELD 模式）
	_tick()
	assert_false(_resolver.is_just_pressed("toggle"), "按住帧 just_pressed 应为 false（粘住回归）")
	assert_true(_resolver.is_just_released("toggle"), "IMPULSE released 在脉冲消失帧触发")
	_tick()
	assert_false(_resolver.is_just_pressed("toggle"), "连续无事件帧 just_pressed 应保持 false")
	assert_false(_resolver.is_just_released("toggle"), "released 不粘住")

	# 帧 N+M：KeyUp 后 IMPULSE 无持续态，各标志已回落
	_router._unhandled_input(_key_event(KEY_E, false))
	_tick()
	assert_false(_resolver.is_just_pressed("toggle"))
	assert_false(_resolver.is_pressed("toggle"), "KeyUp 后 IMPULSE 无持续态")
	assert_false(_resolver.is_just_released("toggle"))


func test_just_pressed_again_on_second_press() -> void:
	_register_impulse("toggle", KEY_E)

	_router._unhandled_input(_key_event(KEY_E, true))
	_tick()
	_tick()
	_router._unhandled_input(_key_event(KEY_E, false))
	_tick()

	# 第二次按下应再次触发
	_router._unhandled_input(_key_event(KEY_E, true))
	_tick()
	assert_true(_resolver.is_just_pressed("toggle"), "第二次按下应再次 just_pressed")


func test_multi_event_frame_counts_once() -> void:
	_register_impulse("toggle", KEY_E)

	# 同一帧两个 KeyDown 事件：最终 just_pressed 仍只表示"本帧按下"
	_router._unhandled_input(_key_event(KEY_E, true))
	_router._unhandled_input(_key_event(KEY_E, true))
	_tick()
	assert_true(_resolver.is_just_pressed("toggle"))
	_tick()
	assert_false(_resolver.is_just_pressed("toggle"), "下一帧不应粘住")


# HELD 语义与 read_axis 时点安全在 test_input_action_state.gd 的 state 层验证
# （binding.is_down() 依赖物理键状态，headless 测试无法提供）
