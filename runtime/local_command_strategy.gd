## LocalCommandStrategy
## Local 模式的命令执行策略。直接执行命令，不等待远程确认。
class_name LocalCommandStrategy
extends CommandStrategy

var _handler: Callable
var _command_bus = null


## p_handler: func(command, context: Dictionary) -> OperationResult
func configure(p_handler: Callable) -> void:
	_handler = p_handler


## 配置命令总线。未配置 handler 时将通过总线执行命令。
func configure_command_bus(p_bus) -> void:
	_command_bus = p_bus


func execute(p_command, p_context: Dictionary) -> OperationResult:
	if _handler != null and _handler.is_valid():
		return _handler.call(p_command, p_context)
	if _command_bus != null:
		return _command_bus.execute(p_command, p_context)
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "LocalCommandStrategy 未配置 handler 或 command_bus", "LocalCommandStrategy")
