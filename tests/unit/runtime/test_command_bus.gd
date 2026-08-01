# tests/unit/runtime/test_command_bus.gd
## 使用 dynamic_command.was_executed / dynamic_handler.was_handled 断言，
## 避免 GDScript 闭包对 bool 值类型按值捕获的问题。
extends GutTest

var _bus: GF_CommandBus


func before_each() -> void:
	_bus = GF_CommandBus.new()


func after_each() -> void:
	_bus = null


func test_execute_calls_command_execute() -> void:
	var cmd = _make_command(null)
	var result := _bus.execute(cmd, {})
	assert_true(result.is_ok())
	assert_true(cmd.was_executed)


func test_execute_routes_to_registered_handler() -> void:
	var handler = _make_handler("test.type")
	_bus.register_handler(handler)
	var cmd = _make_command("test.type")
	var result := _bus.execute(cmd, {})
	assert_true(result.is_ok())
	assert_true(handler.was_handled)


func test_handler_fail_propagates() -> void:
	var handler = _make_handler("block.test", func(_cmd, _ctx):
		return GF_OperationResult.fail(GF_OperationResult.ERR_PRECONDITION, "handler rejected", "TestHandler")
	)
	_bus.register_handler(handler)
	var cmd = _make_command("block.test")
	var result := _bus.execute(cmd, {})
	assert_true(result.is_fail())


func test_execute_null_command_fails() -> void:
	var result := _bus.execute(null, {})
	assert_true(result.is_fail())


# ============================================================
# 辅助
# ============================================================

func _make_command(p_key, p_execute_fn = null):
	var cmd_script: GDScript = load("res://tests/helpers/dynamic_command.gd")
	var cmd = cmd_script.new()
	cmd._command_key = p_key if p_key else ""
	if p_execute_fn:
		cmd._execute_fn = p_execute_fn
	return cmd


func _make_handler(p_key: String, p_handle_fn = null):
	var handler_script: GDScript = load("res://tests/helpers/dynamic_handler.gd")
	var h = handler_script.new()
	h._command_key = p_key
	if p_handle_fn:
		h._handle_fn = p_handle_fn
	return h
