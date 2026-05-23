## EcsWorld — ECS 世界核心。
## 管理实体生命周期、组件存储和世界版本号。
## 所有 ECS 操作均通过此对象完成，不直接操作存储层。
class_name EcsWorld
extends RefCounted

var _entities: Dictionary = {}  # int entity_id -> bool (存在标记)
var _registry: EcsComponentTypeRegistry = null
var _storage_index: EcsStorageIndex = null
var _version: int = 0


func _init() -> void:
	_registry = EcsComponentTypeRegistry.new()
	_storage_index = EcsStorageIndex.new()


# ============================================================
# 实体生命周期
# ============================================================


## 生成一个新实体，返回实体 ID。
func spawn() -> int:
	var id := EcsEntityId.create()
	_entities[id] = true
	_version += 1
	return id


## 销毁实体及其全部组件。不存在时返回 false。
func despawn(p_entity: int) -> bool:
	if not _entities.has(p_entity):
		return false
	_entities.erase(p_entity)
	for type_id in _storage_index.all_type_ids():
		var storage := _storage_index.get_storage(type_id)
		if storage != null and storage.contains(p_entity):
			storage.erase(p_entity)
	_version += 1
	return true


## 检查实体是否存在。
func has_entity(p_entity: int) -> bool:
	return _entities.has(p_entity)


## 返回当前世界存活实体数量。
func entity_count() -> int:
	return _entities.size()


# ============================================================
# 组件操作
# ============================================================


## 为实体添加组件。实体已拥有同类型组件时返回冲突错误。
func add_component(p_entity: int, p_type: StringName, p_data: Variant) -> OperationResult:
	if not _entities.has(p_entity):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "实体不存在: %d" % p_entity, "EcsWorld")
	var reg_result := _registry.register_type(p_type)
	if reg_result.is_fail():
		return reg_result
	var type_id: int = reg_result.data
	var storage := _storage_index.get_or_create_storage(type_id)
	if storage.contains(p_entity):
		return OperationResult.fail(OperationResult.ERR_CONFLICT, "实体 %d 已拥有组件 %s" % [p_entity, p_type], "EcsWorld")
	storage.insert(p_entity, p_data)
	_version += 1
	return OperationResult.ok()


## 为实体设置组件数据（存在则覆盖，不存在则新增）。
func set_component(p_entity: int, p_type: StringName, p_data: Variant) -> OperationResult:
	if not _entities.has(p_entity):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "实体不存在: %d" % p_entity, "EcsWorld")
	var reg_result := _registry.register_type(p_type)
	if reg_result.is_fail():
		return reg_result
	var type_id: int = reg_result.data
	var storage := _storage_index.get_or_create_storage(type_id)
	storage.insert(p_entity, p_data)
	_version += 1
	return OperationResult.ok()


## 获取实体的组件数据，不存在时返回 null。
func get_component(p_entity: int, p_type: StringName) -> Variant:
	if not _entities.has(p_entity):
		return null
	var type_id := _registry.type_id_of(p_type)
	if type_id == 0:
		return null
	var storage := _storage_index.get_storage(type_id)
	if storage == null:
		return null
	return storage.get_data(p_entity)


## 移除实体的组件，不存在时静默忽略。
func remove_component(p_entity: int, p_type: StringName) -> void:
	if not _entities.has(p_entity):
		return
	var type_id := _registry.type_id_of(p_type)
	if type_id == 0:
		return
	var storage := _storage_index.get_storage(type_id)
	if storage == null:
		return
	storage.erase(p_entity)
	_version += 1


## 检查实体是否拥有指定组件。
func has_component(p_entity: int, p_type: StringName) -> bool:
	if not _entities.has(p_entity):
		return false
	var type_id := _registry.type_id_of(p_type)
	if type_id == 0:
		return false
	var storage := _storage_index.get_storage(type_id)
	if storage == null:
		return false
	return storage.contains(p_entity)


# ============================================================
# 世界级操作
# ============================================================


## 返回世界版本号，每次结构变更后递增。
func get_version() -> int:
	return _version


## 获取组件类型注册中心（只读引用）。
func get_registry() -> EcsComponentTypeRegistry:
	return _registry


## 获取存储索引（只读引用）。
func get_storage_index() -> EcsStorageIndex:
	return _storage_index


## 返回所有存活实体 ID 列表。
func all_entities() -> PackedInt64Array:
	var result := PackedInt64Array()
	for id in _entities.keys():
		result.append(id)
	return result
