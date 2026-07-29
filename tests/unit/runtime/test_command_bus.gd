# tests/unit/runtime/test_command_bus.gd
extends GutTest

var _bus: CommandBus


func before_each() -> void:
	_bus = CommandBus.new()


func after_each() -> void:
	_bus = null


func test_execute_calls_command_execute() -> void:
	var executed := false
	var cmd = _make_command(null, func(_ctx):
		executed = true
		return OperationResult.ok()
	)
	var result := _bus.execute(cmd, {})
	assert_true(result.is_ok())
	assert_true(executed)


func test_execute_routes_to_registered_handler() -> void:
	var handler_called := false
	var handler = _make_handler("test.type", func(_cmd, _ctx):
		handler_called = true
		return OperationResult.ok()
	)
	_bus.register_handler(handler)
	var cmd = _make_command("test.type")
	var result := _bus.execute(cmd, {})
	assert_true(result.is_ok())
	assert_true(handler_called)


func test_handler_fail_propagates() -> void:
	var handler = _make_handler("block.test", func(_cmd, _ctx):
		return OperationResult.fail(OperationResult.ERR_PRECONDITION, "handler rejected", "TestHandler")
	)
	_bus.register_handler(handler)
	var cmd = _make_command("block.test")
	var result := _bus.execute(cmd, {})
	assert_true(result.is_fail())


func test_execute_null_command_fails() -> void:
	var result := _bus.execute(null, {})
	assert_true(result.is_fail())


# ============================================================
# Dynamic helpers
# ============================================================

func _make_command(p_key, p_execute_fn = null):
	var s := GDScript.new()
	var execute_body := ""
	if p_execute_fn:
		execute_body = "	if _execute_fn: return _execute_fn.call(p_context)\n	return OperationResult.ok()"
	else:
		execute_body = "	return OperationResult.ok()"
	var key_part := ""
	if p_key:
		key_part = "func command_key() -> String: return '%s'" % p_key
	else:
		key_part = "func command_key() -> String: return ''"

	s.source_code = """
extends ICommand
var _execute_fn
""" + key_part + """
func validate(p_context: Dictionary) -> OperationResult:
	return OperationResult.ok()
func execute(p_context: Dictionary) -> OperationResult:
""" + execute_body
	s.reload()
	var cmd = s.new()
	if p_execute_fn:
		cmd._execute_fn = p_execute_fn
	return cmd


func _make_handler(p_key: String, p_handle_fn):
	var s := GDScript.new()
	s.source_code = """
extends RefCounted
var _handle_fn
func command_key() -> String: return '%s'
func handle(p_command, p_context: Dictionary) -> OperationResult:
	if _handle_fn: return _handle_fn.call(p_command, p_context)
	return OperationResult.ok()
""" % p_key
	s.reload()
	var h = s.new()
	if p_handle_fn:
		h._handle_fn = p_handle_fn
	return h
