## IWorldRepository
## 世界状态数据访问抽象。管理世界的完整快照存取。
## Game 层通过此接口保存/恢复世界，不关心底层存储方式。
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
