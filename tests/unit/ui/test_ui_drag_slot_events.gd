# tests/unit/ui/test_ui_drag_slot_events.gd
## GF_UIDragSlot 鼠标事件回调单元测试。
## 验证：单击/双击/右键/按下/松开/拖动开始/拖动结束 的判定与回调顺序，
## 以及拖动阈值、滑动抑制、失败复位、窗口失焦兜底。
extends GutTest

var _root: Control
var _probe: _EventProbeSlot


func before_each() -> void:
	_root = Control.new()
	add_child(_root)
	_probe = _EventProbeSlot.new()
	_probe.size = Vector2(64, 64)
	_root.add_child(_probe)
	_probe.set_slot_data({"item_id": "potion", "count": 1, "_tags": ["consumable"]})


func after_each() -> void:
	_root.free()
	_root = null
	_probe = null


# ════════════════════════════════════════════
# 单击 / 双击 / 按键
# ════════════════════════════════════════════

func test_left_click_fires_click() -> void:
	_press(MOUSE_BUTTON_LEFT)
	_release(MOUSE_BUTTON_LEFT)
	assert_eq(_probe.presses, [MOUSE_BUTTON_LEFT], "按下回调")
	assert_eq(_probe.releases, [MOUSE_BUTTON_LEFT], "松开回调")
	assert_eq(_probe.clicks, [MOUSE_BUTTON_LEFT], "单击回调")
	assert_eq(_probe.double_clicks, [], "不应有双击")
	assert_eq(_probe.drag_starts, 0, "不应有拖动")
	assert_false(_probe.begin_drag_called, "不应调用 begin_drag")


func test_right_click_fires_click() -> void:
	_press(MOUSE_BUTTON_RIGHT)
	_release(MOUSE_BUTTON_RIGHT)
	assert_eq(_probe.clicks, [MOUSE_BUTTON_RIGHT], "右键单击应上报")
	assert_eq(_probe.presses, [MOUSE_BUTTON_RIGHT], "右键按下应上报")
	assert_eq(_probe.double_clicks, [])


func test_middle_click_fires_click() -> void:
	_press(MOUSE_BUTTON_MIDDLE)
	_release(MOUSE_BUTTON_MIDDLE)
	assert_eq(_probe.clicks, [MOUSE_BUTTON_MIDDLE], "中键单击应上报")


func test_double_click_sequence() -> void:
	_press(MOUSE_BUTTON_LEFT)
	_release(MOUSE_BUTTON_LEFT)
	_press(MOUSE_BUTTON_LEFT, Vector2(10, 10), true)
	_release(MOUSE_BUTTON_LEFT)
	assert_eq(_probe.clicks, [MOUSE_BUTTON_LEFT], "双击只应触发一次单击（第一击）")
	assert_eq(_probe.double_clicks, [MOUSE_BUTTON_LEFT], "双击回调")
	assert_eq(_probe.releases, [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_LEFT], "两次松开都上报")
	assert_eq(_probe.presses, [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_LEFT], "两次按下都上报")


func test_release_without_press_ignored() -> void:
	_release(MOUSE_BUTTON_LEFT)
	assert_eq(_probe.presses, [])
	assert_eq(_probe.releases, [])
	assert_eq(_probe.clicks, [])


func test_second_button_press_while_holding_ignored() -> void:
	_press(MOUSE_BUTTON_LEFT)
	_press(MOUSE_BUTTON_RIGHT)
	_release(MOUSE_BUTTON_RIGHT)
	_release(MOUSE_BUTTON_LEFT)
	assert_eq(_probe.presses, [MOUSE_BUTTON_LEFT], "只记录第一个按下的按键")
	assert_eq(_probe.clicks, [MOUSE_BUTTON_LEFT])


# ════════════════════════════════════════════
# 拖动阈值判定
# ════════════════════════════════════════════

func test_drag_begins_after_threshold() -> void:
	_press(MOUSE_BUTTON_LEFT, Vector2(10, 10))
	_motion(Vector2(30, 10))  # 20px > 8px
	assert_true(_probe.begin_drag_called, "超过阈值应开始拖拽")
	assert_eq(_probe.drag_starts, 1, "拖动开始回调")
	_release(MOUSE_BUTTON_LEFT, Vector2(40, 10))
	assert_eq(_probe.clicks, [], "拖动不应触发单击")
	assert_eq(_probe.releases, [], "拖动中的松手不触发松开回调（由拖拽系统接管）")


func test_below_threshold_is_click() -> void:
	_press(MOUSE_BUTTON_LEFT, Vector2(10, 10))
	_motion(Vector2(15, 10))  # 5px < 8px
	_release(MOUSE_BUTTON_LEFT, Vector2(15, 10))
	assert_false(_probe.begin_drag_called, "未超阈值不应拖拽")
	assert_eq(_probe.clicks, [MOUSE_BUTTON_LEFT], "未超阈值应算单击")


func test_motion_at_threshold_boundary_is_drag() -> void:
	_press(MOUSE_BUTTON_LEFT, Vector2(10, 10))
	_motion(Vector2(18, 10))  # 8px == 阈值，应判定为拖动
	assert_true(_probe.begin_drag_called, "等于阈值应开始拖拽")


func test_drag_disabled_swipe_no_click() -> void:
	_probe.drag_enabled = false
	_press(MOUSE_BUTTON_LEFT, Vector2(10, 10))
	_motion(Vector2(30, 10))
	_release(MOUSE_BUTTON_LEFT, Vector2(30, 10))
	assert_false(_probe.begin_drag_called, "drag_enabled=false 不拖拽")
	assert_eq(_probe.clicks, [], "滑动不触发单击")
	# 状态已复位，后续点击正常
	_press(MOUSE_BUTTON_LEFT)
	_release(MOUSE_BUTTON_LEFT)
	assert_eq(_probe.clicks, [MOUSE_BUTTON_LEFT], "复位后点击正常")


func test_empty_slot_swipe_no_click_no_drag() -> void:
	_probe.set_slot_data({})
	_press(MOUSE_BUTTON_LEFT, Vector2(10, 10))
	_motion(Vector2(30, 10))
	_release(MOUSE_BUTTON_LEFT, Vector2(30, 10))
	assert_false(_probe.begin_drag_called, "空数据不拖拽")
	assert_eq(_probe.clicks, [], "滑动不触发单击")


func test_right_button_never_drags() -> void:
	_press(MOUSE_BUTTON_RIGHT, Vector2(10, 10))
	_motion(Vector2(30, 10))
	_release(MOUSE_BUTTON_RIGHT, Vector2(30, 10))
	assert_false(_probe.begin_drag_called, "右键不触发拖拽")
	assert_eq(_probe.clicks, [], "右键滑动不触发单击")


func test_press_during_drag_ignored() -> void:
	_press(MOUSE_BUTTON_LEFT, Vector2(10, 10))
	_motion(Vector2(30, 10))
	_press(MOUSE_BUTTON_LEFT, Vector2(30, 10))
	assert_eq(_probe.presses, [MOUSE_BUTTON_LEFT], "拖拽期间新的按下被忽略")


func test_begin_drag_failure_resets_state() -> void:
	_probe.begin_drag_result = GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "模拟失败", "test")
	_press(MOUSE_BUTTON_LEFT, Vector2(10, 10))
	_motion(Vector2(30, 10))
	assert_true(_probe.begin_drag_called, "失败也应尝试开始拖拽")
	assert_eq(_probe.drag_starts, 1)
	# 失败后状态复位：后续点击正常
	_press(MOUSE_BUTTON_LEFT)
	_release(MOUSE_BUTTON_LEFT)
	assert_eq(_probe.clicks, [MOUSE_BUTTON_LEFT], "失败复位后点击正常")


# ════════════════════════════════════════════
# 拖拽结束回调（真实 handler 接线）
# ════════════════════════════════════════════

func test_drag_ended_fires_on_cancel() -> void:
	var handler := GF_UIDragSlot._SlotDragHandler.new()
	handler._slot = _probe
	var event := GF_UIDragEvent.new()
	event.drop_receiver = null
	handler.on_end_drag(event)
	assert_eq(_probe.drag_ends, [false], "未放置 → accepted=false")


func test_drag_ended_fires_on_accept() -> void:
	var handler := GF_UIDragSlot._SlotDragHandler.new()
	handler._slot = _probe
	var event := GF_UIDragEvent.new()
	event.drop_receiver = _probe  # 任意非 null 代表有接收者
	handler.on_end_drag(event)
	assert_eq(_probe.drag_ends, [true], "有接收者 → accepted=true")


func test_drag_end_resets_press_state() -> void:
	# 模拟拖拽进行中
	_press(MOUSE_BUTTON_LEFT, Vector2(10, 10))
	_motion(Vector2(30, 10))
	assert_true(_probe.begin_drag_called)
	# handler 结束 → 复位按压跟踪
	var handler := GF_UIDragSlot._SlotDragHandler.new()
	handler._slot = _probe
	var event := GF_UIDragEvent.new()
	event.drop_receiver = null
	handler.on_end_drag(event)
	# 复位后点击正常
	_press(MOUSE_BUTTON_LEFT)
	_release(MOUSE_BUTTON_LEFT)
	assert_eq(_probe.clicks, [MOUSE_BUTTON_LEFT])


# ════════════════════════════════════════════
# 窗口失焦兜底
# ════════════════════════════════════════════

func test_focus_out_resets_press_state() -> void:
	_press(MOUSE_BUTTON_LEFT)
	_probe._notification(_probe.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	# 复位后点击正常
	_press(MOUSE_BUTTON_LEFT)
	_release(MOUSE_BUTTON_LEFT)
	assert_eq(_probe.clicks, [MOUSE_BUTTON_LEFT], "失焦复位后点击正常")


# ════════════════════════════════════════════
# 辅助
# ════════════════════════════════════════════

func _press(p_button: int, p_pos: Vector2 = Vector2(10, 10), p_double: bool = false) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = p_button
	mb.pressed = true
	mb.double_click = p_double
	mb.position = p_pos
	mb.global_position = p_pos
	_probe._on_gui_input(mb)


func _release(p_button: int, p_pos: Vector2 = Vector2(10, 10)) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = p_button
	mb.pressed = false
	mb.position = p_pos
	mb.global_position = p_pos
	_probe._input(mb)


func _motion(p_pos: Vector2) -> void:
	var me := InputEventMouseMotion.new()
	me.position = p_pos
	me.global_position = p_pos
	_probe._input(me)


# ════════════════════════════════════════════
# 辅助类
# ════════════════════════════════════════════

class _EventProbeSlot extends GF_UIDragSlot:

	var presses: Array[int] = []
	var releases: Array[int] = []
	var clicks: Array[int] = []
	var double_clicks: Array[int] = []
	var drag_starts: int = 0
	var drag_ends: Array[bool] = []
	var begin_drag_called: bool = false
	var begin_drag_result: GF_OperationResult = GF_OperationResult.ok()


	func _init() -> void:
		# 测试不涉及放置目标，关闭以避免 _try_register_drop_target 的延迟重试循环
		drop_enabled = false


	func _on_slot_pressed(p_button: int) -> void:
		presses.append(p_button)


	func _on_slot_released(p_button: int) -> void:
		releases.append(p_button)


	func _on_slot_clicked(p_button: int) -> void:
		clicks.append(p_button)


	func _on_slot_double_clicked(p_button: int) -> void:
		double_clicks.append(p_button)


	func _on_slot_drag_started() -> void:
		drag_starts += 1


	func _on_slot_drag_ended(p_accepted: bool) -> void:
		drag_ends.append(p_accepted)


	func _begin_slot_drag() -> GF_OperationResult:
		begin_drag_called = true
		return begin_drag_result
