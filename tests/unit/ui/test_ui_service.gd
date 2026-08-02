# tests/unit/ui/test_ui_service.gd
## GF_UIService 单元测试。
## 覆盖：生命周期、面板注册、UI 树创建、层级访问、面板开关。
extends GutTest

var _service: GF_UIService


func before_each() -> void:
	_service = GF_UIService.new()
	_service.module_name = "GF_UIService"
	_service.init_module()


func after_each() -> void:
	_service = null


# ============================================================
# 生命周期
# ============================================================

func test_init_returns_ok() -> void:
	var result := _service._on_init()
	assert_true(result.is_ok(), "_on_init 应返回 OK")


func test_dependencies_includes_scene_factory() -> void:
	var deps: Array = _service.dependencies()
	var has_factory := false
	for dep in deps:
		if dep == GF_SceneFactory:
			has_factory = true
			break
	assert_true(has_factory, "依赖中应包含 GF_SceneFactory")


func test_dependencies_count_is_three() -> void:
	var deps: Array = _service.dependencies()
	assert_eq(deps.size(), 3, "UI 服务应有 3 个依赖")


# ============================================================
# 面板注册
# ============================================================

func test_register_adds_def() -> void:
	var def := GF_UIPanelDef.new()
	def.name = "test_panel"
	def.path = "res://test.tscn"
	var result := _service.register(def)
	assert_true(result.is_ok(), "注册应成功")


func test_register_empty_name_fails() -> void:
	var def := GF_UIPanelDef.new()
	def.name = ""
	def.path = "res://test.tscn"
	var result := _service.register(def)
	assert_true(result.is_fail(), "空名称应失败")


func test_register_empty_path_fails() -> void:
	var def := GF_UIPanelDef.new()
	def.name = "panel"
	def.path = ""
	var result := _service.register(def)
	assert_true(result.is_fail(), "空路径应失败")


func test_register_all_batch() -> void:
	var defs: Array[GF_UIPanelDef] = []
	for i in 3:
		var def := GF_UIPanelDef.new()
		def.name = "panel_%d" % i
		def.path = "res://p%d.tscn" % i
		defs.append(def)

	var log := GF_FakeLogService.new()
	log.module_name = "FakeLog"
	log.init_module()
	_service._log = log

	var result := _service.register_all(defs)
	assert_true(result.is_ok(), "批量注册应成功")


# ============================================================
# UI 树创建
# ============================================================

func test_create_ui_tree_has_canvas() -> void:
	_service._create_ui_tree()
	var canvas: CanvasLayer = _service.get_ui_canvas()
	assert_not_null(canvas, "应有 CanvasLayer")
	assert_eq(canvas.name, "UiCanvas")
	assert_eq(canvas.layer, 100)


func test_create_ui_tree_has_ui_root() -> void:
	_service._create_ui_tree()
	var root: Control = _service.get_ui_root()
	assert_not_null(root, "应有 UIRoot")
	assert_eq(root.name, "UIRoot")


func test_ui_tree_has_six_layers() -> void:
	_service._create_ui_tree()
	var kinds: Array[StringName] = [
		GF_UIPanelDef.KIND_HUD,
		GF_UIPanelDef.KIND_SCREEN,
		GF_UIPanelDef.KIND_POPUP,
		GF_UIPanelDef.KIND_TOOLTIP,
		GF_UIPanelDef.KIND_SYSTEM,
		GF_UIPanelDef.KIND_DEBUG,
	]
	for kind in kinds:
		var layer := _service.get_ui_layer(kind)
		assert_not_null(layer, "%s 层不应为 null" % kind)


func test_layers_are_controls() -> void:
	_service._create_ui_tree()
	var layer := _service.get_ui_layer(GF_UIPanelDef.KIND_HUD)
	assert_true(layer is Control, "层应是 Control 类型")


# ============================================================
# get_ui_layer
# ============================================================

func test_get_ui_layer_hud_name() -> void:
	_service._create_ui_tree()
	var layer := _service.get_ui_layer(GF_UIPanelDef.KIND_HUD)
	assert_eq(layer.name, "HudLayer")


func test_get_ui_layer_screen_name() -> void:
	_service._create_ui_tree()
	var layer := _service.get_ui_layer(GF_UIPanelDef.KIND_SCREEN)
	assert_eq(layer.name, "ScreenLayer")


func test_get_ui_layer_system_name() -> void:
	_service._create_ui_tree()
	var layer := _service.get_ui_layer(GF_UIPanelDef.KIND_SYSTEM)
	assert_eq(layer.name, "SystemLayer")


func test_get_ui_layer_unknown_falls_back() -> void:
	_service._create_ui_tree()
	var layer := _service.get_ui_layer(&"nonexistent")
	assert_not_null(layer, "未知 kind 应回退到有效层")


# ============================================================
# 面板开关（手动注入 fake 依赖）
# ============================================================

func test_open_unregistered_fails() -> void:
	var svc := _make_configured_service()
	var result := svc.open("nonexistent")
	assert_true(result.is_fail(), "打开未注册面板应失败")


func test_open_and_close() -> void:
	var svc := _make_configured_service()
	_register_test_panel(svc, "shop")
	var result := svc.open("shop")
	assert_true(result.is_ok(), "打开应成功")
	assert_true(svc.is_open("shop"), "面板应为打开状态")
	svc.close("shop")
	assert_false(svc.is_open("shop"), "关闭后不应活跃")


func test_open_returns_panel_in_data() -> void:
	var svc := _make_configured_service()
	_register_test_panel(svc, "inventory")
	var result := svc.open("inventory")
	assert_not_null(result.data, "data 中应有面板实例")


func test_close_persistent_rejected() -> void:
	var svc := _make_configured_service()
	var def := GF_UIPanelDef.new()
	def.name = "hud"
	def.path = "res://hud.tscn"
	def.kind = GF_UIPanelDef.KIND_HUD
	def.lifecycle = GF_UIPanelDef.Lifecycle.PERSISTENT
	svc.register(def)
	svc.open("hud")
	var result := svc.close("hud")
	assert_true(result.is_fail(), "PERSISTENT 面板不应被普通 close 关闭")


func test_force_close_persistent_works() -> void:
	var svc := _make_configured_service()
	var def := GF_UIPanelDef.new()
	def.name = "hud_forced"
	def.path = "res://hud.tscn"
	def.kind = GF_UIPanelDef.KIND_HUD
	def.lifecycle = GF_UIPanelDef.Lifecycle.PERSISTENT
	svc.register(def)
	svc.open("hud_forced")
	var result := svc.force_close("hud_forced")
	assert_true(result.is_ok(), "force_close 应允许关闭 PERSISTENT 面板")


func test_close_top() -> void:
	var svc := _make_configured_service()
	_register_test_panel(svc, "bottom")
	_register_test_panel(svc, "top")
	svc.open("bottom")
	svc.open("top")
	svc.close_top()
	assert_false(svc.is_open("top"), "栈顶面板应被关闭")
	assert_true(svc.is_open("bottom"), "底层面板应保持打开")


func test_reopen_singleton_same_instance() -> void:
	var svc := _make_configured_service()
	var def := GF_UIPanelDef.new()
	def.name = "singleton_panel"
	def.path = "res://singleton.tscn"
	def.kind = GF_UIPanelDef.KIND_SCREEN
	def.singleton = true
	svc.register(def)

	var r1 := svc.open("singleton_panel")
	var panel1: GF_UIPanel = r1.data
	var r2 := svc.open("singleton_panel")
	var panel2: GF_UIPanel = r2.data
	assert_eq(panel1, panel2, "singleton 重复打开应返回同一实例")


func test_get_active_panels_count() -> void:
	var svc := _make_configured_service()
	_register_test_panel(svc, "a")
	_register_test_panel(svc, "b")
	svc.open("a")
	svc.open("b")
	var active := svc.get_active_panels()
	assert_eq(active.size(), 2, "应返回 2 个活跃面板")


func test_get_active_panel_names_contains() -> void:
	var svc := _make_configured_service()
	_register_test_panel(svc, "panel_x")
	svc.open("panel_x")
	var names := svc.get_active_panel_names()
	assert_true(names.has("panel_x"), "活跃面板名称中应包含 panel_x")


func test_show_hud_opens_persistent_hud() -> void:
	var svc := _make_configured_service()
	var def := GF_UIPanelDef.new()
	def.name = "hud_main"
	def.path = "res://hud_main.tscn"
	def.kind = GF_UIPanelDef.KIND_HUD
	def.lifecycle = GF_UIPanelDef.Lifecycle.PERSISTENT
	svc.register(def)
	svc.show_hud()
	assert_true(svc.is_open("hud_main"), "show_hud 应打开 PERSISTENT HUD 面板")


func test_close_all_keeps_persistent() -> void:
	var svc := _make_configured_service()
	var normal := GF_UIPanelDef.new()
	normal.name = "normal_panel"
	normal.path = "res://n.tscn"
	svc.register(normal)
	var persistent := GF_UIPanelDef.new()
	persistent.name = "hud_persist"
	persistent.path = "res://h.tscn"
	persistent.kind = GF_UIPanelDef.KIND_HUD
	persistent.lifecycle = GF_UIPanelDef.Lifecycle.PERSISTENT
	svc.register(persistent)

	svc.open("normal_panel")
	svc.open("hud_persist")
	svc.close_all()
	assert_false(svc.is_open("normal_panel"), "普通面板应被关闭")
	assert_true(svc.is_open("hud_persist"), "PERSISTENT 面板应保留")


func test_clear_gameplay_ui_keeps_hud() -> void:
	var svc := _make_configured_service()
	var screen_def := GF_UIPanelDef.new()
	screen_def.name = "inventory"
	screen_def.path = "res://inv.tscn"
	screen_def.kind = GF_UIPanelDef.KIND_SCREEN
	svc.register(screen_def)
	var hud_def := GF_UIPanelDef.new()
	hud_def.name = "my_hud"
	hud_def.path = "res://hud.tscn"
	hud_def.kind = GF_UIPanelDef.KIND_HUD
	svc.register(hud_def)

	svc.open("inventory")
	svc.open("my_hud")
	svc.clear_gameplay_ui()
	assert_false(svc.is_open("inventory"), "SCREEN 面板应被清除")
	assert_true(svc.is_open("my_hud"), "HUD 面板应保留")


# ============================================================
# 测试辅助方法
# ============================================================

func _make_configured_service() -> GF_UIService:
	var svc := GF_UIService.new()
	svc.module_name = "GF_UIService"
	svc.init_module()

	var log := GF_FakeLogService.new()
	log.module_name = "FakeLog"
	log.init_module()
	svc._log = log

	var fake_factory: Variant = GF_FakeSceneFactory.new()
	svc._scene_factory = fake_factory

	var fake_input: Variant = GF_FakeInputService.new()
	svc._input_service = fake_input

	svc._create_ui_tree()
	return svc


func _register_test_panel(p_svc: GF_UIService, p_name: String, p_kind: StringName = GF_UIPanelDef.KIND_SCREEN) -> void:
	var def := GF_UIPanelDef.new()
	def.name = p_name
	def.path = "res://%s.tscn" % p_name
	def.kind = p_kind
	def.close_on_escape = true
	p_svc.register(def)

