## InputProvider — 输入事件收集器 Node（v3.0）。
## 使用 _input 接收所有原始事件（_unhandled_input 在 CanvasLayer 场景下可能丢鼠标事件）。
## 空间 UI 检测：鼠标在 mouse_filter=STOP 的 Control 上时跳过，避免穿透 UI。
class_name InputProvider
extends Node

var _resolver: ActionResolver = null
var _mouse_pos: Vector2 = Vector2.ZERO
var _last_frame: int = -1


func configure(p_resolver: ActionResolver) -> void:
	_resolver = p_resolver
	set_process(true)


func _ready() -> void:
	set_process(true)


func _input(p_event: InputEvent) -> void:
	if _resolver == null:
		return

	# 帧切换时清零各动作的脉冲状态
	var current_frame := Engine.get_process_frames()
	if current_frame != _last_frame:
		_last_frame = current_frame
		for state in _resolver._states.values():
			state.begin_frame()

	# 更新鼠标位置
	if p_event is InputEventMouse:
		_mouse_pos = (p_event as InputEventMouse).global_position

	# 有空间冲突的事件类型：检查鼠标是否在遮挡 UI 上
	if p_event is InputEventMouseButton or p_event is InputEventMouseMotion:
		if _is_mouse_over_blocking_ui(_mouse_pos):
			return

	# 触控手势也有空间冲突
	if p_event is InputEventPanGesture or p_event is InputEventMagnifyGesture:
		if _is_mouse_over_blocking_ui(_mouse_pos):
			return

	# 键盘事件无空间冲突，直接处理
	_resolver.process_event(p_event)


func _process(p_delta: float) -> void:
	if _resolver != null:
		_resolver.end_frame(p_delta)


## 检查给定屏幕坐标是否在 mouse_filter=STOP 的 Control 上。
func _is_mouse_over_blocking_ui(p_screen_pos: Vector2) -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	return _scan_controls(vp, p_screen_pos)


func _scan_controls(p_node: Node, p_pos: Vector2) -> bool:
	for child in p_node.get_children():
		if child is Control:
			var ctrl := child as Control
			if not ctrl.visible:
				continue
			if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				# IGNORE 不消费事件，但递归检查子节点
				if _scan_controls(ctrl, p_pos):
					return true
				continue
			# PASS 或 STOP：命中时阻断
			if ctrl.get_global_rect().has_point(p_pos):
				return true
			# 递归子节点
			if _scan_controls(ctrl, p_pos):
				return true
		else:
			# 非 Control 节点（如 CanvasLayer、Node2D）
			if _scan_controls(child, p_pos):
				return true
	return false
