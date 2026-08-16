## GF_EcsWorld — ECS 世界核心。
## 管理实体生命周期、组件存储、ID 分配和世界版本号。
## 所有 ECS 操作均通过此对象完成，不直接操作存储层。
class_name GF_EcsWorld
extends GF_IEcsWorld

var _entities: Dictionary = {}  # int entity_id -> bool
var _registry: GF_EcsComponentTypeRegistry = null
var _storage_index: GF_EcsStorageIndex = null
var _version: int = 0
var _next_entity_id: int = 1
## 原生后端门面（NATIVE 模式下非空；SPARSE_SET/ARCHETYPE 为 null）
var _native_backend: GF_EcsNativeBackend = null
## 世界级变更日志（单帧生命周期，性能路线图 §1.4）。
## 每次 mutation 自动追加；消费方读取后调用 change_log.clear()。
## NATIVE 模式下引用原生门面组装的日志（同构 API 面）。
var change_log: GF_EcsChangeLog = null
## 世界级单例资源字典。与 Component 不同，Resource 全局只有一份，
## 通过 set_resource/get_resource 存取，不需要 Entity 访问。
## 等价于 Bevy 的 Resource<T>、守望先锋 ECS 的 singleton component。
var _resources: Dictionary = {}


## [param p_backend] GF_EcsStorageIndex.StorageBackend 枚举值。
## NATIVE 走 Flecs/GDExtension 后端（性能路线图 §1.6，需编译扩展，opt-in）；
## 缺省 SPARSE_SET（纯 GDScript，零依赖）。
func _init(p_backend: int = -1) -> void:
	_registry = GF_EcsComponentTypeRegistry.new()
	_storage_index = GF_EcsStorageIndex.new()
	change_log = GF_EcsChangeLog.new()
	if p_backend == GF_EcsStorageIndex.StorageBackend.NATIVE:
		if ClassDB.class_exists("GF_EcsNativeWorld"):
			_native_backend = GF_EcsNativeBackend.new()
			change_log = _native_backend.change_log
		else:
			# GDExtension 未编译/未加载：降级回默认 GDScript 后端（纯代码分发策略，
			# NATIVE 是 opt-in——使用方无编译链时世界照常可用）
			push_error("[GF_EcsWorld] NATIVE 后端不可用（GDExtension 未加载），"
				+ "已降级回 SPARSE_SET——见 gdextension/README.md 编译指引")


# ============================================================
# 实体生命周期
# ============================================================


func spawn() -> int:
	if _native_backend != null:
		return _native_backend.spawn()
	var id: int = _next_entity_id
	_next_entity_id += 1
	_entities[id] = true
	_version += 1
	change_log.record_added_entity(id)
	return id


func despawn(p_entity: int) -> bool:
	if _native_backend != null:
		return _native_backend.despawn(p_entity)
	if not _entities.has(p_entity):
		return false
	_entities.erase(p_entity)
	for type_id in _storage_index.all_type_ids():
		var storage: GF_IEcsStorage = _storage_index.get_storage(type_id)
		if storage != null and storage.contains(p_entity):
			storage.erase(p_entity)
	_version += 1
	change_log.record_removed_entity(p_entity)
	return true


func has_entity(p_entity: int) -> bool:
	if _native_backend != null:
		return _native_backend.has_entity(p_entity)
	return _entities.has(p_entity)


## 强制使用指定 ID 创建实体（供快照恢复使用，不自动分配 ID）。
func _force_spawn(p_entity: int) -> void:
	if _native_backend != null:
		_native_backend.force_spawn(p_entity)
		return
	_entities[p_entity] = true
	_next_entity_id = maxi(_next_entity_id, p_entity + 1)
	_version += 1
	change_log.record_added_entity(p_entity)


func entity_count() -> int:
	if _native_backend != null:
		return _native_backend.entity_count()
	return _entities.size()


## 已分配的最大实体 ID（实体 ID 单调递增不复用，增量扫描游标用）。
## 供需要「发现新实体」的消费方（如 GrowthSystem 缓存增量维护）分帧扫描
## (last_cursor, max_entity_id()] 区间，避免周期性全量 query 的规模级尖峰。
func max_entity_id() -> int:
	if _native_backend != null:
		return _native_backend.max_entity_id()
	return _next_entity_id - 1


# ============================================================
# 组件操作
# ============================================================


func add_component(p_entity: int, p_type: GDScript, p_data: Variant) -> GF_OperationResult:
	if _native_backend != null:
		var native_result: GF_OperationResult = _native_add_component(p_entity, p_type, p_data)
		if native_result.is_fail():
			return native_result
		return GF_OperationResult.ok()
	if not _entities.has(p_entity):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "实体不存在: %d" % p_entity, "GF_EcsWorld")
	var reg_result: GF_OperationResult = _registry.register_type(p_type)
	if reg_result.is_fail():
		return reg_result
	var type_id: int = reg_result.data
	var storage := _storage_index.get_or_create_storage(type_id)
	if storage.contains(p_entity):
		return GF_OperationResult.fail(GF_OperationResult.ERR_CONFLICT, "实体 %d 已拥有组件 %s" % [p_entity, _registry._type_name(p_type)], "GF_EcsWorld")
	storage.insert(p_entity, p_data)
	_version += 1
	change_log.record_component_change(p_entity, type_id, GF_EcsChangeLog.ChangeKind.COMPONENT_ADDED, p_data)
	return GF_OperationResult.ok()


func set_component(p_entity: int, p_type: GDScript, p_data: Variant) -> GF_OperationResult:
	if _native_backend != null:
		return _native_set_component(p_entity, p_type, p_data)
	if not _entities.has(p_entity):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "实体不存在: %d" % p_entity, "GF_EcsWorld")
	var reg_result: GF_OperationResult = _registry.register_type(p_type)
	if reg_result.is_fail():
		return reg_result
	var type_id: int = reg_result.data
	var storage := _storage_index.get_or_create_storage(type_id)
	storage.insert(p_entity, p_data)
	_version += 1
	change_log.record_component_change(p_entity, type_id, GF_EcsChangeLog.ChangeKind.COMPONENT_CHANGED, p_data)
	return GF_OperationResult.ok()


func get_component(p_entity: int, p_type: GDScript) -> Variant:
	if _native_backend != null:
		return _native_get_component(p_entity, p_type)
	if not _entities.has(p_entity):
		return null
	var type_id: int = _registry.type_id_of(p_type)
	if type_id == 0:
		return null
	var storage := _storage_index.get_storage(type_id)
	if storage == null:
		return null
	return storage.get_data(p_entity)


func remove_component(p_entity: int, p_type: GDScript) -> void:
	if _native_backend != null:
		_native_remove_component(p_entity, p_type)
		return
	if not _entities.has(p_entity):
		return
	var type_id: int = _registry.type_id_of(p_type)
	if type_id == 0:
		return
	var storage := _storage_index.get_storage(type_id)
	if storage == null:
		return
	if not storage.contains(p_entity):
		return  # 无此组件：静默返回，不递增版本、不记变更日志
	storage.erase(p_entity)
	_version += 1
	change_log.record_component_change(p_entity, type_id, GF_EcsChangeLog.ChangeKind.COMPONENT_REMOVED)


func has_component(p_entity: int, p_type: GDScript) -> bool:
	if _native_backend != null:
		return _native_has_component(p_entity, p_type)
	if not _entities.has(p_entity):
		return false
	var type_id: int = _registry.type_id_of(p_type)
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
	if _native_backend != null:
		return _native_backend.get_version()
	return _version


## 设置世界级单例资源。与 Component 不同，Resource 全局只有一份，不需要通过 Entity 访问。
## [param p_key] 使用 class_name 引用作为键，如 [code]set_resource(GF_ContentDefRegistry, data)[/code]。
func set_resource(p_key: Variant, p_data: Variant) -> void:
	_resources[p_key] = p_data


## 获取世界级单例资源。返回 null 表示未注册。
## [param p_key] 使用 class_name 引用作为键，如 [code]get_resource(GF_ContentDefRegistry)[/code]。
func get_resource(p_key: Variant) -> Variant:
	return _resources.get(p_key, null)


## 是否已注册指定资源。
## [param p_key] 使用 class_name 引用作为键，如 [code]has_resource(GF_ContentDefRegistry)[/code]。
func has_resource(p_key: Variant) -> bool:
	return _resources.has(p_key)


## 返回所有存活实体 ID 列表。
func all_entities() -> PackedInt64Array:
	if _native_backend != null:
		return _native_backend.all_entities()
	var result := PackedInt64Array()
	for id in _entities.keys():
		result.append(id)
	return result


## 重置世界（清空所有实体和组件，重置 ID 分配器）。
func reset() -> void:
	if _native_backend != null:
		_native_backend.reset()
		_registry = GF_EcsComponentTypeRegistry.new()
		_storage_index = GF_EcsStorageIndex.new()
		_resources.clear()
		return
	_entities.clear()
	_storage_index.clear()
	_registry = GF_EcsComponentTypeRegistry.new()
	_storage_index = GF_EcsStorageIndex.new()
	_next_entity_id = 1
	_version = 0
	_resources.clear()
	change_log.clear()


# ============================================================
# 内部（仅供 GF_EcsQueryPlan 等框架内部使用）
# ============================================================


func _get_registry() -> GF_EcsComponentTypeRegistry:
	return _registry


func _get_storage_index() -> GF_EcsStorageIndex:
	return _storage_index


## 原生后端门面访问器（GF_EcsQueryPlan 原生分支用；null = 非原生模式）。
func _get_native_backend() -> GF_EcsNativeBackend:
	return _native_backend


# ============================================================
# 原生后端 helper（NATIVE 模式下经 registry 解析 type_key 后委托门面）
# ============================================================


func _native_add_component(p_entity: int, p_type: GDScript, p_data: Variant) -> GF_OperationResult:
	var reg_result: GF_OperationResult = _registry.register_type(p_type)
	if reg_result.is_fail():
		return reg_result
	var type_key: int = reg_result.data
	if not _native_backend.has_entity(p_entity):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "实体不存在: %d" % p_entity, "GF_EcsWorld")
	if not _native_backend.add_component(p_entity, type_key, p_data):
		return GF_OperationResult.fail(GF_OperationResult.ERR_CONFLICT, "实体 %d 已拥有组件 %s" % [p_entity, _registry._type_name(p_type)], "GF_EcsWorld")
	return GF_OperationResult.ok()


func _native_set_component(p_entity: int, p_type: GDScript, p_data: Variant) -> GF_OperationResult:
	var reg_result: GF_OperationResult = _registry.register_type(p_type)
	if reg_result.is_fail():
		return reg_result
	var type_key: int = reg_result.data
	if not _native_backend.set_component(p_entity, type_key, p_data):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "实体不存在: %d" % p_entity, "GF_EcsWorld")
	return GF_OperationResult.ok()


func _native_get_component(p_entity: int, p_type: GDScript) -> Variant:
	var type_key: int = _registry.type_id_of(p_type)
	if type_key == 0:
		return null
	return _native_backend.get_component(p_entity, type_key)


func _native_remove_component(p_entity: int, p_type: GDScript) -> void:
	var type_key: int = _registry.type_id_of(p_type)
	if type_key == 0:
		return
	_native_backend.remove_component(p_entity, type_key)


func _native_has_component(p_entity: int, p_type: GDScript) -> bool:
	var type_key: int = _registry.type_id_of(p_type)
	if type_key == 0:
		return false
	return _native_backend.has_component(p_entity, type_key)
