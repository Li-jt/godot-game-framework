## EcsStorageIndex — 组件类型到存储实例的索引映射。
## 为 EcsQuery 提供候选实体集，按需创建存储实例。
class_name EcsStorageIndex
extends IEcsStorageIndex

var _storages: Dictionary = {}  # int type_id -> EcsSparseSetStorage


## 获取指定类型的存储实例，不存在时返回 null。
func get_storage(p_type_id: int) -> EcsSparseSetStorage:
	return _storages.get(p_type_id, null)


## 获取或创建指定类型的存储实例。
func get_or_create_storage(p_type_id: int) -> EcsSparseSetStorage:
	if _storages.has(p_type_id):
		return _storages[p_type_id]
	var storage: EcsSparseSetStorage = EcsSparseSetStorage.new()
	_storages[p_type_id] = storage
	return storage


## 移除指定类型的所有存储数据。
func remove_storage(p_type_id: int) -> void:
	_storages.erase(p_type_id)


## 检查指定类型是否已有存储。
func has_storage(p_type_id: int) -> bool:
	return _storages.has(p_type_id)


## 返回所有已分配存储的 type_id。
func all_type_ids() -> Array[int]:
	var result: Array[int] = []
	for key in _storages.keys():
		result.append(key)
	return result


## 清空全部存储。
func clear() -> void:
	_storages.clear()
