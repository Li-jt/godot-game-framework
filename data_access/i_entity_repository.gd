## IEntityRepository
## 实体数据访问抽象。管理单个实体的增删改查。
class_name IEntityRepository
extends RefCounted

func find_by_id(p_entity_id: String) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IEntityRepository")


func find_all(p_type: String) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IEntityRepository")


func create(p_entity_data: Dictionary) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IEntityRepository")


func update(p_entity_id: String, p_data: Dictionary) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IEntityRepository")


func remove(p_entity_id: String) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IEntityRepository")
