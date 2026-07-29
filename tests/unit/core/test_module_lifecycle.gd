# tests/unit/core/test_module_lifecycle.gd
## ModuleLifecycle 单元测试。
## 所有 Service 的生命周期基类，状态机必须在所有情况下正确。
extends GutTest

# 内部 test double：可控 _on_init 返回值
class TestModule extends ModuleLifecycle:
	var init_should_fail: bool = false

	func _on_init() -> OperationResult:
		if init_should_fail:
			return OperationResult.fail(OperationResult.ERR_INTERNAL, "forced failure", "TestModule")
		return OperationResult.ok()


# ============================================================
# 初始化流程
# ============================================================

func test_init_from_uninitialized_to_initialized() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.init_module()
	assert_eq(m.state, CoreLifecycleState.State.INITIALIZED)


func test_on_init_default_returns_ok() -> void:
	var m := ModuleLifecycle.new()
	var result := m.init_module()
	assert_true(result.is_ok())
	assert_eq(m.state, CoreLifecycleState.State.INITIALIZED)


func test_init_is_idempotent_when_initialized() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.init_module()
	var result := m.init_module()  # 第二次调用
	assert_true(result.is_ok())
	assert_eq(m.state, CoreLifecycleState.State.INITIALIZED)


func test_init_returns_fail_when_disposed() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.dispose_module()
	var result := m.init_module()
	assert_true(result.is_fail())
	assert_eq(result.status_code, OperationResult.ERR_DISPOSED)


func test_init_failure_stays_in_failed() -> void:
	var m := TestModule.new()
	m.init_should_fail = true
	var result := m.init_module()
	assert_true(result.is_fail())
	assert_eq(m.state, CoreLifecycleState.State.FAILED)
	assert_eq(result.error.message, "forced failure")


# ============================================================
# 释放流程
# ============================================================

func test_dispose_sets_state() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.dispose_module()
	assert_eq(m.state, CoreLifecycleState.State.DISPOSED)


func test_dispose_is_idempotent() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.dispose_module()
	var result := m.dispose_module()  # 第二次
	assert_true(result.is_ok())
	assert_eq(m.state, CoreLifecycleState.State.DISPOSED)


func test_dispose_then_init_fails() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.dispose_module()
	var result := m.init_module()
	assert_true(result.is_fail())
	assert_eq(result.status_code, OperationResult.ERR_DISPOSED)


# ============================================================
# finalize_configuration
# ============================================================

func test_finalize_configuration_to_ready() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.init_module()
	var result := m.finalize_configuration()
	assert_true(result.is_ok())
	assert_eq(m.state, CoreLifecycleState.State.READY)


func test_finalize_configuration_rejects_uninitialized() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	var result := m.finalize_configuration()
	assert_true(result.is_fail())
	assert_eq(result.status_code, OperationResult.ERR_PRECONDITION)


func test_finalize_configuration_rejects_disposed() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.dispose_module()
	var result := m.finalize_configuration()
	assert_true(result.is_fail())


func test_finalize_configuration_idempotent_when_ready() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.init_module()
	m.finalize_configuration()
	var result := m.finalize_configuration()  # 第二次
	assert_true(result.is_ok())
	assert_eq(m.state, CoreLifecycleState.State.READY)


# ============================================================
# 状态查询
# ============================================================

func test_is_ready_when_ready() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.init_module()
	m.finalize_configuration()
	assert_true(m.is_ready())


func test_is_ready_when_only_initialized() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.init_module()
	assert_false(m.is_ready())


func test_is_failed_when_init_failed() -> void:
	var m := TestModule.new()
	m.init_should_fail = true
	m.init_module()
	assert_true(m.is_failed())


func test_is_failed_when_normal() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.init_module()
	assert_false(m.is_failed())


func test_is_initialized() -> void:
	var m := TestModule.new()
	m.module_name = "Test"
	m.init_module()
	assert_true(m.is_initialized())
