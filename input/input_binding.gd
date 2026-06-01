## InputBinding — 单条设备绑定。
## 描述一种物理输入如何映射到动作值。每种设备源类型有各自的匹配逻辑和取值方式。
class_name InputBinding
extends RefCounted

## 设备源类型
enum Source {
	KEYBOARD,        ## InputEventKey → keycode
	MOUSE_BUTTON,    ## InputEventMouseButton（非滚轮按钮）
	MOUSE_WHEEL,     ## InputEventMouseButton（滚轮上/下）
	GAMEPAD_BUTTON,  ## InputEventJoypadButton → button_index
	GAMEPAD_AXIS,    ## InputEventJoypadMotion → axis + axis_value
	TOUCH_PAN,       ## InputEventPanGesture → delta.y
	TOUCH_MAGNIFY,   ## InputEventMagnifyGesture → factor
}

## 输出模式
enum Mode {
	IMPULSE,  ## 事件触发时产出一个脉冲值，下一帧自动归零（滚轮每格、按钮点击）
	HELD,     ## 按住时每帧轮询当前状态（键盘按键、鼠标拖拽）
	ANALOG,   ## 映射原始模拟量到输出范围（手柄摇杆/扳机、触控手势）
}

## 设备源类型
var source: int = Source.KEYBOARD
## 设备码。含义取决于 source：keycode / button_index / joy_axis
var code: int = 0
## 输出缩放。如 KEY_E 设为 -1.0 实现反方向
var scale: float = 1.0
## 输出模式
var mode: int = Mode.HELD
## 是否为负半轴（仅 GAMEPAD_AXIS 模式，区分正负方向）
var negative_axis: bool = false


func _init(p_source: int, p_code: int = 0, p_scale: float = 1.0, p_mode: int = Mode.HELD, p_negative: bool = false) -> void:
	source = p_source
	code = p_code
	scale = p_scale
	mode = p_mode
	negative_axis = p_negative


## 判断给定原始事件是否匹配此绑定。
func matches(p_event: InputEvent) -> bool:
	match source:
		Source.KEYBOARD:
			if p_event is InputEventKey:
				return (p_event as InputEventKey).keycode == code
		Source.MOUSE_BUTTON:
			if p_event is InputEventMouseButton:
				var mb := p_event as InputEventMouseButton
				if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
					return false
				return mb.button_index == code
		Source.MOUSE_WHEEL:
			if p_event is InputEventMouseButton:
				return (p_event as InputEventMouseButton).button_index == code
		Source.GAMEPAD_BUTTON:
			if p_event is InputEventJoypadButton:
				return (p_event as InputEventJoypadButton).button_index == code
		Source.GAMEPAD_AXIS:
			if p_event is InputEventJoypadMotion:
				return (p_event as InputEventJoypadMotion).axis == code
		Source.TOUCH_PAN:
			return p_event is InputEventPanGesture
		Source.TOUCH_MAGNIFY:
			return p_event is InputEventMagnifyGesture
	return false


## 从原始事件中提取模拟量值（ANALOG 模式用）。
func extract_analog(p_event: InputEvent) -> float:
	match source:
		Source.GAMEPAD_AXIS:
			var jm := p_event as InputEventJoypadMotion
			if jm == null: return 0.0
			return -jm.axis_value if negative_axis else jm.axis_value
		Source.TOUCH_PAN:
			var pan := p_event as InputEventPanGesture
			if pan == null: return 0.0
			return pan.delta.y
		Source.TOUCH_MAGNIFY:
			var mg := p_event as InputEventMagnifyGesture
			if mg == null: return 0.0
			return mg.factor - 1.0
	return 0.0


## 检查事件是否为"按下"动作（IMPULSE 模式用）。
func is_press_event(p_event: InputEvent) -> bool:
	match source:
		Source.KEYBOARD:
			if p_event is InputEventKey:
				return (p_event as InputEventKey).pressed
		Source.MOUSE_BUTTON:
			if p_event is InputEventMouseButton:
				return (p_event as InputEventMouseButton).pressed
		Source.MOUSE_WHEEL:
			return true  # 滚轮事件 pressed 恒为 false，但应始终触发
		Source.GAMEPAD_BUTTON:
			if p_event is InputEventJoypadButton:
				return (p_event as InputEventJoypadButton).pressed
		Source.GAMEPAD_AXIS, Source.TOUCH_PAN, Source.TOUCH_MAGNIFY:
			return true
	return false


## 检查 HELD 绑定当前是否按住（HELD 模式每帧轮询用）。
func is_down() -> bool:
	match source:
		Source.KEYBOARD:
			return Input.is_key_pressed(code)
		Source.MOUSE_BUTTON:
			return Input.is_mouse_button_pressed(code)
	return false
