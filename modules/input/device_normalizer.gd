## GF_DeviceNormalizer — 设备归一化器（v4.0）。
## 将 Godot InputEvent 转为 GF_InputRawSignal 列表，消除下游对 Godot 事件类型的依赖。
##
## Godot 4.7 兼容：键盘/鼠标的 device 值从 0 变为专用常量。
## 本归一化器从 InputEvent 中提取真实 device 值，并通过常量暴露 4.7 语义。
class_name GF_DeviceNormalizer
extends RefCounted

## Godot 4.7+ 键盘设备固定 ID（4.6 及以前为 0）。
const DEVICE_ID_KEYBOARD: int = 16
## Godot 4.7+ 鼠标设备固定 ID（4.6 及以前为 0）。
const DEVICE_ID_MOUSE: int = 32


## 将单个 InputEvent 转为 0..N 个 GF_InputRawSignal。
func normalize(p_event: InputEvent) -> Array[GF_InputRawSignal]:
	var result: Array[GF_InputRawSignal] = []
	var dev: int = p_event.device

	if p_event is InputEventKey:
		var ke := p_event as InputEventKey
		# 键盘自动重复（echo）不是新的按下：长按超过系统重复延迟后，echo 流
		# （约 30ms 间隔、pressed=true）会让 IMPULSE 动作每帧重复触发
		# （如面板 toggle 开关闪烁），在归一化层直接过滤
		if ke.echo:
			return result
		result.append(GF_InputRawSignal.new(
			GF_InputBinding.Source.KEYBOARD, ke.keycode, ke.pressed,
			0.0, Vector2.INF, dev))

	elif p_event is InputEventMouseButton:
		var mb := p_event as InputEventMouseButton
		# 鼠标滚轮独立为一个 source
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			result.append(GF_InputRawSignal.new(
				GF_InputBinding.Source.MOUSE_WHEEL, mb.button_index, true,
				float(mb.factor), mb.global_position, dev))
		else:
			result.append(GF_InputRawSignal.new(
				GF_InputBinding.Source.MOUSE_BUTTON, mb.button_index, mb.pressed,
				0.0, mb.global_position, dev))

	elif p_event is InputEventJoypadButton:
		var jb := p_event as InputEventJoypadButton
		result.append(GF_InputRawSignal.new(
			GF_InputBinding.Source.GAMEPAD_BUTTON, jb.button_index, jb.pressed,
			0.0, Vector2.INF, dev))

	elif p_event is InputEventJoypadMotion:
		var jm := p_event as InputEventJoypadMotion
		result.append(GF_InputRawSignal.new(
			GF_InputBinding.Source.GAMEPAD_AXIS, jm.axis, true,
			jm.axis_value, Vector2.INF, dev))

	elif p_event is InputEventPanGesture:
		var pan := p_event as InputEventPanGesture
		result.append(GF_InputRawSignal.new(
			GF_InputBinding.Source.TOUCH_PAN, 0, true,
			pan.delta.y, pan.position, dev))

	elif p_event is InputEventMagnifyGesture:
		var mg := p_event as InputEventMagnifyGesture
		result.append(GF_InputRawSignal.new(
			GF_InputBinding.Source.TOUCH_MAGNIFY, 0, true,
			mg.factor, Vector2.INF, dev))

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
