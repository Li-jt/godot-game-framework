## InputActionState — 单个动作的运行时状态（v4.0）。
## 仅维护值与标记，不做跨动作调度。由 ActionResolver 驱动。
class_name InputActionState
extends RefCounted

## 最终输出值
var value: float = 0.0
var smoothed_value: float = 0.0
var pressed: bool = false
var just_pressed: bool = false
var just_released: bool = false

var _impulse_acc: float = 0.0
var _held_acc: float = 0.0
var _analog_acc: float = 0.0
var _was_pressed: bool = false
var _had_input_this_frame: bool = false


func begin_frame() -> void:
	_impulse_acc = 0.0
	_analog_acc = 0.0
	_was_pressed = pressed
	_had_input_this_frame = false


func accumulate_impulse(p_value: float) -> void:
	_impulse_acc += p_value
	_had_input_this_frame = true


func accumulate_held(p_value: float) -> void:
	_held_acc = p_value
	_had_input_this_frame = true


func accumulate_analog(p_value: float) -> void:
	_analog_acc = p_value
	_had_input_this_frame = true


func finalize(p_def: InputActionDef, p_delta: float) -> void:
	# 1. compose
	var raw: float
	match p_def.compose_mode:
		InputActionDef.ComposeMode.SUM:
			raw = _impulse_acc + _held_acc + _analog_acc
		InputActionDef.ComposeMode.MAX:
			raw = maxf(maxf(_impulse_acc, _held_acc), _analog_acc)
		InputActionDef.ComposeMode.AVERAGE:
			var count := 0
			if absf(_held_acc) > 0.0: count += 1
			if absf(_analog_acc) > 0.0: count += 1
			raw = (_impulse_acc + _held_acc + _analog_acc) / maxf(1.0, float(count))
		_:
			raw = _impulse_acc + _held_acc + _analog_acc

	# 2. deadzone
	if absf(raw) < p_def.deadzone:
		raw = 0.0

	# 3. sensitivity
	value = raw * p_def.sensitivity

	# 4. smoothing
	if p_def.smoothing > 0.0:
		var t: float = clampf(p_def.smoothing * p_delta * 60.0, 0.0, 1.0)
		smoothed_value = lerpf(smoothed_value, value, t)
	else:
		smoothed_value = value

	# 5. pressed / just flags
	pressed = absf(value) > 0.0001
	just_pressed = pressed and not _was_pressed and _had_input_this_frame
	just_released = not pressed and _was_pressed
