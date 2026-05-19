## InputAdapter
## 统一输入适配层。封装 Godot Input 单例，提供动作查询和鼠标位置。
## 所有模块的输入读取必须通过此服务，禁止直接使用 `Input.is_action_pressed()` 等。
##
## 后续由 InputService（T3-4）在此基础上扩展输入上下文、UI/Game 输入分离等。
##
## 使用方式：
##   [codeblock]
##   var input: InputAdapter = injected_input_adapter
##   if input.is_action_just_pressed("ui_accept"):
##       do_something()
##   var mouse_pos := input.mouse_position()
##   [/codeblock]
class_name InputAdapter
extends RefCounted

var blocked: bool = false


# ============================================================
# 动作查询
# ============================================================

## 动作是否按住
func is_action_pressed(p_action: String) -> bool:
	if blocked:
		return false
	return Input.is_action_pressed(p_action)


## 动作是否刚按下（仅触发一次）
func is_action_just_pressed(p_action: String) -> bool:
	if blocked:
		return false
	return Input.is_action_just_pressed(p_action)


## 动作是否刚释放
func is_action_just_released(p_action: String) -> bool:
	if blocked:
		return false
	return Input.is_action_just_released(p_action)


## 动作的模拟量强度（0.0 ~ 1.0，手柄摇杆/触控用）
func get_action_strength(p_action: String) -> float:
	if blocked:
		return 0.0
	return Input.get_action_strength(p_action)


## 获取当前按下的动作所对应的输入方向向量（WASD/摇杆）
func get_vector(p_negative_x: String, p_positive_x: String, p_negative_y: String, p_positive_y: String, p_deadzone: float = -1.0) -> Vector2:
	if blocked:
		return Vector2.ZERO
	return Input.get_vector(p_negative_x, p_positive_x, p_negative_y, p_positive_y, p_deadzone)


# ============================================================
# 鼠标
# ============================================================

## 鼠标屏幕坐标
func mouse_position() -> Vector2:
	return _get_mouse_position_raw()


## 鼠标是否在窗口内
func is_mouse_in_window() -> bool:
	var pos := _get_mouse_position_raw()
	var size := DisplayServer.window_get_size()
	var rect := Rect2(Vector2.ZERO, size)
	return rect.has_point(pos)


# ============================================================
# 输入屏蔽
# ============================================================

## 屏蔽所有输入（UI 模态时调用）
func block() -> void:
	blocked = true


## 解除输入屏蔽
func unblock() -> void:
	blocked = false


# ============================================================
# 内部
# ============================================================

func _get_mouse_position_raw() -> Vector2:
	return DisplayServer.mouse_get_position()
