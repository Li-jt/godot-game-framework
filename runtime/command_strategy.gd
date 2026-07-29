## GF_CommandStrategy
## 命令执行策略抽象基类。Local/Remote/Hybrid 各自实现。
## CommandExecutor 通过 GF_RuntimeService 获取当前策略，不自己做模式判断。
class_name GF_CommandStrategy
extends RefCounted

## 执行命令。p_context 包含 WorldWriter 等运行时上下文。
func execute(p_command, p_context: Dictionary) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_CommandStrategy")
