## GF_UIDragSlot
## 可拖拽格子 Control。既是拖拽源也是放置目标，拖到场景里配置一下就能用。
##
## 内置行为（框架自动处理，游戏层不需要写代码）：
## - 鼠标按下 → 自动调 GF_UIService.begin_drag（drag_enabled=true 且有数据时）
## - 有物品拖过 → 自动高亮（drop_enabled=true 且 _accepts 通过时）
## - 物品放入 → 发射 slot_drop_received 信号
##
## 使用方式：
##   1. 在场景中放置 GF_UIDragSlot 作为子节点
##   2. 编辑器中勾选 drag_enabled / drop_enabled
##   3. 连接 slot_drop_received 信号处理业务逻辑
class_name GF_UIDragSlot
extends Control

# ════════════════════════════════════════════
# 配置（编辑器可调）
# ════════════════════════════════════════════

## 此格子是否可从中拖出物品
@export var drag_enabled: bool = true

## 此格子是否可放入物品
@export var drop_enabled: bool = true

## 接受的物品标签（空 = 全部接受）
@export var accept_tags: Array[String] = []

## 拒绝的物品标签
@export var reject_tags: Array[String] = []

## 放入物品时是否交换（true=交换, false=移动，源格子变空）
@export var swap_on_drop: bool = true

## 自定义拖拽图标（为空则用格子的 Icon 子节点纹理）
@export var drag_ghost_texture: Texture2D

## 拖拽图标相对于鼠标的偏移
@export var drag_ghost_offset: Vector2 = Vector2(-24, -24)

# ════════════════════════════════════════════
# 信号
# ════════════════════════════════════════════

## 物品从此格子拖出
signal slot_drag_begin(slot: GF_UIDragSlot)

## 物品放入此格子
signal slot_drop_received(from_slot: GF_UIDragSlot, to_slot: GF_UIDragSlot)

## 拖拽取消（物品弹回）
signal slot_drag_cancelled(slot: GF_UIDragSlot)

## 拖拽结束（无论成功与否）
signal slot_drag_end(slot: GF_UIDragSlot, accepted: bool)

# ════════════════════════════════════════════
# 内部引用
# ════════════════════════════════════════════

var _slot_data: Dictionary = {}
var _highlight: ColorRect = null
var _button: Button = null
var _is_highlighted: bool = false
var _registered_target: GF_UIDropTarget = null
var _drop_target_registered: bool = false


func _ready() -> void:
	_ensure_internal_nodes()
	_button.gui_input.connect(_on_gui_input)
	# 延迟注册 drop target，等父面板的 ctx 注入完成
	_try_register_drop_target.call_deferred()


func _ensure_internal_nodes() -> void:
	if not has_node("Button"):
		_button = Button.new()
		_button.name = "Button"
		_button.flat = true
		_button.set_anchors_preset(Control.PRESET_FULL_RECT)
		_button.focus_mode = Control.FOCUS_NONE
		add_child(_button)
	else:
		_button = $Button as Button

	if not has_node("Highlight"):
		_highlight = ColorRect.new()
		_highlight.name = "Highlight"
		_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
		_highlight.color = Color(1.0, 1.0, 1.0, 0.2)
		_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_highlight.hide()
		add_child(_highlight)
	else:
		_highlight = $Highlight as ColorRect


## 尝试注册 drop target。如果 _bootstrap 还没注入（面板 open() 尚未完成），延迟重试。
func _try_register_drop_target() -> void:
	if _drop_target_registered:
		return
	if not drop_enabled:
		return

	var panel := _get_parent_panel()
	var ui := _find_ui_service()
	if panel == null or ui == null:
		# _bootstrap 还没注入，再延迟一次
		_try_register_drop_target.call_deferred()
		return

	_registered_target = GF_UIDropTarget.new()
	_registered_target.panel = panel
	_registered_target.rect = get_rect()
	_registered_target.accept_filter = func(data: Dictionary) -> bool:
		return _accepts(data)
	_registered_target.on_hover = func(_data: Dictionary) -> void:
		_show_highlight()
	_registered_target.on_leave = func() -> void:
		_hide_highlight()
	_registered_target.on_drop = func(data: Dictionary) -> bool:
		return _handle_drop(data)

	ui.register_drop_target(_registered_target)
	_drop_target_registered = true


## 手动刷新注册（当格子的 rect 发生变化时调用）
func refresh_drop_target() -> void:
	if _registered_target != null:
		_registered_target.rect = get_rect()
	else:
		_try_register_drop_target()


# ════════════════════════════════════════════
# 公共方法
# ════════════════════════════════════════════

## 设置格子数据（游戏层调用）
func set_slot_data(p_data: Dictionary) -> void:
	_slot_data = p_data


## 获取格子数据
func get_slot_data() -> Dictionary:
	return _slot_data


## 检查格子是否为空
func is_empty() -> bool:
	return _slot_data.is_empty()


# ════════════════════════════════════════════
# 内部：拖拽源
# ════════════════════════════════════════════

func _on_gui_input(p_event: InputEvent) -> void:
	if not (p_event is InputEventMouseButton):
		return
	var mb := p_event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.double_click:
		return

	if drag_enabled and not _slot_data.is_empty():
		_begin_slot_drag()


func _begin_slot_drag() -> void:
	var panel := _get_parent_panel()
	var ui := _find_ui_service()
	if panel == null or ui == null:
		return

	var icon := drag_ghost_texture
	if icon == null:
		var icon_node := get_node_or_null("Icon") as TextureRect
		if icon_node != null:
			icon = icon_node.texture

	var handler := _SlotDragHandler.new()
	handler._slot = self
	handler._data = _slot_data.duplicate()
	handler._icon = icon
	handler._offset = drag_ghost_offset

	slot_drag_begin.emit(self)
	ui.begin_drag(handler, get_global_mouse_position(), panel)


# ════════════════════════════════════════════
# 内部：放置目标
# ════════════════════════════════════════════

func _accepts(p_data: Dictionary) -> bool:
	if not drop_enabled:
		return false

	var tags: Array = p_data.get("_tags", [])
	if not accept_tags.is_empty():
		for tag in accept_tags:
			if tag in tags:
				return true
		return false
	if not reject_tags.is_empty():
		for tag in reject_tags:
			if tag in tags:
				return false
	return true


func _handle_drop(p_data: Dictionary) -> bool:
	var source_slot: GF_UIDragSlot = p_data.get("_source_slot")
	if source_slot == null:
		return false
	if source_slot == self:
		return false

	slot_drop_received.emit(source_slot, self)
	return true


func _show_highlight() -> void:
	if _is_highlighted:
		return
	_is_highlighted = true
	if _highlight != null:
		_highlight.show()


func _hide_highlight() -> void:
	if not _is_highlighted:
		return
	_is_highlighted = false
	if _highlight != null:
		_highlight.hide()


func _get_parent_panel() -> GF_UIPanel:
	var p: Node = get_parent()
	while p != null:
		if p is GF_UIPanel:
			return p as GF_UIPanel
		p = p.get_parent()
	return null


## 通过父面板的 _bootstrap 查找 GF_UIService。
## _bootstrap 由 UIService.open() 在 add_child 之后注入，
## 因此 _ready() 时可能为 null，此时返回 null 由调用方延迟重试。
func _find_ui_service() -> GF_UIService:
	var panel := _get_parent_panel()
	if panel != null and panel._bootstrap != null:
		return panel._bootstrap.service(GF_UIService) as GF_UIService
	return null


# ════════════════════════════════════════════
# 内部 handler
# ════════════════════════════════════════════

class _SlotDragHandler extends GF_UIDragHandler:

	var _slot: GF_UIDragSlot = null
	var _data: Dictionary = {}
	var _icon: Texture2D = null
	var _offset: Vector2 = Vector2.ZERO
	var _ghost: GF_UIDragGhost = null


	func on_begin_drag(event: GF_UIDragEvent) -> void:
		event.drag_data = _data.duplicate()
		event.drag_data["_source_slot"] = _slot
		if _icon != null:
			_ghost = event.show_ghost_texture(_icon, _offset)


	func on_end_drag(event: GF_UIDragEvent) -> void:
		if event.drop_receiver == null:
			_slot.slot_drag_cancelled.emit(_slot)
		_slot.slot_drag_end.emit(_slot, event.drop_receiver != null)
