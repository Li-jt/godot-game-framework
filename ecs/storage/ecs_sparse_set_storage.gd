## EcsSparseSetStorage — 基于 SparseSet 的组件数据存储。
## 提供 O(1) 的增删改查，并支持高效的实体遍历（entities()）。
## 第一版实现，后续可进阶 Archetype/Chunk 存储。
class_name EcsSparseSetStorage
extends RefCounted

## 稀疏映射：entity_id -> dense 数组中的索引
var _sparse: Dictionary = {}
## 稠密数据数组，与 _entities 一一对应
var _dense: Array = []
## 稠密实体 ID 数组，与 _dense 一一对应
var _entities: Array[int] = []


## 插入或更新实体的组件数据。
func insert(p_entity: int, p_data: Variant) -> void:
	if _sparse.has(p_entity):
		var idx: int = _sparse[p_entity]
		_dense[idx] = p_data
		return
	var idx := _dense.size()
	_sparse[p_entity] = idx
	_dense.append(p_data)
	_entities.append(p_entity)


## 移除实体的组件数据。实体不存在时静默忽略。
func erase(p_entity: int) -> void:
	if not _sparse.has(p_entity):
		return
	var idx: int = _sparse[p_entity]
	_sparse.erase(p_entity)
	# swap-remove：用末尾元素填充删除位置，保持 dense 紧凑
	var last_idx := _dense.size() - 1
	if idx != last_idx:
		var last_entity: int = _entities[last_idx]
		_dense[idx] = _dense[last_idx]
		_entities[idx] = last_entity
		_sparse[last_entity] = idx
	_dense.pop_back()
	_entities.pop_back()


## 检查实体是否拥有此组件。
func contains(p_entity: int) -> bool:
	return _sparse.has(p_entity)


## 获取实体的组件数据，不存在时返回 null。
func get_data(p_entity: int) -> Variant:
	var idx = _sparse.get(p_entity, -1)
	if idx == -1:
		return null
	return _dense[idx]


## 返回所有拥有此组件的实体 ID 列表。
func entities() -> PackedInt64Array:
	var result := PackedInt64Array()
	for e in _entities:
		result.append(e)
	return result


## 返回当前存储的实体数量。
func count() -> int:
	return _entities.size()


## 清空全部数据。
func clear() -> void:
	_sparse.clear()
	_dense.clear()
	_entities.clear()
