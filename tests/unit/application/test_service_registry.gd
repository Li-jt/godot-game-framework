# tests/unit/application/test_service_registry.gd
## GF_ServiceRegistry 单元测试。
## 服务注册中心：优先级覆盖、owner 跟踪、必需 key 校验。
extends GutTest

var _registry: GF_ServiceRegistry


func before_each() -> void:
	_registry = GF_ServiceRegistry.new()


func after_each() -> void:
	_registry = null


# ============================================================
# 注册
# ============================================================

func test_register_stores_service() -> void:
	var result := _registry.register("TestSvc", RefCounted.new())
	assert_true(result.is_ok())
	assert_not_null(_registry.get_service("TestSvc"))


func test_register_empty_key_fails() -> void:
	var result := _registry.register("", RefCounted.new())
	assert_true(result.is_fail())
	assert_eq(result.status_code, GF_OperationResult.ERR_BAD_REQUEST)


func test_register_null_service_fails() -> void:
	var result := _registry.register("TestSvc", null)
	assert_true(result.is_fail())
	assert_eq(result.status_code, GF_OperationResult.ERR_BAD_REQUEST)


func test_register_all_stores_multiple() -> void:
	var entries: Array = [
		["SvcA", RefCounted.new()],
		["SvcB", RefCounted.new()],
	]
	var result := _registry.register_all(entries)
	assert_true(result.is_ok())
	assert_not_null(_registry.get_service("SvcA"))
	assert_not_null(_registry.get_service("SvcB"))


func test_has_returns_true_for_registered() -> void:
	_registry.register("TestSvc", RefCounted.new())
	assert_true(_registry.has("TestSvc"))


func test_has_returns_false_for_unregistered() -> void:
	assert_false(_registry.has("Nonexistent"))


# ============================================================
# 优先级覆盖
# ============================================================

func test_higher_priority_can_override() -> void:
	_registry.register_with_priority("TestSvc", RefCounted.new(), "owner_a", 50)
	var result := _registry.register_with_priority("TestSvc", RefCounted.new(), "owner_b", 30)
	assert_true(result.is_ok())


func test_lower_priority_cannot_override() -> void:
	_registry.register_with_priority("TestSvc", RefCounted.new(), "owner_a", 30)
	var result := _registry.register_with_priority("TestSvc", RefCounted.new(), "owner_b", 50)
	assert_true(result.is_fail())
	assert_eq(result.status_code, GF_OperationResult.ERR_CONFLICT)


func test_same_priority_cannot_override() -> void:
	_registry.register_with_priority("TestSvc", RefCounted.new(), "owner_a", 100)
	var result := _registry.register_with_priority("TestSvc", RefCounted.new(), "owner_b", 100)
	assert_true(result.is_fail())


# ============================================================
# 注销
# ============================================================

func test_unregister_removes_service() -> void:
	_registry.register("TestSvc", RefCounted.new())
	_registry.unregister("TestSvc")
	assert_false(_registry.has("TestSvc"))


func test_unregister_by_owner_batch() -> void:
	_registry.register_with_priority("SvcA", RefCounted.new(), "mod:test", 100)
	_registry.register_with_priority("SvcB", RefCounted.new(), "mod:test", 100)
	_registry.register_with_priority("SvcC", RefCounted.new(), "core", 50)

	var removed := _registry.unregister_by_owner("mod:test")
	assert_eq(removed, 2)
	assert_true(_registry.has("SvcC"))
	assert_false(_registry.has("SvcA"))


func test_owner_of_returns_correct() -> void:
	_registry.register_with_priority("TestSvc", RefCounted.new(), "my_owner", 100)
	assert_eq(_registry.owner_of("TestSvc"), "my_owner")


# ============================================================
# 校验
# ============================================================

func test_verify_pending_all_registered() -> void:
	_registry.register("SvcA", RefCounted.new())
	_registry.register("SvcB", RefCounted.new())
	_registry.add_required("SvcA")
	_registry.add_required("SvcB")
	var result := _registry.verify_pending()
	assert_true(result.is_ok())


func test_verify_pending_missing_key_fails() -> void:
	_registry.register("SvcA", RefCounted.new())
	_registry.add_required("SvcB")  # 未注册
	var result := _registry.verify_pending()
	assert_true(result.is_fail())


func test_count_accurate() -> void:
	assert_eq(_registry.count(), 0)
	_registry.register("A", RefCounted.new())
	_registry.register("B", RefCounted.new())
	assert_eq(_registry.count(), 2)
