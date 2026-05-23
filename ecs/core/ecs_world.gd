## EcsWorld — ECS 世界核心。
## 管理实体生命周期、组件存储、ID 分配和世界版本号。
## 所有 ECS 操作均通过此对象完成，不直接操作存储层。
class_name EcsWorld
extends IEcsWorld

var _entities: Dictionary = {}  # int entity_id -> bool
var _registry: EcsComponentTypeRegistry = null
var _storage_index: EcsStorageIndex = null
var _version: int = 0
var _next_entity_id: int = 1


func _init() -> void:
	_registry = EcsComponentTypeRegistry.new()
	_storage_index = EcsStorageIndex.new()


# ============================================================
# 实体生命周期
# ============================================================


func spawn() -> int:
	var id := _next_entity_id
	_next_entity_id += 1
	_entities[id] = true
	_version += 1
	return id


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


func has_entity(p_entity: int) -> bool:
	return _entities.has(p_entity)


## 强制使用指定 ID 创建实体（供快照恢复使用，不自动分配 ID）。
func _force_spawn(p_entity: int) -> void:
	_entities[p_entity] = true
	_next_entity_id = maxi(_next_entity_id, p_entity + 1)
	_version += 1


func entity_count() -> int:
	return _entities.size()


# ============================================================
# 组件操作
# ============================================================


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


func get_version() -> int:
	return _version


## 返回所有存活实体 ID 列表。
func all_entities() -> PackedInt64Array:
	var result := PackedInt64Array()
	for id in _entities.keys():
		result.append(id)
	return result


## 重置世界（清空所有实体和组件，重置 ID 分配器）。
func reset() -> void:
	_entities.clear()
	_storage_index.clear()
	_registry = EcsComponentTypeRegistry.new()
	_storage_index = EcsStorageIndex.new()
	_next_entity_id = 1
	_version = 0


# ============================================================
# 内部（仅供 EcsQueryPlan 等框架内部使用）
# ============================================================


func _get_registry() -> EcsComponentTypeRegistry:
	return _registry


func _get_storage_index() -> EcsStorageIndex:
	return _storage_index
