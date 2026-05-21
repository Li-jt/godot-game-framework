## ICommand
## 框架级命令抽象。Game 层命令可继承此类接入 CommandBus。
## 命令应保持“可验证 + 可执行”的最小行为约定：
## - command_key()：返回用于路由到 Handler 的命令键
## - validate()：可选的前置校验（默认通过）
## - execute()：默认执行入口（当未注册 Handler 时可直接执行）
class_name ICommand
extends RefCounted


## 返回命令键（如 "place_building"）。为空时表示无法路由到显式 Handler。
func command_key() -> String:
	return ""


## 命令前置校验。默认直接通过。
func validate(_p_context: Dictionary) -> OperationResult:
	return OperationResult.ok()


## 执行命令。子类应重写。
func execute(_p_context: Dictionary) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "ICommand.execute 未实现", "ICommand")
