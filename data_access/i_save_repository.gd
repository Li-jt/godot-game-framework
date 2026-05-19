## ISaveRepository
## 存档数据访问抽象。屏蔽本地文件/远程 API 差异。
## Game 层通过此接口读存，不关心数据来源。
class_name ISaveRepository
extends RefCounted

func save(p_slot: int, p_data: Dictionary, p_meta: SaveMeta) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "ISaveRepository")


func load(p_slot: int) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "ISaveRepository")


func list_slots() -> Array[SaveMeta]:
	return []


func delete(p_slot: int) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "ISaveRepository")
