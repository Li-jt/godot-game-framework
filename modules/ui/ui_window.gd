## GF_UIWindow
## Win11 风格窗口根脚本。挂到 Game 层窗口场景的根节点（见 scenes/ui/window_shell.tscn）。
## 只含交互逻辑，不含视觉节点——窗口结构由 Game 层在编辑器搭建。
##
## 能力由场景结构表达：
## - 拖入 [member drag_area]（通常是标题栏）→ 可拖动；保持 null → 不可拖动
## - 子树中存在挂 GF_ResizeHandle 脚本的节点 → 可缩放
##
## 点击置顶走双通道（Win11 语义：点窗口任意处都置顶）：
## - 通道 1：viewport.gui_focus_changed —— 点击可聚焦控件触发
## - 通道 2：窗口根 _gui_input —— 点击空白区/不可聚焦控件经 PASS 冒泡触发
## 两者互补无遗漏，统一走 request_focus() → GF_UIService.focus_window()。
class_name GF_UIWindow
extends GF_UIPanel

## 拖动结束（松手）时发射。
signal move_finished(new_position: Vector2)
## 缩放结束（松手）时发射。
signal resize_finished(new_size: Vector2)
## 窗口获得视觉焦点（置顶/点击）时发射。Game 层订阅后切换标题栏样式。
signal focused
## 窗口失去视觉焦点时发射。
signal unfocused

## 编辑器拖入：窗口拖动手柄区域（通常是标题栏）。null = 窗口不可拖动。
## 建议保持默认 MOUSE_FILTER_STOP，避免标题栏点击穿透到游戏。
@export var drag_area: Control = null

## 窗口拖出屏幕时，标题栏保留在父层可视区内的最小可见量（像素）。
const EDGE_KEEP := 32.0
## _panel_def 未注入时的最小尺寸兜底（编辑器直接运行场景时）。
const MIN_FALLBACK_SIZE := Vector2(320, 240)

var _is_moving := false
var _drag_grab_offset := Vector2.ZERO
var _is_focused := false
## GF_ResizeHandle 实例。find_children 按 class_name 字符串发现，避免类型循环引用。
var _resize_handles: Array = []
## 焦点跟踪的 viewport 引用（_exit_tree 时 get_viewport() 可能已失效）。
var _viewport: Viewport = null


func _ready() -> void:
	# 窗口根 PASS：让空白区/不可聚焦控件的点击冒泡进 _gui_input（置顶通道 2）
	mouse_filter = Control.MOUSE_FILTER_PASS
	_viewport = get_viewport()
	_discover_resize_handles()
	if drag_area != null:
		drag_area.gui_input.connect(_on_drag_area_input)
	_connect_focus_tracking()


func _exit_tree() -> void:
	if drag_area != null and drag_area.gui_input.is_connected(_on_drag_area_input):
		drag_area.gui_input.disconnect(_on_drag_area_input)
	if _viewport != null and _viewport.gui_focus_changed.is_connected(_on_viewport_focus_changed):
		_viewport.gui_focus_changed.disconnect(_on_viewport_focus_changed)


func _gui_input(event: InputEvent) -> void:
	# 置顶通道 2：冒泡到窗口根的左键点击
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			request_focus()


# ============================================================
# 公共 API（GF_ResizeHandle / GF_UIService 消费）
# ============================================================

## 请求窗口置顶（z-order）+ 视觉焦点。由拖动、缩放、点击等交互触发。
func request_focus() -> void:
	_set_focused(true)
	if _bootstrap != null:
		var ui: GF_UIService = _bootstrap.service(GF_UIService) as GF_UIService
		if ui != null:
			ui.focus_window(panel_name)


## 由 GF_ResizeHandle 在缩放结束时调用。
func notify_resize_finished() -> void:
	resize_finished.emit(size)


## 缩放下限。优先读面板定义的 window_min_size，未注入时用兜底常量。
func get_window_min_size() -> Vector2:
	if _panel_def != null:
		return _panel_def.window_min_size
	return MIN_FALLBACK_SIZE


# ============================================================
# 拖动（drag_area 的 gui_input，全本地坐标）
# ============================================================

func _on_drag_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_is_moving = true
			_drag_grab_offset = mb.position   # drag_area 本地坐标
			request_focus()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _is_moving:
				_is_moving = false
				move_finished.emit(position)
	elif event is InputEventMouseMotion and _is_moving:
		var mm := event as InputEventMouseMotion
		# 相对增量，无累计误差；drag_area 随窗口移动，本地坐标不受影响
		position += mm.position - _drag_grab_offset
		_clamp_position()


func _clamp_position() -> void:
	var parent_ctl := get_parent_control()
	if parent_ctl == null:
		return
	var area := parent_ctl.size
	var new_pos := position
	# 标题栏始终保留在父层可视区内，防拖丢
	new_pos.x = clampf(new_pos.x, -size.x + EDGE_KEEP, area.x - EDGE_KEEP)
	new_pos.y = clampf(new_pos.y, 0.0, area.y - EDGE_KEEP)
	position = new_pos


# ============================================================
# 焦点跟踪（置顶通道 1 + focused/unfocused 信号）
# ============================================================

func _connect_focus_tracking() -> void:
	if _viewport != null and not _viewport.gui_focus_changed.is_connected(_on_viewport_focus_changed):
		_viewport.gui_focus_changed.connect(_on_viewport_focus_changed)


func _on_viewport_focus_changed(p_control: Control) -> void:
	var node: Node = p_control
	var inside := false
	while node != null:
		if node == self:
			inside = true
			break
		node = node.get_parent()
	_set_focused(inside)
	if inside:
		request_focus()


func _set_focused(p_focused: bool) -> void:
	if _is_focused == p_focused:
		return
	_is_focused = p_focused
	if p_focused:
		focused.emit()
	else:
		unfocused.emit()


# ============================================================
# 缩放手柄发现
# ============================================================

func _discover_resize_handles() -> void:
	_resize_handles = find_children("*", "GF_ResizeHandle", true, false)
