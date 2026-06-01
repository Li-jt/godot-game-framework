## InputActionState — 单个动作的运行时状态（v3.0）。
## ActionResolver 每帧更新，InputService 对外暴露读取。
## 生命周期：end_frame() 被调用 → 合成值 → 清零脉冲供下帧。
class_name InputActionState
extends RefCounted

var _def: InputActionDef

## 本帧 IMPULSE 绑定累加脉冲值
var _impulse_value: float = 0.0
## 本帧 HELD 绑定当前值（每帧 poll_held 覆盖）
var _held_value: float = 0.0
## 本帧 ANALOG 绑定原始值
var _analog_value: float = 0.0

## 二进制按下状态
var _pressed: bool = false
## 本帧是否刚按下
var _just_pressed: bool = false
## 本帧是否刚释放
var _just_released: bool = false

## 最终输出值（未经平滑）
var value: float = 0.0
## 平滑后的输出值
var smoothed_value: float = 0.0


func _init(p_def: InputActionDef) -> void:
	_def = p_def


## 处理匹配到的原始事件（由 ActionResolver.process_event 调用）。
func apply_event(p_event: InputEvent, p_binding: InputBinding) -> void:
	match p_binding.mode:
		InputBinding.Mode.IMPULSE:
			if p_binding.is_press_event(p_event):
				_impulse_value += p_binding.scale
				_just_pressed = true
				_pressed = true
		InputBinding.Mode.HELD:
			pass  # HELD 由 poll_held() 每帧轮询，不在这里处理
		InputBinding.Mode.ANALOG:
			_analog_value = p_binding.extract_analog(p_event) * p_binding.scale


## 在新帧开始处理事件前调用，清零上一帧的脉冲值和释放标记。
## _pressed 不清零：由 _poll_held 每帧覆盖，或由 end_frame 延迟清零。
func begin_frame() -> void:
	_impulse_value = 0.0
	_analog_value = 0.0
	_just_pressed = false
	_just_released = false


## 每帧结束时调用：轮询 HELD → 合成 → 死区/灵敏度/平滑。
func end_frame(p_delta: float) -> void:
	# 0. 延迟清零上一帧的 _pressed（确保本帧 is_pressed 读取后才清）
	if not _has_held_binding():
		_pressed = false

	# 1. 轮询 HELD 绑定
	_poll_held()

	# 2. 合成原始值
	var raw: float = 0.0
	match _def.compose_mode:
		InputActionDef.ComposeMode.SUM:
			raw = _impulse_value + _held_value + _analog_value
		InputActionDef.ComposeMode.MAX:
			raw = maxf(maxf(_impulse_value, _held_value), _analog_value)
		InputActionDef.ComposeMode.AVERAGE:
			var count := 0
			if absf(_held_value) > 0.0: count += 1
			if absf(_analog_value) > 0.0: count += 1
			var divisor: float = maxf(1.0, float(count))
			raw = (_impulse_value + _held_value + _analog_value) / divisor

	# 3. 死区
	if absf(raw) < _def.deadzone:
		raw = 0.0

	# 4. 灵敏度
	value = raw * _def.sensitivity

	# 5. 平滑（指数移动平均）
	if _def.smoothing > 0.0:
		var t: float = clampf(_def.smoothing * p_delta * 60.0, 0.0, 1.0)
		smoothed_value = lerpf(smoothed_value, value, t)
	else:
		smoothed_value = value

	# 6. _pressed 延迟清零（IMPULSE 动作确保 is_pressed 在整帧有效）
	# 下一帧 begin_frame 会通过 _poll_held/apply_event 重新设置 _pressed


## 每帧轮询所有 HELD 绑定的当前状态。
## 如果该动作没有 HELD 绑定，不修改 _pressed，保留 IMPULSE 或 ANALOG 设置的值。
func _poll_held() -> void:
	if not _has_held_binding():
		return
	var was_pressed := _pressed
	var held: float = 0.0
	for binding in _def.bindings:
		if binding.mode != InputBinding.Mode.HELD:
			continue
		if binding.is_down():
			held = maxf(absf(held), absf(binding.scale))
			if binding.scale < 0.0:
				held = -held
			break  # 取第一个按住的 HELD 绑定
	_held_value = held
	_pressed = held != 0.0
	if _pressed and not was_pressed:
		_just_pressed = true
	if not _pressed and was_pressed:
		_just_released = true


func _has_held_binding() -> bool:
	for binding in _def.bindings:
		if binding.mode == InputBinding.Mode.HELD:
			return true
	return false
