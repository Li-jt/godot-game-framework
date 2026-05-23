## EcsQueryPlan — 预编译查询计划。
## 由 EcsQuery.build() 创建，缓存查询条件，减少每帧构建开销。
## 可复用：同一 plan 可多次 execute()。
class_name EcsQueryPlan
extends RefCounted

var _with_types: Array[StringName] = []
var _without_types: Array[StringName] = []
var _optional_types: Array[StringName] = []


func _init(p_with: Array[StringName], p_without: Array[StringName], p_optional: Array[StringName]) -> void:
	_with_types = p_with.duplicate()
	_without_types = p_without.duplicate()
	_optional_types = p_optional.duplicate()


## 对指定世界执行查询，返回匹配的实体和组件数据。
func execute(p_world: EcsWorld) -> EcsQueryResult:
	var registry := p_world.get_registry()
	var storage_index := p_world.get_storage_index()

	if _with_types.is_empty():
		return EcsQueryResult.new()

	# 统计每种 with 组件需要的 type_id 和 storage
	var with_type_ids: Array[int] = []
	var with_storages: Array[EcsSparseSetStorage] = []
	for with_type in _with_types:
		var tid := registry.type_id_of(with_type)
		if tid == 0:
			return EcsQueryResult.new()
		var storage := storage_index.get_storage(tid)
		if storage == null:
			return EcsQueryResult.new()
		with_type_ids.append(tid)
		with_storages.append(storage)

	# 解析 without 的 type_id
	var without_type_ids: Array[int] = []
	for without_type in _without_types:
		var tid := registry.type_id_of(without_type)
		if tid != 0:
			without_type_ids.append(tid)

	# 解析 optional 的 type_id
	var optional_type_ids: Array[int] = []
	var optional_type_names: Array[StringName] = []
	for opt_type in _optional_types:
		var tid := registry.type_id_of(opt_type)
		if tid != 0:
			optional_type_ids.append(tid)
			optional_type_names.append(opt_type)

	# 以第一个 with 组件的实体集为候选，遍历过滤
	var primary_storage: EcsSparseSetStorage = with_storages[0]
	var result := EcsQueryResult.new()
	result._required_types = _with_types
	result._optional_types = optional_type_names

	for entity in primary_storage.entities():
		if not p_world.has_entity(entity):
			continue

		# 检查所有 required
		var matches := true
		for i in range(1, with_storages.size()):
			if not with_storages[i].contains(entity):
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
		var row := EcsQueryRow.new()
		row.entity = entity
		for wtype in _with_types:
			var wstorage := storage_index.get_storage(registry.type_id_of(wtype))
			if wstorage != null:
				row._components[wtype] = wstorage.get_data(entity)
		for oname in optional_type_names:
			var ostorage := storage_index.get_storage(registry.type_id_of(oname))
			if ostorage != null and ostorage.contains(entity):
				row._components[oname] = ostorage.get_data(entity)

		result._rows.append(row)

	return result
