## GF_ICommand
## 框架级命令抽象。Game 层命令可继承此类接入 GF_CommandBus。
## 命令应保持“可验证 + 可执行”的最小行为约定：
## - command_key()：返回用于路由到 Handler 的命令键
## - validate()：可选的前置校验（默认通过）
## - execute()：默认执行入口（当未注册 Handler 时可直接执行）
class_name GF_ICommand
extends RefCounted


## 返回命令键（如 "place_building"）。为空时表示无法路由到显式 Handler。
func command_key() -> String:
	return ""


## 命令前置校验。默认直接通过。
func validate(_p_context: Dictionary) -> GF_OperationResult:
	return GF_OperationResult.ok()


## 执行命令。子类应重写。
func execute(_p_context: Dictionary) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "GF_ICommand.execute 未实现", "GF_ICommand")


## 命令是否确定性（性能路线图 §3.3 命令日志约束）。
## 确定性命令：同参数重放结果一致，禁止读时钟/随机源——
## 随机改为「命令携带随机数或种子派生」。默认 false，
## 确定命令重写返回 true 才可入 GF_CommandLog。
func is_deterministic() -> bool:
	return false


## 序列化为日志条目（确定性命令需实现，供日志记录与重放重建）。
## 返回纯数据字典（JSON 友好），重放时经命令工厂还原。
func serialize_for_log() -> Dictionary:
	return {}
