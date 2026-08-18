## GF_UIDragSlot
## 可拖拽格子 Control。既是拖拽源也是放置目标，拖到场景里配置一下就能用。
##
## 内置行为（框架自动处理，游戏层不需要写代码）：
## - 鼠标按下后移动超过 drag_start_threshold → 自动调 GF_UIService.begin_drag
##   （drag_enabled=true 且有数据时）
## - 有物品拖过 → 自动高亮（drop_enabled=true 且 _accepts 通过时）
## - 物品放入 → 发射 slot_drop_received 信号
##
## 鼠标事件回调（子类按需重写，无需自己判断输入类型）：
##   [codeblock]
##   class_name MySlot
##   extends GF_UIDragSlot
##
##   func _on_slot_clicked(p_button: int) -> void:
##       match p_button:
##           MOUSE_BUTTON_LEFT:  _select_item()
##           MOUSE_BUTTON_RIGHT: _open_context_menu()
##
##   func _on_slot_double_clicked(p_button: int) -> void:
##       _use_item()
##
##   func _on_slot_drag_ended(p_accepted: bool) -> void:
##       if p_accepted:
##           _log_success()
##   [/codeblock]
## 只实现需要的事件，其余不用管。
##
## 使用方式：
##   1. 在场景中放置 GF_UIDragSlot 作为子节点
##   2. 编辑器中勾选 drag_enabled / drop_enabled
##   3. 连接 slot_drop_received 信号处理拖放业务逻辑
##   4. 需要点击/双击/右键等交互时，继承此类并重写对应回调
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

## 拖动判定阈值（像素）。按下后移动超过此距离才判定为拖动，
## 否则松开时判定为单击。设为 0 表示按下即拖拽（旧版行为）。
@export var drag_start_threshold: float = 8.0

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

# ════════════════════════════════════════════
# 鼠标事件跟踪状态
# ════════════════════════════════════════════

## 当前按下的鼠标按键（-1 = 无）
var _press_button: int = -1

## 按下时的全局（viewport）坐标，用于拖动阈值判定
var _press_global_pos: Vector2 = Vector2.ZERO

## 是否已移动超过拖动阈值（判定为滑动/拖动，不再算单击）
var _moved_past_threshold: bool = false

## 本格子是否已触发拖拽（拖拽期间忽略新的按下）
var _drag_triggered: bool = false

## 双击第二击的松开不再算一次单击
var _suppress_next_click: bool = false


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
	# 绑定方法为动态 rect 提供者：hit-test 时实时取全局坐标，布局变化无需手动刷新
	_registered_target.rect_provider = _get_global_rect_for_target
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


## 返回 slot 的全局命中矩形（canvas 坐标）。
## 注册为 GF_UIDropTarget.rect_provider，hit-test 时实时调用。
func _get_global_rect_for_target() -> Rect2:
	return Rect2(get_global_position(), size)


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
# 鼠标事件回调（子类按需重写，框架自动判定事件类型）
# ════════════════════════════════════════════

## 任意鼠标按键在此格子上按下。
## [param p_button] MOUSE_BUTTON_* 常量
func _on_slot_pressed(p_button: int) -> void:
	pass


## 任意鼠标按键松开（与按下的是同一按键）。
## [param p_button] MOUSE_BUTTON_* 常量
func _on_slot_released(p_button: int) -> void:
	pass


## 单击：按下 → 松开，且移动未超过 drag_start_threshold（未触发拖动）。
## [br]双击时第一击也会触发本回调（标准行为），第二击触发 _on_slot_double_clicked。
## [param p_button] MOUSE_BUTTON_* 常量（左键/右键/中键通用）
func _on_slot_clicked(p_button: int) -> void:
	pass


## 双击：Godot 引擎按 OS 双击时间窗口检测（InputEventMouseButton.double_click）。
## [param p_button] MOUSE_BUTTON_* 常量
func _on_slot_double_clicked(p_button: int) -> void:
	pass


## 拖动开始：按下后移动超过 drag_start_threshold 像素触发。
## 仅 drag_enabled=true 且格子有数据时触发（否则仅视为滑动，不触发单击）。
func _on_slot_drag_started() -> void:
	pass


## 拖动结束（无论成功与否）。
## [param p_accepted] true=有放置目标接受，false=拖拽取消/未放置
func _on_slot_drag_ended(p_accepted: bool) -> void:
	pass


# ════════════════════════════════════════════
# 内部：鼠标事件判定（单击/双击/右键/拖动）
# ════════════════════════════════════════════

func _on_gui_input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseButton:
		var mb := p_event as InputEventMouseButton
		if mb.pressed:
			_handle_button_press(mb)
		# 松开统一在 _input 处理（全局可见，不依赖鼠标悬停在格子上）


## 全局输入观察（与 GF_UIDragManager 同模式）：
## - 按下后跟踪鼠标移动：gui_input 只在鼠标悬停时送达 motion，
##   鼠标移出格子后仍要能判定拖动阈值，故用 _input 全局跟踪；
## - 统一处理松开：松开事件可能被其它 Control 消费，_input 在 GUI 之前必达。
func _input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseMotion:
		if _press_button != -1 and not _drag_triggered:
			_check_drag_threshold(p_event as InputEventMouseMotion)
	elif p_event is InputEventMouseButton:
		var mb := p_event as InputEventMouseButton
		if not mb.pressed and mb.button_index == _press_button:
			_finish_button_release(mb)


func _handle_button_press(p_mb: InputEventMouseButton) -> void:
	# 已有按键按下或本格子正在拖拽时，忽略新的按下（如双击第二击落在拖拽期间）
	if _press_button != -1 or _drag_triggered:
		return
	_press_button = p_mb.button_index
	_press_global_pos = p_mb.global_position
	_moved_past_threshold = false
	_suppress_next_click = false
	_on_slot_pressed(p_mb.button_index)
	if p_mb.double_click:
		_on_slot_double_clicked(p_mb.button_index)
		# 双击第二击的松开不再算一次单击
		_suppress_next_click = true


func _check_drag_threshold(p_me: InputEventMouseMotion) -> void:
	if _press_global_pos.distance_to(p_me.global_position) < drag_start_threshold:
		return
	_moved_past_threshold = true
	# 仅左键 + 可拖拽 + 有数据才真正开始拖拽
	if _press_button != MOUSE_BUTTON_LEFT or not drag_enabled or _slot_data.is_empty():
		# 无拖拽可能：本次按压判定为滑动而非点击。
		# 立即复位——松开可能发生在格子外，不能依赖松开事件复位
		_press_button = -1
		return
	_drag_triggered = true
	_on_slot_drag_started()
	var result := _begin_slot_drag()
	if result.is_fail():
		_reset_press_state()


func _finish_button_release(p_mb: InputEventMouseButton) -> void:
	var pressed_button := _press_button
	_press_button = -1
	_moved_past_threshold = false
	if _drag_triggered:
		# 拖拽中的松手由 GF_UIDragManager 路由放置（on_end_drag 会复位其余状态）
		_drag_triggered = false
		return
	_on_slot_released(pressed_button)
	if _suppress_next_click:
		_suppress_next_click = false
		return
	_on_slot_clicked(pressed_button)


## 复位按压/拖拽跟踪状态。拖拽结束、begin_drag 失败、窗口失焦时调用，防止状态卡死。
func _reset_press_state() -> void:
	_press_button = -1
	_moved_past_threshold = false
	_drag_triggered = false
	_suppress_next_click = false


## 窗口失焦时复位（用户按住鼠标后切走窗口，松开事件可能丢失导致状态卡死）。
func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_reset_press_state()


# ════════════════════════════════════════════
# 内部：拖拽源
# ════════════════════════════════════════════

func _begin_slot_drag() -> GF_OperationResult:
	var panel := _get_parent_panel()
	var ui := _find_ui_service()
	if panel == null or ui == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_PRECONDITION,
			"UI 服务不可用（面板尚未注入 _bootstrap）", "GF_UIDragSlot")

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
	return ui.begin_drag(handler, get_global_mouse_position(), panel)


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
		# 复位按压跟踪（拖拽中的松手可能不落在本格子，_input 收不到）
		_slot._reset_press_state()
		if event.drop_receiver == null:
			_slot.slot_drag_cancelled.emit(_slot)
		_slot.slot_drag_end.emit(_slot, event.drop_receiver != null)
		_slot._on_slot_drag_ended(event.drop_receiver != null)
