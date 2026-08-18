# tests/unit/ui/test_ui_drag_slot_target_cleanup.gd
## GF_UIDragSlot drop target 生命周期测试（集成）。
## 覆盖：注册后 self 正确、完整拖拽（含 ghost）hit-test 无错、
## 格子释放自动注销 target、hit-test 跳过失效回调目标。
extends GutTest

var _bs: GF_AppBootstrap
var _svc: GF_UIService
var _panel: GF_UIPanel
var _slot: GF_UIDragSlot


func before_each() -> void:
	_bs = _Bootstrap.new()
	add_child(_bs)
	# bootstrap._ready() 已执行：builtins + UI 服务注册 + 配置（含 UI 树/拖拽管理器）
	_svc = _bs.service(GF_UIService) as GF_UIService
	# 用假工厂替换场景工厂，open() 返回假面板
	_svc._scene_factory = GF_FakeSceneFactory.new()
	var def := GF_UIPanelDef.new("", "")
	def.name = "test_panel"
	def.path = "res://test_panel.tscn"
	_svc.register(def)
	_svc.open("test_panel")
	_panel = _svc.get_panel("test_panel")
	# 在面板里放一个真实格子（drop_enabled=true 才会注册 drop target）
	_slot = GF_UIDragSlot.new()
	_slot.size = Vector2(64, 64)
	_slot.set_slot_data({"item_id": "potion", "_tags": ["consumable"]})
	_panel.add_child(_slot)
	# 等 _ready 里的延迟注册完成
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	_bs.queue_free()
	_bs = null
	_svc = null
	_panel = null
	_slot = null


# ════════════════════════════════════════════
# 注册正确性（ghost 报错回归）
# ════════════════════════════════════════════

func test_registered_target_lambda_self_is_slot() -> void:
	assert_not_null(_slot._registered_target, "格子应注册 drop target")
	var filter: Callable = _slot._registered_target.accept_filter
	assert_true(filter.is_valid(), "accept_filter 应有效")
	assert_eq(filter.get_object(), _slot, "accept_filter 的 self 应是格子本身，而不是 ghost")
	assert_true(filter.call({"item_id": "potion", "_tags": ["consumable"]}), "调用应成功")


func test_full_drag_with_ghost_hit_test_no_error() -> void:
	# 1. 按下并移动超过阈值 → 触发真实拖拽（内部创建 ghost）
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(10, 10)
	press.global_position = Vector2(10, 10)
	_slot._on_gui_input(press)

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(40, 40)
	motion.global_position = Vector2(40, 40)
	_slot._input(motion)

	assert_true(_svc.is_dragging(), "拖拽应已开始")
	var mgr := _svc.get_drag_manager()
	assert_not_null(mgr.get_current_event(), "拖拽事件应存在")

	# 2. 模拟拖拽移动（drag manager 的 _input 路径 → _on_drag_motion → _hit_test_target）
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.position = Vector2(50, 50)
	drag_motion.global_position = Vector2(50, 50)
	mgr._input(drag_motion)

	# 3. 直接命中测试：不应报错（含 ghost 分配后内存复用场景）
	var hit: GF_UIDropTarget = _svc._hit_test_target(Vector2(50, 50))
	assert_true(hit == _slot._registered_target or hit == null, "hit 应为格子的 target（或 null）")


# ════════════════════════════════════════════
# 释放清理
# ════════════════════════════════════════════

func test_slot_exit_tree_unregisters_target() -> void:
	var target: GF_UIDropTarget = _slot._registered_target
	assert_true(_svc._drop_targets.has(target), "注册后 target 应在服务中")
	_slot.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(_svc._drop_targets.has(target), "格子释放后其 target 应被注销")


func test_slot_free_unregisters_target_immediately() -> void:
	var target: GF_UIDropTarget = _slot._registered_target
	assert_true(_svc._drop_targets.has(target))
	_slot.free()
	assert_false(_svc._drop_targets.has(target), "free() 立即注销 target")


func test_rebuild_slots_keeps_only_new_targets() -> void:
	# 模拟游戏面板重建：旧格子释放 + 新格子创建（_on_reopen 模式）
	var old_target: GF_UIDropTarget = _slot._registered_target
	_slot.queue_free()

	var new_slot := GF_UIDragSlot.new()
	new_slot.size = Vector2(64, 64)
	new_slot.set_slot_data({"item_id": "sword", "_tags": ["weapon"]})
	_panel.add_child(new_slot)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(_svc._drop_targets.has(old_target), "旧格子的 target 应已注销")
	var found_new := false
	for t in _svc._drop_targets:
		if t.panel == _panel:
			found_new = true
	assert_true(found_new, "新格子应注册了新 target")


# ════════════════════════════════════════════
# hit-test 防御（残留失效目标）
# ════════════════════════════════════════════

func test_hit_test_skips_target_with_freed_callback_object() -> void:
	# 先启动拖拽（_hit_test_target 依赖当前拖拽事件）
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(10, 10)
	press.global_position = Vector2(10, 10)
	_slot._on_gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(40, 40)
	motion.global_position = Vector2(40, 40)
	_slot._input(motion)
	assert_true(_svc.is_dragging(), "拖拽应已开始")

	# 手动构造一个回调绑定到已释放格子的 target（模拟未能及时注销的残留目标）
	var doomed := GF_UIDragSlot.new()
	doomed.size = Vector2(64, 64)
	_panel.add_child(doomed)
	var target := GF_UIDropTarget.new()
	target.panel = _panel
	target.accept_filter = Callable(doomed, "_accepts")
	target.rect_provider = Callable(doomed, "_get_global_rect_for_target")
	_svc.register_drop_target(target)
	doomed.free()  # 释放后 target 的回调悬空

	var hit: GF_UIDropTarget = _svc._hit_test_target(Vector2(50, 50))
	assert_ne(hit, target, "绑定已释放对象的 target 应被跳过（不崩溃）")


# ════════════════════════════════════════════
# 辅助
# ════════════════════════════════════════════

class _Bootstrap extends GF_AppBootstrap:
	func _assemble() -> void:
		register(GF_UIService.new())
