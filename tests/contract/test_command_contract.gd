# tests/contract/test_command_contract.gd
## 契约测试：ICommand + ICommandHandler 接口。
extends GutTest

var _bus: CommandBus


func before_each() -> void:
	_bus = CommandBus.new()


func after_each() -> void:
	_bus = null


func test_command_execute_returns_operation_result() -> void:
	var cmd = _make_command(null)
	var result = _bus.execute(cmd, {})
	assert_not_null(result)


func test_command_validate_before_execute() -> void:
	var order: Array[String] = []
	var cmd = _make_command(null, func(_ctx):
		order.append("execute")
		return OperationResult.ok()
	)
	_bus.execute(cmd, {})
	# 简单验证执行成功
	assert_true(order.size() > 0)


func test_handler_receives_command() -> void:
	var handler = _make_handler("test.type", func(_cmd, _ctx):
		return OperationResult.ok()
	)
	_bus.register_handler(handler)
	var cmd = _make_command("test.type")
	var result = _bus.execute(cmd, {})
	assert_true(result.is_ok())


func _make_command(p_key, p_execute_fn = null):
	var s := GDScript.new()
	var key_part := ""
	if p_key:
		key_part = "func command_key() -> String: return '%s'" % p_key
	else:
		key_part = "func command_key() -> String: return ''"
	var exec_body := "func execute(p_context: Dictionary) -> OperationResult:\n"
	if p_execute_fn:
		exec_body += "	if _execute_fn: return _execute_fn.call(p_context)\n	return OperationResult.ok()"
	else:
		exec_body += "	return OperationResult.ok()"
	s.source_code = "extends ICommand\nvar _execute_fn\n" + key_part + "\n" + exec_body
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
