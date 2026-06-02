## InputBinding — 单条设备绑定（v4.0）。
## 描述一种物理输入如何映射到动作值。
class_name InputBinding
extends RefCounted

enum Source {
	KEYBOARD, MOUSE_BUTTON, MOUSE_WHEEL,
	GAMEPAD_BUTTON, GAMEPAD_AXIS,
	TOUCH_PAN, TOUCH_MAGNIFY,
}
enum Mode { IMPULSE, HELD, ANALOG }
enum Slot { PRIMARY, SECONDARY }

var source: int = Source.KEYBOARD
var code: int = 0
var scale: float = 1.0
var mode: int = Mode.HELD
var negative_axis: bool = false
var device_id: int = -1
var slot: int = Slot.PRIMARY
var priority: int = 0


func _init(p_source: int, p_code: int = 0, p_scale: float = 1.0, p_mode: int = Mode.HELD,
	p_negative: bool = false, p_slot: int = Slot.PRIMARY, p_device: int = -1) -> void:
	source = p_source; code = p_code; scale = p_scale; mode = p_mode
	negative_axis = p_negative; slot = p_slot; device_id = p_device


## 匹配 RawSignal（v4.0 新主接口）。
func matches_signal(p_signal: InputRawSignal) -> bool:
	if source != p_signal.source or code != p_signal.code:
		return false
	if device_id != -1 and p_signal.device_id != -1 and device_id != p_signal.device_id:
		return false
	return true


## 匹配 Godot InputEvent（向后兼容）。
func matches(p_event: InputEvent) -> bool:
	match source:
		Source.KEYBOARD:
			return p_event is InputEventKey and (p_event as InputEventKey).keycode == code
		Source.MOUSE_BUTTON:
			if p_event is InputEventMouseButton:
				var mb := p_event as InputEventMouseButton
				if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
					return false
				return mb.button_index == code
		Source.MOUSE_WHEEL:
			return p_event is InputEventMouseButton and (p_event as InputEventMouseButton).button_index == code
		Source.GAMEPAD_BUTTON:
			return p_event is InputEventJoypadButton and (p_event as InputEventJoypadButton).button_index == code
		Source.GAMEPAD_AXIS:
			return p_event is InputEventJoypadMotion and (p_event as InputEventJoypadMotion).axis == code
		Source.TOUCH_PAN:
			return p_event is InputEventPanGesture
		Source.TOUCH_MAGNIFY:
			return p_event is InputEventMagnifyGesture
	return false


func extract_analog(p_event: InputEvent) -> float:
	match source:
		Source.GAMEPAD_AXIS:
			var jm := p_event as InputEventJoypadMotion
			return (-jm.axis_value if negative_axis else jm.axis_value) if jm != null else 0.0
		Source.TOUCH_PAN:
			var pan := p_event as InputEventPanGesture
			return pan.delta.y if pan != null else 0.0
		Source.TOUCH_MAGNIFY:
			var mg := p_event as InputEventMagnifyGesture
			return (mg.factor - 1.0) if mg != null else 0.0
	return 0.0


func is_press_event(p_event: InputEvent) -> bool:
	match source:
		Source.KEYBOARD:
			return p_event is InputEventKey and (p_event as InputEventKey).pressed
		Source.MOUSE_BUTTON:
			return p_event is InputEventMouseButton and (p_event as InputEventMouseButton).pressed
		Source.MOUSE_WHEEL:
			return true
		Source.GAMEPAD_BUTTON:
			return p_event is InputEventJoypadButton and (p_event as InputEventJoypadButton).pressed
		Source.GAMEPAD_AXIS, Source.TOUCH_PAN, Source.TOUCH_MAGNIFY:
			return true
	return false


func is_down() -> bool:
	match source:
		Source.KEYBOARD:      return Input.is_key_pressed(code)
		Source.MOUSE_BUTTON:  return Input.is_mouse_button_pressed(code)
	return false


## 深拷贝。
func duplicate_binding() -> InputBinding:
	return InputBinding.new(source, code, scale, mode, negative_axis, slot, device_id)


## 序列化（存档用）。
func to_dict() -> Dictionary:
	return {"source": source, "code": code, "scale": scale, "mode": mode,
		"negative_axis": negative_axis, "device_id": device_id, "slot": slot}


## 反序列化。
static func from_dict(p_data: Dictionary) -> InputBinding:
	return InputBinding.new(
		p_data.get("source", 0), p_data.get("code", 0),
		p_data.get("scale", 1.0), p_data.get("mode", Mode.HELD),
		p_data.get("negative_axis", false), p_data.get("slot", Slot.PRIMARY),
		p_data.get("device_id", -1))
