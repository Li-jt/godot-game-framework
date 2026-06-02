## DeviceNormalizer — 设备归一化器（v4.0）。
## 将 Godot InputEvent 转为 InputRawSignal 列表，消除下游对 Godot 事件类型的依赖。
class_name DeviceNormalizer
extends RefCounted


## 将单个 InputEvent 转为 0..N 个 InputRawSignal。
func normalize(p_event: InputEvent) -> Array[InputRawSignal]:
	var result: Array[InputRawSignal] = []

	if p_event is InputEventKey:
		var ke := p_event as InputEventKey
		result.append(InputRawSignal.new(
			InputBinding.Source.KEYBOARD, ke.keycode, ke.pressed,
			0.0, Vector2.INF, -1))

	elif p_event is InputEventMouseButton:
		var mb := p_event as InputEventMouseButton
		# 鼠标滚轮独立为一个 source
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			result.append(InputRawSignal.new(
				InputBinding.Source.MOUSE_WHEEL, mb.button_index, true,
				float(mb.factor), mb.global_position, -1))
		else:
			result.append(InputRawSignal.new(
				InputBinding.Source.MOUSE_BUTTON, mb.button_index, mb.pressed,
				0.0, mb.global_position, -1))

	elif p_event is InputEventJoypadButton:
		var jb := p_event as InputEventJoypadButton
		result.append(InputRawSignal.new(
			InputBinding.Source.GAMEPAD_BUTTON, jb.button_index, jb.pressed,
			0.0, Vector2.INF, -1))

	elif p_event is InputEventJoypadMotion:
		var jm := p_event as InputEventJoypadMotion
		result.append(InputRawSignal.new(
			InputBinding.Source.GAMEPAD_AXIS, jm.axis, true,
			jm.axis_value, Vector2.INF, -1))

	elif p_event is InputEventPanGesture:
		var pan := p_event as InputEventPanGesture
		result.append(InputRawSignal.new(
			InputBinding.Source.TOUCH_PAN, 0, true,
			pan.delta.y, pan.position, -1))

	elif p_event is InputEventMagnifyGesture:
		var mg := p_event as InputEventMagnifyGesture
		result.append(InputRawSignal.new(
			InputBinding.Source.TOUCH_MAGNIFY, 0, true,
			mg.factor, Vector2.INF, -1))

	# 设置时间戳
	var now := Time.get_ticks_msec()
	for sig in result:
		sig.timestamp_msec = now
		sig.original_event = p_event

	return result


## 该事件是否为空间事件（鼠标/触控）？
func is_pointer_event(p_event: InputEvent) -> bool:
	return p_event is InputEventMouse or p_event is InputEventPanGesture or p_event is InputEventMagnifyGesture


## 从事件中提取指针位置。无位置时返回 Vector2.INF。
func extract_pointer_position(p_event: InputEvent) -> Vector2:
	if p_event is InputEventMouse:
		return (p_event as InputEventMouse).global_position
	if p_event is InputEventPanGesture:
		return (p_event as InputEventPanGesture).position
	return Vector2.INF
