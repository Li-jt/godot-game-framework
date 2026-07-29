## GF_LocalCommandStrategy
## Local 模式的命令执行策略。直接执行命令，不等待远程确认。
class_name GF_LocalCommandStrategy
extends GF_CommandStrategy

var _handler: Callable
var _command_bus: Variant = null


## p_handler: func(command, context: Dictionary) -> GF_OperationResult
func configure(p_handler: Callable) -> void:
	_handler = p_handler


## 配置命令总线。未配置 handler 时将通过总线执行命令。
func configure_command_bus(p_bus) -> void:
	_command_bus = p_bus


func execute(p_command, p_context: Dictionary) -> GF_OperationResult:
	if _handler != null and _handler.is_valid():
		return _handler.call(p_command, p_context)
	if _command_bus != null:
		return _command_bus.execute(p_command, p_context)
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "GF_LocalCommandStrategy 未配置 handler 或 command_bus", "GF_LocalCommandStrategy")
