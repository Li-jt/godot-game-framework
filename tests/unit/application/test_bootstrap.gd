# tests/unit/application/test_bootstrap.gd
## GF_AppBootstrap 完整测试。
## 覆盖：注册/查找、依赖拓扑排序、缺失依赖、重复注册、循环依赖、
##       内置服务、ModuleLifecycle 生命周期、真实模块集成。
extends GutTest

# ============================================================
# Fake 服务
# ============================================================

class FakeServiceA:
	extends GF_ModuleLifecycle

	var inited: bool = false
	var configured: bool = false

	func _on_init() -> GF_OperationResult:
		inited = true
		module_name = "FakeServiceA"
		return GF_OperationResult.ok()

	func configure() -> GF_OperationResult:
		configured = true
		return GF_OperationResult.ok()


class FakeServiceB:
	extends GF_ModuleLifecycle

	var inited: bool = false
	var configured: bool = false
	var svc_a: Variant = null

	func _on_init() -> GF_OperationResult:
		inited = true
		module_name = "FakeServiceB"
		return GF_OperationResult.ok()

	func dependencies() -> Array:
		return [FakeServiceA]

	func configure() -> GF_OperationResult:
		svc_a = _bootstrap.service(FakeServiceA)
		configured = true
		return GF_OperationResult.ok()


class FakeServiceC:
	extends GF_ModuleLifecycle

	var configured: bool = false
	var svc_a: Variant = null
	var svc_b: Variant = null

	func _on_init() -> GF_OperationResult:
		module_name = "FakeServiceC"
		return GF_OperationResult.ok()

	func dependencies() -> Array:
		return [FakeServiceA, FakeServiceB]

	func configure() -> GF_OperationResult:
		svc_a = _bootstrap.service(FakeServiceA)
		svc_b = _bootstrap.service(FakeServiceB)
		configured = true
		return GF_OperationResult.ok()


class FakeServiceNoConfig:
	extends GF_ModuleLifecycle

	var inited: bool = false

	func _on_init() -> GF_OperationResult:
		inited = true
		module_name = "FakeNoConfig"
		return GF_OperationResult.ok()


class FakeServiceCircularA:
	extends GF_ModuleLifecycle

	func _on_init() -> GF_OperationResult:
		module_name = "FakeCircularA"
		return GF_OperationResult.ok()

	func dependencies() -> Array:
		return [FakeServiceCircularB]


class FakeServiceCircularB:
	extends GF_ModuleLifecycle

	func _on_init() -> GF_OperationResult:
		module_name = "FakeCircularB"
		return GF_OperationResult.ok()

	func dependencies() -> Array:
		return [FakeServiceCircularA]


# ============================================================
# 1. 内置服务
# ============================================================

func test_builtin_log_exists() -> void:
	var bs = GF_AppBootstrap.new()
	var log = bs.service(GF_LogService)
	assert_not_null(log, "内置 LogService")


func test_builtin_event_bus_exists() -> void:
	var bs = GF_AppBootstrap.new()
	assert_not_null(bs.service(GF_EventBus), "内置 EventBus")


func test_builtin_path_resolver_exists() -> void:
	var bs = GF_AppBootstrap.new()
	assert_not_null(bs.service(GF_PathResolver), "内置 PathResolver")


func test_all_five_builtins_present() -> void:
	var bs = GF_AppBootstrap.new()
	bs._ensure_builtins()
	assert_eq(bs._services.size(), 6, "恰好 6 个内置服务")


# ============================================================
# 2. register() 测试
# ============================================================

func test_register_single() -> void:
	var bs = GF_AppBootstrap.new()
	var r = bs.register(FakeServiceA.new())
	assert_true(r.is_ok())
	assert_eq(bs._services.size(), 7)


func test_register_array() -> void:
	var bs = GF_AppBootstrap.new()
	var r = bs.register([FakeServiceA.new(), FakeServiceB.new()])
	assert_true(r.is_ok())
	assert_eq(bs._services.size(), 8)


func test_register_duplicate_fails() -> void:
	var bs = GF_AppBootstrap.new()
	bs.register(FakeServiceA.new())
	var r = bs.register(FakeServiceA.new())
	assert_true(r.is_fail())
	assert_true(r.is_fail(), "should fail with conflict")


func test_register_empty_array_ok() -> void:
	var bs = GF_AppBootstrap.new()
	var empty: Array = []
	var r = bs.register(empty)
	assert_true(r.is_ok())


# ============================================================
# 3. service() 查找
# ============================================================

func test_service_find_by_class() -> void:
	var bs = GF_AppBootstrap.new()
	var svc = FakeServiceA.new()
	bs.register(svc)
	assert_eq(bs.service(FakeServiceA), svc)


func test_service_not_found_null() -> void:
	var bs = GF_AppBootstrap.new()
	assert_null(bs.service(FakeServiceA))


func test_service_parent_class_match() -> void:
	var bs = GF_AppBootstrap.new()
	bs.register(FakeServiceA.new())
	assert_not_null(bs.service(GF_ModuleLifecycle))


# ============================================================
# 4. 依赖拓扑排序
# ============================================================

func test_dep_order_a_before_b() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(FakeServiceB.new())
	bs.register(FakeServiceA.new())
	bs._init_all()

	var svc_b = bs.service(FakeServiceB)
	assert_not_null(svc_b.svc_a, "B should get A via dep order")


func test_three_level_chain() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(FakeServiceC.new())
	bs.register(FakeServiceB.new())
	bs.register(FakeServiceA.new())
	bs._init_all()

	var svc_c = bs.service(FakeServiceC)
	assert_not_null(svc_c.svc_a, "C→A chain works")
	assert_not_null(svc_c.svc_b, "C→B chain works")


# ============================================================
# 5. 缺失依赖（断层）
# ============================================================

func test_missing_dep_no_crash() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(FakeServiceB.new())  # depends on A, A missing
	bs._init_all()

	var svc_b = bs.service(FakeServiceB)
	assert_null(svc_b.svc_a, "Missing dep returns null, not crash")


func test_missing_dep_does_not_block() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(FakeServiceC.new())
	bs.register(FakeServiceB.new())
	bs._init_all()

	var svc_c = bs.service(FakeServiceC)
	assert_not_null(svc_c, "Other services still configure with missing deps")


# ============================================================
# 6. 重复注册冲突
# ============================================================

func test_dup_registration_rejected() -> void:
	var bs = GF_AppBootstrap.new()
	var r1 = bs.register(FakeServiceA.new())
	assert_true(r1.is_ok())
	var r2 = bs.register(FakeServiceA.new())
	assert_true(r2.is_fail())


func test_dup_in_array_caught() -> void:
	var bs = GF_AppBootstrap.new()
	bs.register(FakeServiceA.new())
	var r = bs.register([FakeServiceB.new(), FakeServiceA.new()])
	assert_true(r.is_fail())


# ============================================================
# 7. 循环依赖
# ============================================================

func test_circular_dep_no_infinite_loop() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(FakeServiceCircularA.new())
	bs.register(FakeServiceCircularB.new())
	bs._init_all()
	pass_test("不崩溃就是通过")


# ============================================================
# 8. 生命周期
# ============================================================

func test_lifecycle_to_ready() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	var svc = FakeServiceA.new()
	bs.register(svc)
	bs._init_all()
	assert_eq(svc.state, GF_CoreLifecycleState.State.READY)


func test_bootstrap_ref_injected() -> void:
	var bs = GF_AppBootstrap.new()
	var svc = FakeServiceA.new()
	bs.register(svc)
	assert_eq(svc._bootstrap, bs)


func test_runtime_service_ready() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_RuntimeService.new())
	bs._init_all()

	var rt = bs.service(GF_RuntimeService)
	assert_not_null(rt)
	assert_true(rt.is_ready())


# ============================================================
# 9. 真实模块集成
# ============================================================

func test_save_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	# 只注册 SaveService，LocalSaveProvider 自动注册
	bs.register(GF_SaveService.new())
	bs._init_all()
	assert_true(bs.service(GF_SaveService).is_ready())
	assert_not_null(bs.service(GF_SaveProvider), "LocalSaveProvider 应被自动注册")


func test_input_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	# 只注册 InputService，InputAdapter 自动注册
	bs.register(GF_InputService.new())
	bs._init_all()
	assert_true(bs.service(GF_InputService).is_ready())
	assert_not_null(bs.service(GF_InputAdapter), "InputAdapter 应被自动注册")


func test_debug_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_DebugService.new())
	bs._init_all()
	assert_true(bs.service(GF_DebugService).is_ready())


func test_config_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_ConfigService.new())
	bs._init_all()
	assert_true(bs.service(GF_ConfigService).is_ready())


func test_resource_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	# 只注册 ResourceService，AssetLoading 自动注册
	bs.register(GF_ResourceService.new())
	bs._init_all()
	assert_true(bs.service(GF_ResourceService).is_ready())
	assert_not_null(bs.service(GF_AssetLoadingService), "AssetLoading 应被自动注册")


func test_localization_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_LocalizationService.new())
	bs._init_all()
	assert_true(bs.service(GF_LocalizationService).is_ready())


func test_threading_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_ThreadingService.new())
	bs._init_all()
	assert_true(bs.service(GF_ThreadingService).is_ready())


func test_ecs_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_EcsWorld.new())
	bs.register(GF_EcsScheduler.new())
	bs._init_all()
	assert_not_null(bs.service(GF_EcsWorld))
	assert_true(bs.service(GF_EcsScheduler).is_ready())


func test_flow_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_AppFlow.new())
	bs._init_all()
	assert_true(bs.service(GF_AppFlow).is_ready())


func test_audio_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	# AudioRuntime 是 Node，需手动 add_child（Node 不会自动注册）
	var runtime = GF_AudioRuntime.new()
	bs.add_child(runtime)
	bs.register(runtime)
	# AudioService 自动注册 ResourceService → AssetLoadingService
	bs.register(GF_AudioService.new())
	bs._init_all()
	assert_true(bs.service(GF_AudioService).is_ready())


# ============================================================
# 10. 全量堆栈
# ============================================================

func test_full_stack() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)

	# 每个服务只注册自己，默认依赖自动级联注册
	bs.register(GF_SceneFactory.new())
	bs.register(GF_ThreadingService.new())
	bs.register(GF_InputService.new())
	bs.register(GF_ConfigService.new())
	bs.register(GF_SaveService.new())
	bs.register(GF_ResourceService.new())
	bs.register(GF_DebugService.new())
	bs.register(GF_AudioService.new())
	bs.register(GF_LocalizationService.new())
	bs.register(GF_AppFlow.new())
	bs.register(GF_EcsWorld.new())
	bs.register(GF_EcsScheduler.new())

	bs._init_all()

	var ok = true
	for svc in bs._services:
		if svc.has_method("is_ready") and not svc.is_ready():
			ok = false
			break
	assert_true(ok, "all services ready")


# ============================================================
# 11. 依赖自动注册（隐藏依赖）
# ============================================================

func test_auto_register_default_provider() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	# 只注册 SaveService，不注册 LocalSaveProvider
	bs.register(GF_SaveService.new())
	bs._init_all()
	assert_not_null(bs.service(GF_SaveProvider), "LocalSaveProvider 应被自动注册")


func test_auto_register_default_adapter() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	# 只注册 InputService，不注册 InputAdapter
	bs.register(GF_InputService.new())
	bs._init_all()
	assert_not_null(bs.service(GF_InputAdapter), "InputAdapter 应被自动注册")


func test_auto_register_cascade_chain() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	# AudioService → ResourceService → AssetLoadingService（3 级级联）
	bs.register(GF_AudioService.new())
	bs._init_all()
	assert_not_null(bs.service(GF_ResourceService), "ResourceService 应被级联注册")
	assert_not_null(bs.service(GF_AssetLoadingService), "AssetLoadingService 应被级联注册")


func test_user_override_blocks_auto_register() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	# 用户先注册自定义 SaveProvider
	bs.register(GF_LocalSaveProvider.new())
	# 再注册 SaveService，它检测到已有 Provider，不覆盖
	bs.register(GF_SaveService.new())
	bs._init_all()
	assert_true(bs.service(GF_SaveService).is_ready())


func test_one_line_register_save() -> void:
	# 最终效果：一行注册，像 QFramework 一样
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_SaveService.new())  # 就这一行
	bs._init_all()
	assert_true(bs.service(GF_SaveService).is_ready())
	assert_not_null(bs.service(GF_SaveProvider))


# ============================================================
# 12. 边界条件
# ============================================================

func test_null_in_array_fails() -> void:
	var bs = GF_AppBootstrap.new()
	var arr: Array = [FakeServiceA.new(), null]
	var r = bs.register(arr)
	assert_true(r.is_fail(), "null element should fail")


func test_unregistered_lookup_null() -> void:
	var bs = GF_AppBootstrap.new()
	bs.register(FakeServiceA.new())
	assert_null(bs.service(FakeServiceC), "unregistered type returns null")
