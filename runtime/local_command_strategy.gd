## LocalCommandStrategy
## Local 模式的命令执行策略。直接执行命令，不等待远程确认。
class_name LocalCommandStrategy
extends CommandStrategy

var _handler: Callable


## p_handler: func(command, context: Dictionary) -> OperationResult
func configure(p_handler: Callable) -> void:
	_handler = p_handler


func execute(p_command, p_context: Dictionary) -> OperationResult:
	if _handler == null or not _handler.is_valid():
		return OperationResult.fail(OperationResult.ERR_INTERNAL, "LocalCommandStrategy 未配置 handler", "LocalCommandStrategy")
	return _handler.call(p_command, p_context)
