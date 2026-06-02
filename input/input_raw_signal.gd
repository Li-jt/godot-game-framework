## InputRawSignal — 设备归一化后的中间态信号（v4.0）。
## DeviceNormalizer 将 Godot InputEvent 转为此格式，ActionResolver 据此匹配 binding。
class_name InputRawSignal
extends RefCounted

## 设备源类型（同 InputBinding.Source）
var source: int = 0
## 设备码（keycode / button_index / joy_axis）
var code: int = 0
## 是否为按下事件
var is_press: bool = false
## 是否为释放事件
var is_release: bool = false
## 模拟量值（ANALOG 模式用）
var analog_value: float = 0.0
## 指针位置（鼠标/触控事件用，无则为 Vector2.INF）
var pointer_pos: Vector2 = Vector2.INF
## 设备 ID（-1 表示任意）
var device_id: int = -1
## 时间戳（msec）
var timestamp_msec: int = 0
## 原始 Godot 事件引用（调试/回退用）
var original_event: InputEvent = null


func _init(p_source: int = 0, p_code: int = 0, p_is_press: bool = false,
	p_analog: float = 0.0, p_pos: Vector2 = Vector2.INF, p_device: int = -1) -> void:
	source = p_source; code = p_code; is_press = p_is_press
	analog_value = p_analog; pointer_pos = p_pos; device_id = p_device


## 是否为空间事件（鼠标/触控）。用于 InputPolicy 判定是否需要 UI 阻挡。
func is_spatial() -> bool:
	return source in [
		InputBinding.Source.MOUSE_BUTTON, InputBinding.Source.MOUSE_WHEEL,
		InputBinding.Source.TOUCH_PAN, InputBinding.Source.TOUCH_MAGNIFY,
	]
