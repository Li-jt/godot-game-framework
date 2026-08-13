# tests/unit/ui/test_ui_resize_handle.gd
## GF_ResizeHandle 单元测试。
## 覆盖：各方向缩放、N/W 方向 position 同步、min_size clamp、resize_finished 信号、光标形状。
extends GutTest

var _window: GF_UIWindow
var _handle: GF_ResizeHandle
var _layer: Control


func before_each() -> void:
	_layer = add_child_autoqfree(Control.new())
	_layer.size = Vector2(1280, 720)
	_window = GF_UIWindow.new()
	_window.size = Vector2(400, 300)
	_window.position = Vector2(100, 100)
	_handle = GF_ResizeHandle.new()
	_handle.edge = GF_ResizeHandle.Edge.RIGHT
	_handle.size = Vector2(8, 300)
	_handle.position = Vector2(392, 0)
	_window.add_child(_handle)
	_layer.add_child(_window)


func after_each() -> void:
	_window.queue_free()
	_window = null


func _press(p_pos: Vector2 = Vector2(4, 4)) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = p_pos
	_handle._gui_input(ev)


func _motion(p_pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p_pos
	_handle._gui_input(ev)


func _release() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	_handle._gui_input(ev)


# ============================================================
# 各方向缩放
# ============================================================

func test_right_edge_resizes_width() -> void:
	_press()
	_motion(Vector2(104, 4))
	assert_eq(_window.size, Vector2(500, 300), "RIGHT 拖动 +100 应加宽")
	assert_eq(_window.position, Vector2(100, 100), "RIGHT 不改变位置")


func test_left_edge_resizes_and_moves() -> void:
	_handle.edge = GF_ResizeHandle.Edge.LEFT
	_handle.position = Vector2(0, 0)
	_press()
	_motion(Vector2(54, 4))
	assert_eq(_window.size, Vector2(350, 300), "LEFT 拖动 +50 应收窄")
	assert_eq(_window.position, Vector2(150, 100), "LEFT 收缩应同步右移 position")


func test_top_edge_resizes_and_moves() -> void:
	_handle.edge = GF_ResizeHandle.Edge.TOP
	_handle.position = Vector2(0, 0)
	_handle.size = Vector2(400, 8)
	_press()
	_motion(Vector2(4, 54))
	assert_eq(_window.size, Vector2(400, 250), "TOP 拖动 +50 应收矮")
	assert_eq(_window.position, Vector2(100, 150), "TOP 收缩应同步下移 position")


func test_bottom_edge_resizes_height() -> void:
	_handle.edge = GF_ResizeHandle.Edge.BOTTOM
	_handle.position = Vector2(0, 292)
	_handle.size = Vector2(400, 8)
	_press()
	_motion(Vector2(4, 104))
	assert_eq(_window.size, Vector2(400, 400), "BOTTOM 拖动 +100 应加高")
	assert_eq(_window.position, Vector2(100, 100), "BOTTOM 不改变位置")


func test_bottom_right_corner_resizes_both() -> void:
	_handle.edge = GF_ResizeHandle.Edge.BOTTOM_RIGHT
	_handle.position = Vector2(392, 292)
	_handle.size = Vector2(8, 8)
	_press()
	_motion(Vector2(54, 54))
	assert_eq(_window.size, Vector2(450, 350), "右下角应双向缩放")
	assert_eq(_window.position, Vector2(100, 100))


func test_top_left_corner_resizes_and_moves() -> void:
	_handle.edge = GF_ResizeHandle.Edge.TOP_LEFT
	_handle.position = Vector2(0, 0)
	_handle.size = Vector2(8, 8)
	_press()
	_motion(Vector2(54, 54))
	assert_eq(_window.size, Vector2(350, 250), "左上角应双向收缩")
	assert_eq(_window.position, Vector2(150, 150), "左上角收缩应同步移动 position")


# ============================================================
# 边界
# ============================================================

func test_min_size_clamp_fallback() -> void:
	# _panel_def 为 null 时用 MIN_FALLBACK_SIZE (320, 240)
	_press()
	_motion(Vector2(-400, 4))
	assert_eq(_window.size.x, 320.0, "不应小于兜底 min_size")


func test_min_size_clamp_from_def() -> void:
	_window._panel_def = GF_UIPanelDef.new("", "")
	_window._panel_def.window_min_size = Vector2(500, 400)
	_window.size = Vector2(800, 600)
	_press()
	_motion(Vector2(-2000, 4))
	assert_eq(_window.size.x, 500.0, "应钳制到 def.window_min_size")


func test_resize_finish_signal() -> void:
	var sizes: Array = []
	_window.resize_finished.connect(func(s): sizes.append(s))
	_press()
	_motion(Vector2(104, 4))
	_release()
	assert_eq(sizes.size(), 1, "松手应发射一次 resize_finished")
	assert_eq(sizes[0], _window.size)


# ============================================================
# 装配
# ============================================================

func test_cursor_shape_matches_edge() -> void:
	assert_eq(_handle.mouse_default_cursor_shape, Control.CURSOR_HSIZE, "RIGHT 应为水平光标")
	_handle.edge = GF_ResizeHandle.Edge.BOTTOM_RIGHT
	_handle._ready()
	assert_eq(_handle.mouse_default_cursor_shape, Control.CURSOR_FDIAGSIZE, "右下角应为对角光标")


func test_handle_without_window_ancestor_is_inert() -> void:
	# 不挂树：_ready 的 _find_window 会 push_warning，被 GUT 计为 unexpected error，
	# 这里直接验证未装配时 _window 为 null 且 _gui_input 安全返回
	var orphan := GF_ResizeHandle.new()
	assert_null(orphan._window, "未装配时窗口引用应为 null")

	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	orphan._gui_input(ev)
	orphan.free()
	pass_test("无窗口祖先时 _gui_input 不崩溃")
