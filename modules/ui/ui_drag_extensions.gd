## GF_UIDragExtensions
## 对任意 Control 快速添加拖拽能力的静态方法集合。
## 游戏层无需继承 GF_UIDragSlot 即可让任意 UI 元素参与拖拽。
class_name GF_UIDragExtensions
extends RefCounted


## 让一个 Control 可从中拖出物品。
## [param p_control] 目标 Control
## [param p_config] Dictionary，支持字段：
##   - "data": Dictionary — 拖拽携带的数据（必填）
##   - "icon": Texture2D — 拖拽时显示的图标（可选）
##   - "offset": Vector2 — 图标相对于鼠标的偏移，默认 (-24, -24)
##   - "condition": Callable — func() -> bool，是否允许拖出，默认始终允许
##   - "on_begin": Callable — func() -> void，拖出时回调
##   - "on_end": Callable — func(accepted: bool) -> void，拖拽结束回调
##   - "on_cancel": Callable — func() -> void，拖拽取消回调
static func setup_drag_source(p_control: Control, p_config: Dictionary) -> void:
	var data: Dictionary = p_config.get("data", {})
	var icon: Texture2D = p_config.get("icon")
	var offset: Vector2 = p_config.get("offset", Vector2(-24, -24))
	var condition: Callable = p_config.get("condition", func() -> bool: return true)
	var on_begin: Callable = p_config.get("on_begin", Callable())
	var on_end: Callable = p_config.get("on_end", Callable())
	var on_cancel: Callable = p_config.get("on_cancel", Callable())

	p_control.gui_input.connect(func(p_event: InputEvent) -> void:
		if not (p_event is InputEventMouseButton):
			return
		var mb := p_event as InputEventMouseButton
		if not mb.pressed:
			return
		if not condition.call():
			return

		var handler := _QuickDragHandler.new()
		handler._data = data
		handler._icon = icon
		handler._offset = offset
		handler._on_begin = on_begin
		handler._on_end = on_end
		handler._on_cancel = on_cancel

		var ui := _find_ui_service(p_control)
		if ui != null:
			ui.begin_drag(handler, p_control.get_global_mouse_position(), _find_panel(p_control))

	, CONNECT_ONE_SHOT if p_config.get("one_shot", false) else 0)


## 让一个 Control 成为放置目标。
## [param p_control] 目标 Control
## [param p_config] Dictionary，支持字段：
##   - "accept": Callable — func(data: Dictionary) -> bool，是否接受拖拽数据
##   - "on_drop": Callable — func(data: Dictionary) -> bool，放入时回调
##   - "on_hover": Callable — func(data: Dictionary) -> void，悬停回调
##   - "on_leave": Callable — func() -> void，离开回调
##   - "rect_override": Rect2 — 覆盖命中区域（默认使用 p_control.get_rect()）
static func setup_drop_target(p_control: Control, p_config: Dictionary) -> void:
	var panel := _find_panel(p_control)
	if panel == null:
		return

	var target := GF_UIDropTarget.new()
	target.panel = panel
	target.rect = p_config.get("rect_override", p_control.get_rect())
	target.accept_filter = p_config.get("accept", func(_d: Dictionary) -> bool: return true)
	target.on_hover = p_config.get("on_hover", Callable())
	target.on_leave = p_config.get("on_leave", Callable())
	target.on_drop = p_config.get("on_drop", Callable())

	var ui := _find_ui_service(p_control)
	if ui != null:
		ui.register_drop_target(target)


## 向上查找所属 GF_UIPanel
static func _find_panel(p_control: Control) -> GF_UIPanel:
	var p: Node = p_control
	while p != null:
		if p is GF_UIPanel:
			return p as GF_UIPanel
		p = p.get_parent()
	return null


## 通过面板上下文查找 GF_UIService
static func _find_ui_service(p_control: Control) -> GF_UIService:
	var panel := _find_panel(p_control)
	if panel != null and panel.ctx != null:
		return panel.ctx.ui
	return null


# ═══════════════════════════════════════════════════
# 内部：轻量级 DragHandler
# ═══════════════════════════════════════════════════

class _QuickDragHandler extends GF_UIDragHandler:

	var _data: Dictionary = {}
	var _icon: Texture2D = null
	var _offset: Vector2 = Vector2.ZERO
	var _ghost: GF_UIDragGhost = null
	var _on_begin: Callable
	var _on_end: Callable
	var _on_cancel: Callable


	func on_begin_drag(event: GF_UIDragEvent) -> void:
		event.drag_data = _data
		if _icon != null:
			_ghost = event.show_ghost_texture(_icon, _offset)
		if _on_begin.is_valid():
			_on_begin.call()


	func on_end_drag(event: GF_UIDragEvent) -> void:
		if event.drop_receiver == null:
			if _on_cancel.is_valid():
				_on_cancel.call()
		if _on_end.is_valid():
			_on_end.call(event.drop_receiver != null)
