## GF_EcsQueryPlan — 预编译查询计划。
## 由 GF_EcsQuery.build() 创建，缓存查询条件，减少每帧构建开销。
## 可复用：同一 plan 可多次 execute()。
class_name GF_EcsQueryPlan
extends RefCounted

var _with_types: Array = []
var _without_types: Array = []
var _optional_types: Array = []


func _init(p_with: Array, p_without: Array, p_optional: Array) -> void:
	_with_types = p_with.duplicate()
	_without_types = p_without.duplicate()
	_optional_types = p_optional.duplicate()


## 轻量查询：只返回匹配实体的 ID 列表，不构建 row/组件数据。
## 供只需实体 ID 的高频消费方使用（如系统缓存重建——数千实体时
## execute() 的每行 row 对象与组件字典分配是明显的周期性 GC 尖峰）。
func execute_entities(p_world: GF_EcsWorld) -> PackedInt64Array:
	var registry := p_world._get_registry()
	var storage_index := p_world._get_storage_index()

	# 预解析 with/without 的 type_id 与存储引用——每实体循环内零字典查找
	# （type_id_of/get_storage 从「每实体×每类型」降为「每类型一次」）
	var with_storages: Array[GF_IEcsStorage] = []
	for with_type in _with_types:
		var tid := registry.type_id_of(with_type)
		if tid == 0:
			return PackedInt64Array()
		var storage := storage_index.get_storage(tid)
		if storage == null:
			return PackedInt64Array()
		with_storages.append(storage)

	var without_storages: Array[GF_IEcsStorage] = []
	for without_type in _without_types:
		var tid := registry.type_id_of(without_type)
		if tid != 0:
			var storage := storage_index.get_storage(tid)
			if storage != null:
				without_storages.append(storage)

	var candidates: PackedInt64Array
	if with_storages.is_empty():
		candidates = p_world.all_entities()
	else:
		candidates = with_storages[0].entities()

	var result := PackedInt64Array()
	for entity in candidates:
		if not p_world.has_entity(entity):
			continue

		var matches := true
		for storage in with_storages:
			if not storage.contains(entity):
				matches = false
				break
		if not matches:
			continue

		var excluded := false
		for storage in without_storages:
			if storage.contains(entity):
				excluded = true
				break
		if excluded:
			continue

		result.append(entity)
	return result


## 对指定世界执行查询，返回匹配的实体和组件数据。
func execute(p_world: GF_EcsWorld) -> GF_EcsQueryResult:
	var registry := p_world._get_registry()
	var storage_index := p_world._get_storage_index()

	# P2-2: 无 with 条件时，候选集为全部存活实体
	var candidates: PackedInt64Array
	if _with_types.is_empty():
		candidates = p_world.all_entities()
	else:
		var with_storages: Array[GF_IEcsStorage] = []
		for with_type in _with_types:
			var tid := registry.type_id_of(with_type)
			if tid == 0:
				return GF_EcsQueryResult.new()
			var storage := storage_index.get_storage(tid)
			if storage == null:
				return GF_EcsQueryResult.new()
			with_storages.append(storage)
		candidates = with_storages[0].entities()

	# 解析 without 的 type_id
	var without_type_ids: Array[int] = []
	for without_type in _without_types:
		var tid := registry.type_id_of(without_type)
		if tid != 0:
			without_type_ids.append(tid)

	# 解析 optional 的 type_id
	var optional_types: Array = []
	for opt_type in _optional_types:
		if registry.type_id_of(opt_type) != 0:
			optional_types.append(opt_type)

	var result := GF_EcsQueryResult.new()
	result._required_types = _with_types
	result._optional_types = optional_types

	for entity in candidates:
		if not p_world.has_entity(entity):
			continue

		# 检查所有 required（_with_types 非空时）
		if not _with_types.is_empty():
			var matches := true
			for with_type in _with_types:
				var s := storage_index.get_storage(registry.type_id_of(with_type))
				if s == null or not s.contains(entity):
					matches = false
					break
			if not matches:
				continue

		# 检查 without
		var excluded := false
		for tid in without_type_ids:
			var s := storage_index.get_storage(tid)
			if s != null and s.contains(entity):
				excluded = true
				break
		if excluded:
			continue

		# 收集组件数据
		var row := GF_EcsQueryRow.new()
		row.entity = entity
		for wtype in _with_types:
			var wstorage := storage_index.get_storage(registry.type_id_of(wtype))
			if wstorage != null:
				row._components[wtype] = wstorage.get_data(entity)
		for oname in optional_types:
			var ostorage := storage_index.get_storage(registry.type_id_of(oname))
			if ostorage != null and ostorage.contains(entity):
				row._components[oname] = ostorage.get_data(entity)

		result._rows.append(row)

	return result
