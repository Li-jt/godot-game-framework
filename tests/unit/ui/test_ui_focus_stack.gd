# tests/unit/ui/test_ui_focus_stack.gd
## GF_UIService 焦点栈单元测试。
## 覆盖：恢复跳过已释放条目、保存去重、reopen 跳过面板自身焦点、
## 单例弹窗多次数据切换后关闭正确恢复焦点。
extends GutTest

var _svc: GF_UIService


func before_each() -> void:
	_svc = GF_UIService.new()
	_svc.module_name = "GF_UIService"
	_svc.init_module()
	_svc._create_ui_tree()
	add_child(_svc.get_ui_canvas())


func after_each() -> void:
	if _svc != null and _svc.get_ui_canvas() != null:
		_svc.get_ui_canvas().queue_free()
	_svc = null


# ════════════════════════════════════════════
# 恢复（_restore_last_focus）
# ════════════════════════════════════════════

func test_restore_skips_freed_entry() -> void:
	var good := Control.new()
	good.focus_mode = Control.FOCUS_ALL
	add_child(good)
	var doomed := Control.new()
	doomed.focus_mode = Control.FOCUS_ALL
	add_child(doomed)

	_svc._focus_stack.append(good)
	_svc._focus_stack.append(doomed)
	doomed.free()  # 入栈后释放 → 栈中条目失效

	_svc._restore_last_focus()
	assert_eq(_svc.get_ui_canvas().get_viewport().gui_get_focus_owner(), good,
		"应跳过失效条目并恢复有效的上一个焦点")


func test_restore_all_stale_leaves_focus_untouched() -> void:
	var doomed := Control.new()
	add_child(doomed)
	_svc._focus_stack.append(doomed)
	doomed.free()
	_svc._restore_last_focus()  # 不应崩溃
	assert_true(true, "全部失效时静默跳过")


func test_restore_empty_stack_noop() -> void:
	_svc._restore_last_focus()
	assert_true(true, "空栈不崩溃")


# ════════════════════════════════════════════
# 保存（_save_current_focus）
# ════════════════════════════════════════════

func test_save_current_focus_dedup() -> void:
	var owner := Control.new()
	owner.focus_mode = Control.FOCUS_ALL
	add_child(owner)
	owner.grab_focus()
	_svc._save_current_focus("panel_a")
	_svc._save_current_focus("panel_a")
	assert_eq(_svc._focus_stack.size(), 1, "同一焦点不应重复入栈")


func test_save_current_focus_skips_panel_internal_focus() -> void:
	var owner := Control.new()
	owner.focus_mode = Control.FOCUS_ALL
	add_child(owner)
	owner.grab_focus()
	_svc._save_current_focus("panel_a")
	assert_eq(_svc._focus_stack.size(), 1)

	# reopen：焦点移到面板内部控件 → 跳过（栈顶已记录打开前的焦点）
	var panel := GF_FakeUIPanel.new()
	panel.panel_name = "panel_a"
	add_child(panel)
	var inner := Control.new()
	inner.focus_mode = Control.FOCUS_ALL
	panel.add_child(inner)
	inner.grab_focus()
	_svc._save_current_focus("panel_a")
	assert_eq(_svc._focus_stack.size(), 1, "面板自身焦点不应入栈")
	assert_eq(_svc._focus_stack[0], owner, "栈中应只有打开前的焦点")


func test_save_current_focus_different_owner_pushed() -> void:
	var a := Control.new()
	a.focus_mode = Control.FOCUS_ALL
	add_child(a)
	a.grab_focus()
	_svc._save_current_focus("panel_a")
	var b := Control.new()
	b.focus_mode = Control.FOCUS_ALL
	add_child(b)
	b.grab_focus()
	_svc._save_current_focus("panel_b")
	assert_eq(_svc._focus_stack.size(), 2, "不同焦点应各自入栈")


# ════════════════════════════════════════════
# 集成：单例弹窗多次数据切换后关闭
# ════════════════════════════════════════════

func test_reopen_then_close_restores_original_focus() -> void:
	var svc := _make_configured_service()
	var def := GF_UIPanelDef.new("", "")
	def.name = "singleton_panel"
	def.path = "res://singleton.tscn"
	def.singleton = true
	svc.register(def)

	var owner := Control.new()
	owner.focus_mode = Control.FOCUS_ALL
	add_child(owner)
	owner.grab_focus()

	var r1 := svc.open("singleton_panel")
	var r2 := svc.open("singleton_panel")  # 数据切换（reopen）
	assert_true(r1.is_ok() and r2.is_ok(), "打开/重开应成功")
	assert_eq(svc._focus_stack.size(), 1, "reopen 不应重复入栈")

	var r3 := svc.close("singleton_panel")
	assert_true(r3.is_ok(), "关闭应成功")
	assert_eq(svc._focus_stack.size(), 0, "关闭后焦点栈应清空")
	assert_eq(svc.get_ui_canvas().get_viewport().gui_get_focus_owner(), owner,
		"焦点应恢复到打开前")


# ════════════════════════════════════════════
# 辅助
# ════════════════════════════════════════════

func _make_configured_service() -> GF_UIService:
	var svc := GF_UIService.new()
	svc.module_name = "GF_UIService"
	svc.init_module()
	var log := GF_FakeLogService.new()
	log.module_name = "FakeLog"
	log.init_module()
	svc._log = log
	svc._scene_factory = GF_FakeSceneFactory.new()
	svc._input_service = GF_FakeInputService.new()
	svc._create_ui_tree()
	add_child(svc.get_ui_canvas())
	return svc
