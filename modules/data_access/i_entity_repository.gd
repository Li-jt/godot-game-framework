## GF_IEntityRepository — 实体持久化仓储接口。
##
## ⚠️ 预留接口：多人/网络模式（Remote / Hybrid Authority）。
## 当前 Local 模式不使用此接口，ECS World 直接通过 GF_SaveService 持久化。
##
## 计划用途：
##   - Remote Authority：服务端通过此接口管理实体 CRUD
##   - Hybrid Authority：客户端预测使用此接口做本地缓存
##
## 注意：此接口当前无实现，不要继承或使用。
class_name GF_IEntityRepository
extends RefCounted

func find_by_id(p_entity_id: String) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_IEntityRepository")


func find_all(p_type: String) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_IEntityRepository")


func create(p_entity_data: Dictionary) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_IEntityRepository")


func update(p_entity_id: String, p_data: Dictionary) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_IEntityRepository")


func remove(p_entity_id: String) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_IEntityRepository")
