## ISaveRepository — 存档数据访问抽象。
##
## ⚠️ 预留接口：多人/网络模式（Remote / Hybrid Authority）。
## 当前 Local 模式不使用此接口，存档通过 SaveService + SaveProvider 管理。
##
## 计划用途：
##   - Remote Authority：服务端通过此接口屏蔽本地文件/远程 API 差异
##   - Hybrid Authority：客户端通过此接口做本地存档缓存
##
## 注意：此接口当前无实现，不要继承或使用。
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
