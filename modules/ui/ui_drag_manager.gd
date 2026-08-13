## GF_UIDragManager
## 拖拽事件驱动 Node。由 GF_UIService 创建，通过 GF_ServiceInstallerImpl 挂到场景树。
## 使用 _input（GUI 之前触发）确保 drop 事件不会被 Control 消费而丢失。
##
## 职责：
## - 状态机：空闲 → 拖拽中 → 放置/取消 → 空闲
## - 每帧通知 GF_UIDragHandler.on_drag
## - 松手时通过 GF_UIService 做 hit_test 路由到 GF_UIDropTarget
## - ESC / 窗口失焦兜底取消
class_name GF_UIDragManager
extends Node

## 指向 GF_UIService 的弱引用，避免循环引用
var _service_ref: WeakRef = null

## 当前活跃的拖拽回调处理器
var _handler: GF_UIDragHandler = null

## 当前拖拽事件数据
var _event: GF_UIDragEvent = null

## 当前拖拽的 L2 视觉（游戏层通过 event.show_ghost_xxx 设置）
var _ghost: GF_UIDragGhost = null

## 当前拖拽源面板名称（面板关闭时检查是否清理引用）
var _source_panel_name: String = ""


func configure(p_service: GF_UIService) -> void:
	_service_ref = weakref(p_service)


## 由 GF_UIService.begin_drag 调用。p_handler 为游戏层实现的 GF_UIDragHandler 子类。
func begin(p_handler: GF_UIDragHandler, p_screen_pos: Vector2, p_button: int, p_source: GF_UIPanel) -> void:
	_handler = p_handler
	_event = GF_UIDragEvent.new()
	_event.position = p_screen_pos
	_event.delta = Vector2.ZERO
	_event.button = p_button
	_event.drag_source = p_source
	# 设置 ghost 附着回调，让 game 层创建的 GF_UIDragGhost 能挂到 SYSTEM 层
	_event._attach_ghost_cb = _on_ghost_attached
	_handler.on_begin_drag(_event)


## 所有原始输入事件（GUI 之前触发）。
## 与 GF_InputRouter._input 共存，两者都观察事件但不互相消费。
func _input(p_event: InputEvent) -> void:
	if _event == null:
		return

	if p_event is InputEventMouseMotion:
		var me := p_event as InputEventMouseMotion
		_event.delta = me.relative
		# 统一坐标系：InputEvent 的 global_position 是 viewport 坐标，
		# UI/ghost/hit-test 使用 canvas 坐标，拉伸窗口下两者不一致
		_event.position = _to_canvas(me.global_position)

		# 1. 通知游戏层
		if is_instance_valid(_handler):
			_handler.on_drag(_event)

		# 2. 更新 L2 视觉
		if _ghost != null and is_instance_valid(_ghost):
			_ghost._follow(_event.position)

		# 3. 命中检测 + hover/leave 通知
		var svc := _get_service()
		if svc != null:
			svc._on_drag_motion(_event.position)

	elif p_event is InputEventMouseButton:
		var mb := p_event as InputEventMouseButton
		if not mb.pressed and mb.button_index == _event.button:
			var svc := _get_service()
			if svc != null:
				svc._on_drag_drop(_to_canvas(mb.global_position))

	elif p_event is InputEventKey:
		var ke := p_event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			var svc := _get_service()
			if svc != null:
				svc.cancel_drag()


## 窗口失焦 → 取消拖拽（防止拖拽卡死）
func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		var svc := _get_service()
		if svc != null:
			svc.cancel_drag()


func _get_service() -> GF_UIService:
	if _service_ref == null:
		return null
	return _service_ref.get_ref() as GF_UIService


## viewport 坐标 → canvas 坐标。窗口拉伸（content_scale_mode）时两者不一致，
## UI 面板、ghost、hit-test 全部使用 canvas 坐标，输入事件统一换算。
func _to_canvas(p_viewport_pos: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return p_viewport_pos
	return vp.make_canvas_position_local(p_viewport_pos)


## event.show_ghost_xxx 的回调：将 ghost 挂到 SYSTEM 层
func _on_ghost_attached(p_ghost: GF_UIDragGhost) -> void:
	_ghost = p_ghost
	var svc := _get_service()
	if svc != null:
		var system_layer := svc.get_ui_layer(GF_UIPanelDef.KIND_SYSTEM)
		if system_layer != null:
			system_layer.add_child(p_ghost)


## 返回当前拖拽事件，空闲时返回 null。
func get_current_event() -> GF_UIDragEvent:
	return _event


## 返回当前拖拽处理器，空闲时返回 null。
func get_current_handler() -> GF_UIDragHandler:
	return _handler


## 判断是否正在拖拽中。
func is_dragging() -> bool:
	return _event != null


## 清理拖拽状态。由 GF_UIService 在拖拽结束时调用。
func clear_drag_state() -> void:
	if _ghost != null:
		if is_instance_valid(_ghost):
			_ghost.dismiss()
		_ghost = null
	_handler = null
	_event = null
	_source_panel_name = ""
