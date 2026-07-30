# tests/helpers/dynamic_handler.gd
## 动态 ICommandHandler 测试替身。通过 _handle_fn 注入行为。
extends RefCounted

var _handle_fn: Callable
var _command_key: String = ""
var was_handled: bool = false


func command_key() -> String:
	return _command_key


func handle(p_command, p_context: Dictionary) -> GF_OperationResult:
	was_handled = true
	if _handle_fn.is_valid():
		return _handle_fn.call(p_command, p_context)
	return GF_OperationResult.ok()
