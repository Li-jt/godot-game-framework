## IWorldRepository — 世界状态数据访问抽象。
##
## ⚠️ 预留接口：多人/网络模式（Remote / Hybrid Authority）。
## 当前 Local 模式不使用此接口，ECS World 直接通过 SaveService 持久化。
##
## 计划用途：
##   - Remote Authority：服务端通过此接口管理世界快照存取
##   - Hybrid Authority：客户端预测使用此接口做本地世界缓存
##
## 注意：此接口当前无实现，不要继承或使用。
class_name IWorldRepository
extends RefCounted

## 获取当前世界的完整快照（Dictionary 形式）
func fetch_world_snapshot() -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IWorldRepository")


## 用快照恢复世界状态
func apply_world_snapshot(p_snapshot: Dictionary) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IWorldRepository")


## 提交变更集。检查 expected_revision 防止并发覆盖。
func commit_changes(p_changes: ChangeSet) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IWorldRepository")


## 获取当前世界状态版本号
func get_revision() -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IWorldRepository")
