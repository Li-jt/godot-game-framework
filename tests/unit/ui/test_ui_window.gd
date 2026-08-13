# tests/unit/ui/test_ui_window.gd
## GF_UIWindow 单元测试。
## 覆盖：拖动与钳制、move_finished 信号、焦点信号双通道、手柄发现、mouse_filter 强制。
extends GutTest

var _window: GF_UIWindow
var _drag_area: Control
var _layer: Control


func before_each() -> void:
	_layer = add_child_autoqfree(Control.new())
	_layer.size = Vector2(1280, 720)
	_window = GF_UIWindow.new()
	_window.size = Vector2(400, 300)
	_window.position = Vector2(100, 100)
	_drag_area = Control.new()
	_drag_area.size = Vector2(400, 32)
	_drag_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_window.add_child(_drag_area)
	_window.drag_area = _drag_area
	# 最后挂窗口 → _ready 时 drag_area 已就位，connect 生效
	_layer.add_child(_window)


func after_each() -> void:
	_window.queue_free()
	_window = null


# ============================================================
# 拖动
# ============================================================

func _press(p_pos: Vector2 = Vector2(10, 5)) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = p_pos
	_window._on_drag_area_input(ev)


func _motion(p_pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p_pos
	_window._on_drag_area_input(ev)


func _release(p_pos: Vector2 = Vector2(60, 25)) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = p_pos
	_window._on_drag_area_input(ev)


func test_drag_moves_window_by_relative_delta() -> void:
	_press()
	_motion(Vector2(60, 25))
	assert_eq(_window.position, Vector2(150, 120), "拖动应按相对增量移动窗口")


func test_drag_release_emits_move_finished() -> void:
	var emitted: Array = []
	_window.move_finished.connect(func(p): emitted.append(p))
	_press()
	_motion(Vector2(60, 25))
	_release()
	assert_eq(emitted.size(), 1, "松手应发射一次 move_finished")
	assert_eq(emitted[0], _window.position)


func test_drag_clamped_to_parent_bounds() -> void:
	# 左边界：窗口最右边缘至少 EDGE_KEEP 留在父层内
	_press()
	_motion(Vector2(-2000, 5))
	assert_eq(_window.position, Vector2(-400.0 + GF_UIWindow.EDGE_KEEP, 100.0), "左边界应钳制")

	# 上边界：窗口顶边不低于父层顶边
	_press()
	_motion(Vector2(10, -10000))
	assert_eq(_window.position.y, 0.0, "上边界应钳制")


func test_no_drag_area_no_moving_flag() -> void:
	# 未设置 drag_area 的窗口不应进入拖动状态（connect 未发生，直接调用也不应移动）
	var bare := GF_UIWindow.new()
	bare.size = Vector2(400, 300)
	bare.position = Vector2(10, 10)
	_layer.add_child(bare)
	var start := bare.position
	_press()
	_motion(Vector2(60, 25))
	assert_eq(bare.position, start, "无 drag_area 时拖动不应影响窗口")
	bare.queue_free()


# ============================================================
# 焦点信号
# ============================================================

func test_focus_inside_emits_focused() -> void:
	var inner := Control.new()
	inner.focus_mode = Control.FOCUS_ALL
	_window.add_child(inner)
	var got: Array = []
	_window.focused.connect(func(): got.append(true))
	_window._on_viewport_focus_changed(inner)
	assert_eq(got.size(), 1, "焦点进入窗口子树应发射 focused")


func test_focus_outside_emits_unfocused() -> void:
	_window._set_focused(true)
	var got: Array = []
	_window.unfocused.connect(func(): got.append(true))
	var outsider := Control.new()
	_layer.add_child(outsider)
	_window._on_viewport_focus_changed(outsider)
	assert_eq(got.size(), 1, "焦点移出窗口应发射 unfocused")


func test_set_focused_idempotent() -> void:
	var got: Array = []
	_window.focused.connect(func(): got.append(true))
	_window._set_focused(true)
	_window._set_focused(true)
	assert_eq(got.size(), 1, "重复置位不应重复发射")


# ============================================================
# 其他
# ============================================================

func test_ready_forces_pass_mouse_filter() -> void:
	assert_eq(_window.mouse_filter, Control.MOUSE_FILTER_PASS, "窗口根应强制 PASS")


func test_discovers_resize_handles() -> void:
	var handle := GF_ResizeHandle.new()
	_window.add_child(handle)
	_window._discover_resize_handles()
	assert_eq(_window._resize_handles.size(), 1, "应递归发现子树中的手柄")


func test_request_focus_without_bootstrap_is_safe() -> void:
	var got: Array = []
	_window.focused.connect(func(): got.append(true))
	_window.request_focus()
	assert_eq(got.size(), 1, "request_focus 应发射 focused")
	# 无 bootstrap 时静默降级，不崩溃


func test_gui_input_left_press_requests_focus() -> void:
	var got: Array = []
	_window.focused.connect(func(): got.append(true))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	_window._gui_input(ev)
	assert_eq(got.size(), 1, "窗口根左键点击应触发置顶（通道 2）")
