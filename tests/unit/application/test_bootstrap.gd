# tests/unit/application/test_bootstrap.gd
extends GutTest

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
	var svc_a: Variant = null
	func _on_init() -> GF_OperationResult:
		module_name = "FakeServiceB"
		return GF_OperationResult.ok()
	func dependencies() -> Array:
		return [FakeServiceA]
	func configure() -> GF_OperationResult:
		svc_a = _bootstrap.service(FakeServiceA)
		return GF_OperationResult.ok()

class FakeServiceC:
	extends GF_ModuleLifecycle
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

func test_builtin_log_exists() -> void:
	var bs = GF_AppBootstrap.new()
	assert_not_null(bs.service(GF_LogService), "builtin LogService")

func test_builtin_event_bus_exists() -> void:
	var bs = GF_AppBootstrap.new()
	assert_not_null(bs.service(GF_EventBus), "builtin EventBus")

func test_all_six_builtins_present() -> void:
	var bs = GF_AppBootstrap.new()
	bs._ensure_builtins()
	assert_eq(bs._services.size(), 6, "6 builtins")

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

func test_register_empty_array_ok() -> void:
	var bs = GF_AppBootstrap.new()
	var r = bs.register([])
	assert_true(r.is_ok())

func test_service_find_by_class() -> void:
	var bs = GF_AppBootstrap.new()
	var svc = FakeServiceA.new()
	bs.register(svc)
	assert_eq(bs.service(FakeServiceA), svc)

func test_service_not_found_null() -> void:
	var bs = GF_AppBootstrap.new()
	assert_null(bs.service(FakeServiceA))

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
	assert_not_null(svc_c.svc_a)
	assert_not_null(svc_c.svc_b)

func test_missing_dep_no_crash() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(FakeServiceB.new())
	bs._init_all()
	var svc_b = bs.service(FakeServiceB)
	assert_null(svc_b.svc_a, "Missing dep returns null")

func test_circular_dep_no_infinite_loop() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(FakeServiceCircularA.new())
	bs.register(FakeServiceCircularB.new())
	bs._init_all()
	pass_test("no crash")

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

func test_save_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_SaveService.new())
	bs._init_all()
	assert_true(bs.service(GF_SaveService).is_ready())
	assert_not_null(bs.service(GF_SaveProvider))

func test_input_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_InputService.new())
	bs._init_all()
	assert_true(bs.service(GF_InputService).is_ready())
	assert_not_null(bs.service(GF_InputAdapter))

func test_ecs_module() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_EcsWorld.new())
	bs.register(GF_EcsScheduler.new())
	bs._init_all()
	assert_not_null(bs.service(GF_EcsWorld))
	assert_true(bs.service(GF_EcsScheduler).is_ready())

func test_auto_register_default_provider() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_SaveService.new())
	bs._init_all()
	assert_not_null(bs.service(GF_SaveProvider))

func test_auto_register_default_adapter() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_InputService.new())
	bs._init_all()
	assert_not_null(bs.service(GF_InputAdapter))

func test_user_override_blocks_auto_register() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_LocalSaveProvider.new())
	bs.register(GF_SaveService.new())
	bs._init_all()
	assert_true(bs.service(GF_SaveService).is_ready())

func test_send_command_works() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs._init_all()
	var r = bs.send_command(null, {})
	assert_true(r.is_fail(), "null command should fail gracefully")

func test_full_stack_minimal() -> void:
	var bs = GF_AppBootstrap.new()
	add_child(bs)
	bs.register(GF_SceneFactory.new())
	bs.register(GF_InputService.new())
	bs.register(GF_SaveService.new())
	bs.register(GF_DebugService.new())
	bs.register(GF_ConfigService.new())
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

func test_unregistered_lookup_null() -> void:
	var bs = GF_AppBootstrap.new()
	bs.register(FakeServiceA.new())
	assert_null(bs.service(FakeServiceC))
