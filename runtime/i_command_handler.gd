## ICommandHandler
## 框架级命令处理器抽象。用于把命令执行逻辑从命令对象中拆出，
## 便于后续接入 Remote / Hybrid 策略时统一替换处理实现。
class_name ICommandHandler
extends RefCounted


## 声明本 Handler 处理的命令键。
func command_key() -> String:
	return ""


## 处理命令。子类应重写并返回 OperationResult。
func handle(_p_command, _p_context: Dictionary) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "ICommandHandler.handle 未实现", "ICommandHandler")
