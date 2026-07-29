## GF_ICommandHandler
## 框架级命令处理器抽象。用于把命令执行逻辑从命令对象中拆出，
## 便于后续接入 Remote / Hybrid 策略时统一替换处理实现。
class_name GF_ICommandHandler
extends RefCounted


## 声明本 Handler 处理的命令键。
func command_key() -> String:
	return ""


## 处理命令。子类应重写并返回 GF_OperationResult。
func handle(_p_command, _p_context: Dictionary) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "GF_ICommandHandler.handle 未实现", "GF_ICommandHandler")
