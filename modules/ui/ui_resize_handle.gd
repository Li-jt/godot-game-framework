## GF_ResizeHandle
## 窗口缩放手柄。挂到窗口场景的边缘 Control 上（见 scenes/ui/window_shell.tscn）。
## _ready 沿父链自动找祖先 GF_UIWindow，Inspector 下拉选择方向。
## 8 个手柄共用同一段缩放逻辑：位标志组合判断，N/W 方向缩放时窗口 position 同步收缩。
class_name GF_ResizeHandle
extends Control

## 位标志：LEFT=1, RIGHT=2, TOP=4, BOTTOM=8；角方向 = 两个边方向的组合。
## Inspector 中下拉选择。
@export var edge: Edge = Edge.RIGHT

enum Edge {
	LEFT = 1,
	RIGHT = 2,
	TOP = 4,
	BOTTOM = 8,
	TOP_LEFT = 5,
	TOP_RIGHT = 6,
	BOTTOM_LEFT = 9,
	BOTTOM_RIGHT = 10,
}

var _window: GF_UIWindow = null
var _press_size := Vector2.ZERO
var _press_mouse := Vector2.ZERO   # 窗口本地坐标
var _is_resizing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = _cursor_for_edge(edge)
	_window = _find_window()


func _gui_input(event: InputEvent) -> void:
	if _window == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_is_resizing = true
			_press_size = _window.size
			_press_mouse = mb.position + position   # 手柄本地 → 窗口本地
			_window.request_focus()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _is_resizing:
				_is_resizing = false
				_window.notify_resize_finished()
	elif event is InputEventMouseMotion and _is_resizing:
		var mm := event as InputEventMouseMotion
		_apply_resize(mm.position + position)


func _apply_resize(p_mouse_local: Vector2) -> void:
	var delta := p_mouse_local - _press_mouse
	var min_size := _window.get_window_min_size()
	var new_size := _press_size
	var new_pos := _window.position

	# 位标志判断：角方向（TOP_LEFT 等）两个分支都会命中
	if edge & Edge.LEFT:
		new_size.x = maxf(min_size.x, _press_size.x - delta.x)
		new_pos.x = _window.position.x + (_press_size.x - new_size.x)
	if edge & Edge.RIGHT:
		new_size.x = maxf(min_size.x, _press_size.x + delta.x)
	if edge & Edge.TOP:
		new_size.y = maxf(min_size.y, _press_size.y - delta.y)
		new_pos.y = _window.position.y + (_press_size.y - new_size.y)
	if edge & Edge.BOTTOM:
		new_size.y = maxf(min_size.y, _press_size.y + delta.y)

	_window.size = new_size
	_window.position = new_pos


# ============================================================
# 内部辅助
# ============================================================

func _cursor_for_edge(p_edge: int) -> Control.CursorShape:
	match p_edge:
		Edge.LEFT, Edge.RIGHT:
			return Control.CURSOR_HSIZE
		Edge.TOP, Edge.BOTTOM:
			return Control.CURSOR_VSIZE
		Edge.TOP_LEFT, Edge.BOTTOM_RIGHT:
			return Control.CURSOR_FDIAGSIZE
		Edge.TOP_RIGHT, Edge.BOTTOM_LEFT:
			return Control.CURSOR_BDIAGSIZE
	return Control.CURSOR_ARROW


func _find_window() -> GF_UIWindow:
	var node := get_parent()
	while node != null:
		if node is GF_UIWindow:
			return node as GF_UIWindow
		node = node.get_parent()
	push_warning("GF_ResizeHandle 未找到祖先 GF_UIWindow，缩放手柄失效")
	return null
