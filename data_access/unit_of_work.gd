## UnitOfWork — 工作单元。将一组相关变更作为一个原子操作提交。
##
## ⚠️ 预留接口：多人/网络模式（Remote / Hybrid Authority）。
## 当前 Local 模式不使用此接口。
##
## 计划用途：
##   - Remote Authority：服务端确保一组操作原子提交
##   - Hybrid Authority：客户端预测批量操作时使用
##
## 注意：此接口当前无实现，不要继承或使用。
##
## 使用方式：
##   [codeblock]
##   var uow := UnitOfWork.new()
##   var result := uow.begin(repository)
##   if result.is_fail(): return result
##   uow.add_change({"type": "place_building", ...})
##   uow.add_change({"type": "remove_item", ...})
##   return uow.commit()
##   [/codeblock]
class_name UnitOfWork
extends RefCounted

enum State { IDLE, ACTIVE, COMMITTED, ROLLED_BACK }

var state: State = State.IDLE
var _changes: ChangeSet = null
var _repository: IWorldRepository = null


## 开始工作单元。从 Repository 读取当前 revision 作为 expected_revision。
func begin(p_repository: IWorldRepository) -> OperationResult:
	var rev_result := p_repository.get_revision()
	if rev_result.is_fail():
		return rev_result

	_repository = p_repository
	_changes = ChangeSet.new()
	_changes.expected_revision = (rev_result.data as Revision).value
	state = State.ACTIVE
	return OperationResult.ok()


## 添加一条变更操作
func add_change(p_operation: Dictionary) -> void:
	if state != State.ACTIVE:
		return
	_changes.operations.append(p_operation)


## 提交所有变更。如果 revision 不匹配（并发冲突），返回 fail。
func commit() -> OperationResult:
	if state != State.ACTIVE:
		return OperationResult.fail(OperationResult.ERR_PRECONDITION, "UnitOfWork 未处于 ACTIVE 状态", "UnitOfWork")

	var result := _repository.commit_changes(_changes)
	if result.is_fail():
		state = State.ROLLED_BACK
		return result

	state = State.COMMITTED
	return OperationResult.ok()


## 丢弃所有变更
func rollback() -> OperationResult:
	if state == State.COMMITTED:
		return OperationResult.fail(OperationResult.ERR_PRECONDITION, "已提交的 UnitOfWork 不可回滚", "UnitOfWork")
	state = State.ROLLED_BACK
	_changes = null
	return OperationResult.ok()
