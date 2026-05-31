## InputAdapter
## 统一输入适配层。封装 Godot Input 单例，提供动作查询、轴读取和鼠标位置。
## 所有模块的输入读取必须通过此类，禁止直接使用 Input / _input / _unhandled_input。
##
## 使用方式：
##   var adapter: InputAdapter = ...
##   if adapter.is_action_just_pressed("ui_accept"):
##       do_something()
##   var zoom := adapter.read_axis("camera_zoom")  # 滚轮/手柄兼容
class_name InputAdapter
extends RefCounted

var blocked: bool = false


# ============================================================
# 二进制动作查询
# ============================================================

## 动作是否按住。
func is_action_pressed(p_action: String) -> bool:
	if blocked: return false
	return Input.is_action_pressed(p_action)


## 动作是否刚按下（仅触发一次）。
func is_action_just_pressed(p_action: String) -> bool:
	if blocked: return false
	return Input.is_action_just_pressed(p_action)


## 动作是否刚释放。
func is_action_just_released(p_action: String) -> bool:
	if blocked: return false
	return Input.is_action_just_released(p_action)


## 动作的模拟量强度（0.0 ~ 1.0，手柄摇杆/扳机）。
func get_action_strength(p_action: String) -> float:
	if blocked: return 0.0
	return Input.get_action_strength(p_action)


## 获取方向向量（WASD/摇杆）。
func get_vector(p_negative_x: String, p_positive_x: String, p_negative_y: String, p_positive_y: String, p_deadzone: float = -1.0) -> Vector2:
	if blocked: return Vector2.ZERO
	return Input.get_vector(p_negative_x, p_positive_x, p_negative_y, p_positive_y, p_deadzone)


# ============================================================
# 轴读取（v2.0 新增）
# ============================================================

## 读取指定逻辑动作对应的组合轴值。
## 会聚合所有 input_map_actions 的 get_action_strength 和鼠标滚轮增量。
## 返回值范围通常为 -1.0 ~ 1.0（滚轮根据 factor 缩放）。
func read_axis(p_input_map_actions: Array[String], p_sensitivity: float = 1.0, p_deadzone: float = 0.1) -> float:
	if blocked: return 0.0
	var total: float = 0.0
	for action_name in p_input_map_actions:
		var name := str(action_name)
		# Godot InputMap 动作：读 strength
		total += Input.get_action_strength(name)
		# 鼠标滚轮：通过 is_action_just_pressed 获取增量
		if Input.is_action_just_pressed(name):
			# 判断正负方向
			var ev_list := InputMap.action_get_events(StringName(name))
			for ev in ev_list:
				if ev is InputEventMouseButton:
					var mb := ev as InputEventMouseButton
					match mb.button_index:
						MOUSE_BUTTON_WHEEL_UP:
							total += absf(mb.factor) if mb.factor != 0.0 else 1.0
						MOUSE_BUTTON_WHEEL_DOWN:
							total -= absf(mb.factor) if mb.factor != 0.0 else 1.0
	total *= p_sensitivity
	if absf(total) < p_deadzone: return 0.0
	return clampf(total, -1.0, 1.0)


# ============================================================
# 鼠标
# ============================================================

## 鼠标屏幕坐标。
func mouse_position() -> Vector2:
	return DisplayServer.mouse_get_position()


## 鼠标是否在窗口内。
func is_mouse_in_window() -> bool:
	var pos := DisplayServer.mouse_get_position()
	var size := DisplayServer.window_get_size()
	return Rect2(Vector2.ZERO, size).has_point(pos)


# ============================================================
# 输入屏蔽
# ============================================================

## 屏蔽所有输入（UI 模态时调用）。
func block() -> void:
	blocked = true


## 解除输入屏蔽。
func unblock() -> void:
	blocked = false
