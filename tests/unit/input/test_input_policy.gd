# tests/unit/input/test_input_policy.gd
extends GutTest

var _policy: GF_InputPolicy


func before_each() -> void:
	_policy = GF_InputPolicy.new()


func after_each() -> void:
	_policy = null


func test_empty_stack_does_not_block() -> void:
	# 空上下文栈时，动作不被 can_be_blocked 明确阻挡
	var dummy_event := InputEventKey.new()
	assert_false(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))


func test_allowlist_allows_action() -> void:
	var ctx := GF_InputContext.new()
	ctx.allowed_actions = ["jump", "move"]
	_policy.get_context_stack().append(ctx)

	var dummy_event := InputEventKey.new()
	# allowed 里的动作不会被 context 阻挡
	assert_false(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))


func test_block_all_game_actions_blocks() -> void:
	var ctx := GF_InputContext.new()
	ctx.block_all_game_actions = true
	_policy.get_context_stack().append(ctx)

	var dummy_event := InputEventKey.new()
	assert_true(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))


func test_blocked_action_ids_blocks_specific() -> void:
	var ctx := GF_InputContext.new()
	ctx.blocked_action_ids = ["ui_click"]
	_policy.get_context_stack().append(ctx)

	var dummy_event := InputEventKey.new()
	assert_true(_policy.is_action_blocked("ui_click", dummy_event, Vector2.INF))
	assert_false(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))


func test_wildcard_blocks_all() -> void:
	var ctx := GF_InputContext.new()
	ctx.blocked_action_ids = ["*"]
	_policy.get_context_stack().append(ctx)

	var dummy_event := InputEventKey.new()
	assert_true(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))
	assert_true(_policy.is_action_blocked("any_action", dummy_event, Vector2.INF))


func test_pop_context_restores() -> void:
	var ctx1 := GF_InputContext.new()
	ctx1.blocked_action_ids = ["jump"]
	_policy.get_context_stack().append(ctx1)

	var ctx2 := GF_InputContext.new()
	ctx2.block_all_game_actions = true
	_policy.get_context_stack().append(ctx2)

	var dummy_event := InputEventKey.new()
	assert_true(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))

	_policy.get_context_stack().pop_back()
	# ctx1 只 blocked jump
	assert_true(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))

	_policy.get_context_stack().pop_back()
	assert_false(_policy.is_action_blocked("jump", dummy_event, Vector2.INF))


# ============================================================
# UI POINTER_ONLY 顶层命中（窗口模式）
# ============================================================

func test_ui_pointer_only_topmost_panel_blocks() -> void:
	var ui := _FakeUIForPolicy.new()
	var panel := GF_FakeUIPanel.new()
	var def := GF_UIPanelDef.new("", "")
	def.input_block_mode = GF_UIPanelDef.InputBlockMode.POINTER_ONLY
	def.blocked_action_ids = ["move"]
	panel._panel_def = def
	ui.top_panel = panel
	_policy.set_ui_service(ui)

	var dummy_event := InputEventKey.new()
	assert_true(_policy.is_action_blocked("move", dummy_event, Vector2(10, 10)), "顶层 POINTER_ONLY 面板应阻挡 move")
	assert_false(_policy.is_action_blocked("jump", dummy_event, Vector2(10, 10)), "非 blocked 动作不应阻挡")
	panel.free()


func test_ui_pointer_no_top_panel_no_block() -> void:
	var ui := _FakeUIForPolicy.new()
	_policy.set_ui_service(ui)

	var dummy_event := InputEventKey.new()
	assert_false(_policy.is_action_blocked("move", dummy_event, Vector2(10, 10)), "无命中面板时不应阻挡")


func test_ui_pointer_skips_when_dragging() -> void:
	var ui := _FakeUIForPolicy.new()
	ui.dragging = true
	var panel := GF_FakeUIPanel.new()
	var def := GF_UIPanelDef.new("", "")
	def.input_block_mode = GF_UIPanelDef.InputBlockMode.POINTER_ONLY
	def.blocked_action_ids = ["move"]
	panel._panel_def = def
	ui.top_panel = panel
	_policy.set_ui_service(ui)

	var dummy_event := InputEventKey.new()
	assert_false(_policy.is_action_blocked("move", dummy_event, Vector2(10, 10)), "拖拽中不应阻挡")
	panel.free()


func test_ui_pointer_converts_viewport_to_canvas_coords() -> void:
	# stretch/mode=canvas_items 回归：InputEvent 指针是 viewport 坐标，面板
	# hit-test 是 canvas 坐标，缩放窗口下不一致 → 必须先换算（同 drag manager）
	var ui := _FakeUIForPolicy.new()
	var panel := GF_FakeUIPanel.new()
	var def := GF_UIPanelDef.new("", "")
	def.input_block_mode = GF_UIPanelDef.InputBlockMode.POINTER_ONLY
	def.blocked_action_ids = ["move"]
	panel._panel_def = def
	ui.top_panel = panel
	_policy.set_ui_service(ui)

	# 临时给根 viewport 施加 2 倍 canvas 缩放，模拟拉伸窗口（测后恢复）
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	add_child(root)
	ui.ui_root = root
	var vp: Viewport = root.get_viewport()
	vp.canvas_transform = Transform2D(2.0, Vector2.ZERO)

	var dummy_event := InputEventKey.new()
	assert_true(_policy.is_action_blocked("move", dummy_event, Vector2(40, 40)),
		"viewport 位置 (40,40) 换算后应命中面板区域")
	# 关键断言：传给 hit-test 的位置必须被换算（2 倍缩放 → 约 (20,20)），
	# 而不是原始 viewport 坐标 (40,40)——修复前正是传原值导致阻挡失效
	assert_ne(ui.last_pos, Vector2(40, 40), "传入 hit-test 的位置应已被换算")
	assert_true(ui.last_pos.x < 40.0, "2 倍 canvas 缩放下换算位置应缩小（x≈20，实际 %s）" % str(ui.last_pos))

	vp.canvas_transform = Transform2D.IDENTITY
	root.free()
	panel.free()


# ============================================================
# 内部 fake
# ============================================================

## GF_UIService 的鸭子类型 fake。GUT 9.6 对 GF_UIService 生成 double 源码会解析失败，
## 而 GF_InputPolicy 对 _ui_service 本就是鸭子类型调用（is_dragging / get_top_panel_at_position）。
class _FakeUIForPolicy:
	var dragging := false
	var top_panel: Variant = null
	var ui_root: Variant = null
	var last_pos := Vector2.INF

	func is_dragging() -> bool:
		return dragging

	func get_top_panel_at_position(p_pos: Vector2) -> Variant:
		last_pos = p_pos
		return top_panel

	func get_ui_root() -> Variant:
		return ui_root

	func get_active_panels() -> Array:
		return []
