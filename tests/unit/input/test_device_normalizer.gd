# tests/unit/input/test_device_normalizer.gd
extends GutTest

var _normalizer: GF_DeviceNormalizer


func before_each() -> void:
	_normalizer = GF_DeviceNormalizer.new()


func after_each() -> void:
	_normalizer = null


func test_normalize_key_press_produces_keyboard_signal() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	event.device = 16

	var signals: Array[GF_InputRawSignal] = _normalizer.normalize(event)
	assert_eq(signals.size(), 1)
	assert_eq(signals[0].source, GF_InputBinding.Source.KEYBOARD)
	assert_eq(signals[0].code, KEY_SPACE)
	assert_true(signals[0].is_press)
	assert_eq(signals[0].device_id, 16)


func test_normalize_key_release_is_press_false() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_A
	event.pressed = false

	var signals: Array[GF_InputRawSignal] = _normalizer.normalize(event)
	assert_eq(signals.size(), 1)
	assert_false(signals[0].is_press)


func test_normalize_key_echo_is_filtered() -> void:
	# 长按产生的键盘自动重复（echo）不是新的按下，不应产生信号
	# （否则 IMPULSE 动作会每帧重复触发，面板 toggle 闪烁）
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	event.echo = true

	var signals: Array[GF_InputRawSignal] = _normalizer.normalize(event)
	assert_eq(signals.size(), 0, "echo 事件不应产生信号")


func test_normalize_key_release_never_echo() -> void:
	# 松开事件 echo 恒为 false，正常产生 pressed=false 信号
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = false

	var signals: Array[GF_InputRawSignal] = _normalizer.normalize(event)
	assert_eq(signals.size(), 1, "松开事件应正常归一化")
	assert_false(signals[0].is_press)


func test_normalize_mouse_button_produces_button_signal() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true

	var signals: Array[GF_InputRawSignal] = _normalizer.normalize(event)
	assert_eq(signals.size(), 1)
	assert_eq(signals[0].source, GF_InputBinding.Source.MOUSE_BUTTON)


func test_is_pointer_event_detects_mouse_motion() -> void:
	var event := InputEventMouseMotion.new()
	assert_true(_normalizer.is_pointer_event(event))


func test_is_pointer_event_detects_mouse_button() -> void:
	var event := InputEventMouseButton.new()
	assert_true(_normalizer.is_pointer_event(event))


func test_is_pointer_event_false_for_keyboard() -> void:
	var event := InputEventKey.new()
	assert_false(_normalizer.is_pointer_event(event))


func test_normalize_handles_action_event() -> void:
	var event := InputEventAction.new()
	# Action 事件不被 normalizer 处理
	var signals: Array[GF_InputRawSignal] = _normalizer.normalize(event)
	assert_eq(signals.size(), 0)
