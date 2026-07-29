## GF_EcsArchetypeStorage — 基于 Archetype 模式的高性能组件存储。
## 将相同组件组合的实体分组存储在同一 Archetype 中，
## 组件数据按行对齐，支持批量遍历优化。
## 通过 GF_IEcsStorage 接口与 SparseSet 可互换。
class_name GF_EcsArchetypeStorage
extends GF_IEcsStorage

# ============================================================
# _ArchetypeManager — 共享的全局 Archetype 管理器
# ============================================================

class _ArchetypeManager:
	var _archetypes: Array[Dictionary] = []
	# entity_id → {archetype_idx: int, row: int}
	var _entity_map: Dictionary = {}

	## 查找包含指定 type_ids 组合的 archetype，不存在返回 -1。
	func _find_archetype(p_type_ids: PackedInt64Array) -> int:
		for i in _archetypes.size():
			if _archetypes[i]["type_ids"] == p_type_ids:
				return i
		return -1

	## 创建新 archetype，返回索引。
	func _create_archetype(p_type_ids: PackedInt64Array) -> int:
		var columns: Array[Array] = []
		for _t in p_type_ids:
			columns.append([])
		var arch := {
			"type_ids": p_type_ids,
			"entities": [] as Array[int],
			"columns": columns,
		}
		_archetypes.append(arch)
		return _archetypes.size() - 1

	## 获取或创建包含指定 type_ids 的 archetype。
	func _get_or_create_archetype(p_type_ids: PackedInt64Array) -> int:
		var idx := _find_archetype(p_type_ids)
		if idx != -1:
			return idx
		return _create_archetype(p_type_ids)

	## 在 archetype 中查找 type_id 对应的列索引。
	func _column_index(p_arch_idx: int, p_type_id: int) -> int:
		return _archetypes[p_arch_idx]["type_ids"].find(p_type_id)

	## 从 archetype 中移除 entity（swap-remove，保持紧凑）。
	func _remove_from_archetype(p_arch_idx: int, p_entity: int, p_row: int) -> void:
		var arch: Dictionary = _archetypes[p_arch_idx]
		var last_row: int = arch["entities"].size() - 1
		if p_row != last_row:
			var last_entity: int = arch["entities"][last_row]
			arch["entities"][p_row] = last_entity
			for col in arch["columns"].size():
				arch["columns"][col][p_row] = arch["columns"][col][last_row]
			_entity_map[last_entity] = {"archetype_idx": p_arch_idx, "row": p_row}
		arch["entities"].pop_back()
		for col in arch["columns"].size():
			arch["columns"][col].pop_back()
		_entity_map.erase(p_entity)

	## 从旧 archetype 收集实体的所有组件数据。
	func _collect_entity_data(p_entity: int, p_arch_idx: int, p_row: int) -> Dictionary:
		var arch: Dictionary = _archetypes[p_arch_idx]
		var data: Dictionary = {}
		for i in arch["type_ids"].size():
			data[arch["type_ids"][i]] = arch["columns"][i][p_row]
		return data

	## 向 archetype 追加 entity 和组件数据。
	func _append_to_archetype(p_arch_idx: int, p_entity: int, p_data: Dictionary) -> int:
		var arch: Dictionary = _archetypes[p_arch_idx]
		var row: int = arch["entities"].size()
		arch["entities"].append(p_entity)
		for i in arch["type_ids"].size():
			var tid: int = arch["type_ids"][i]
			var d = p_data.get(tid, null)
			arch["columns"][i].append(d)
		_entity_map[p_entity] = {"archetype_idx": p_arch_idx, "row": row}
		return row

	## 插入或更新实体的组件数据。
	func insert_component(p_type_id: int, p_entity: int, p_data: Variant) -> void:
		if _entity_map.has(p_entity):
			var info: Dictionary = _entity_map[p_entity]
			var old_arch: Dictionary = _archetypes[info["archetype_idx"]]
			var old_type_ids: PackedInt64Array = old_arch["type_ids"]

			# 如果 archetype 已包含此 type，直接更新
			if old_type_ids.has(p_type_id):
				var col: int = _column_index(info["archetype_idx"], p_type_id)
				old_arch["columns"][col][info["row"]] = p_data
				return

			# 需要迁移到新 archetype
			var new_type_ids := _make_sorted_type_ids(old_type_ids, p_type_id)
			var new_arch_idx := _get_or_create_archetype(new_type_ids)
			var existing_data := _collect_entity_data(p_entity, info["archetype_idx"], info["row"])
			existing_data[p_type_id] = p_data
			_remove_from_archetype(info["archetype_idx"], p_entity, info["row"])
			_append_to_archetype(new_arch_idx, p_entity, existing_data)
			return

		# 新实体：放入只有这一个 type 的 archetype
		var type_ids := PackedInt64Array([p_type_id])
		var arch_idx := _get_or_create_archetype(type_ids)
		_append_to_archetype(arch_idx, p_entity, {p_type_id: p_data})

	## 移除实体的某个组件。
	func erase_component(p_type_id: int, p_entity: int) -> void:
		if not _entity_map.has(p_entity):
			return
		var info: Dictionary = _entity_map[p_entity]
		var old_arch: Dictionary = _archetypes[info["archetype_idx"]]
		var old_type_ids: PackedInt64Array = old_arch["type_ids"]

		if not old_type_ids.has(p_type_id):
			return

		if old_type_ids.size() == 1:
			# 只剩下这一个组件 → 移除实体
			_remove_from_archetype(info["archetype_idx"], p_entity, info["row"])
			return

		# 迁移到不含此 type 的新 archetype
		var new_type_ids := _remove_type_from_sorted(old_type_ids, p_type_id)
		var new_arch_idx := _get_or_create_archetype(new_type_ids)
		var existing_data := _collect_entity_data(p_entity, info["archetype_idx"], info["row"])
		existing_data.erase(p_type_id)
		_remove_from_archetype(info["archetype_idx"], p_entity, info["row"])
		_append_to_archetype(new_arch_idx, p_entity, existing_data)

	## 检查实体是否拥有某组件。
	func has_component(p_type_id: int, p_entity: int) -> bool:
		if not _entity_map.has(p_entity):
			return false
		var info: Dictionary = _entity_map[p_entity]
		return _archetypes[info["archetype_idx"]]["type_ids"].has(p_type_id)

	## 获取实体组件数据。
	func get_component(p_type_id: int, p_entity: int):
		if not _entity_map.has(p_entity):
			return null
		var info: Dictionary = _entity_map[p_entity]
		var arch: Dictionary = _archetypes[info["archetype_idx"]]
		var col: int = _column_index(info["archetype_idx"], p_type_id)
		if col == -1:
			return null
		return arch["columns"][col][info["row"]]

	## 获取所有包含指定类型的实体。
	func get_entities_with_type(p_type_id: int) -> PackedInt64Array:
		var result := PackedInt64Array()
		for arch in _archetypes:
			if arch["type_ids"].has(p_type_id):
				for e in arch["entities"]:
					result.append(e)
		return result

	## 统计包含指定类型的实体数。
	func count_entities_with_type(p_type_id: int) -> int:
		var total := 0
		for arch in _archetypes:
			if arch["type_ids"].has(p_type_id):
				total += arch["entities"].size()
		return total

	## 清除指定类型的所有数据（从所有 archetype 中移除该类型列）。
	func clear_type(p_type_id: int) -> void:
		var affected_archs: Array[int] = []
		for i in _archetypes.size():
			if _archetypes[i]["type_ids"].has(p_type_id):
				affected_archs.append(i)

		for arch_idx in affected_archs:
			var arch: Dictionary = _archetypes[arch_idx]
			if arch["type_ids"].size() == 1:
				# 只有这一个类型 → 实体全部移除
				for e in arch["entities"]:
					_entity_map.erase(e)
				arch["entities"].clear()
				for c in arch["columns"].size():
					arch["columns"][c].clear()
			else:
				# 迁移所有实体到不含此类型的新 archetype
				var new_type_ids := _remove_type_from_sorted(arch["type_ids"], p_type_id)
				var new_arch_idx := _get_or_create_archetype(new_type_ids)
				var entities_copy: Array[int] = arch["entities"].duplicate()
				for e in entities_copy:
					var existing_data := _collect_entity_data(e, arch_idx, _entity_map[e]["row"])
					existing_data.erase(p_type_id)
					_remove_from_archetype(arch_idx, e, _entity_map[e]["row"])
					_append_to_archetype(new_arch_idx, e, existing_data)

	## 清空所有数据。
	func clear_all() -> void:
		_archetypes.clear()
		_entity_map.clear()

	func _make_sorted_type_ids(p_existing: PackedInt64Array, p_new_type: int) -> PackedInt64Array:
		var result := PackedInt64Array()
		var inserted := false
		for tid in p_existing:
			if not inserted and p_new_type < tid:
				result.append(p_new_type)
				inserted = true
			result.append(tid)
		if not inserted:
			result.append(p_new_type)
		return result

	func _remove_type_from_sorted(p_type_ids: PackedInt64Array, p_remove: int) -> PackedInt64Array:
		var result := PackedInt64Array()
		for tid in p_type_ids:
			if tid != p_remove:
				result.append(tid)
		return result


# ============================================================
# GF_EcsArchetypeStorage — 公有接口
# ============================================================

## 所有 GF_EcsArchetypeStorage 实例共享的全局 manager。
## GDScript 中 Godot 进程只有一个 ECS World，因此静态共享是安全的。
static var _manager: _ArchetypeManager = null

var _type_id: int = 0


func _init(p_type_id: int) -> void:
	_type_id = p_type_id
	if _manager == null:
		_manager = _ArchetypeManager.new()


func insert(p_entity: int, p_data: Variant) -> void:
	_manager.insert_component(_type_id, p_entity, p_data)


func erase(p_entity: int) -> void:
	_manager.erase_component(_type_id, p_entity)


func contains(p_entity: int) -> bool:
	return _manager.has_component(_type_id, p_entity)


func get_data(p_entity: int) -> Variant:
	return _manager.get_component(_type_id, p_entity)


func entities() -> PackedInt64Array:
	return _manager.get_entities_with_type(_type_id)


func count() -> int:
	return _manager.count_entities_with_type(_type_id)


func clear() -> void:
	_manager.clear_type(_type_id)


## 返回存储后端名称。
func get_backend_name() -> String:
	return "Archetype"
