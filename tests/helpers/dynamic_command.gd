# tests/helpers/dynamic_command.gd
## 动态 ICommand 测试替身。通过 _execute_fn 注入行为。
extends GF_ICommand

var _execute_fn: Callable
var _command_key: String = ""
var was_executed: bool = false


func command_key() -> String:
	return _command_key


func validate(p_context: Dictionary) -> GF_OperationResult:
	return GF_OperationResult.ok()


func execute(p_context: Dictionary) -> GF_OperationResult:
	was_executed = true
	if _execute_fn.is_valid():
		return _execute_fn.call(p_context)
	return GF_OperationResult.ok()
