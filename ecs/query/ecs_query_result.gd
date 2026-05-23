## EcsQueryResult — 查询结果集。
## 包含匹配的实体行列表，支持 for_each 迭代和批量提取。
class_name EcsQueryResult
extends RefCounted

var _rows: Array = []  # Array[EcsQueryRow]
var _required_types: Array[StringName] = []
var _optional_types: Array[StringName] = []


## 对每行结果调用回调函数。回调签名：func(row: EcsQueryRow) -> void。
func for_each(p_fn: Callable) -> void:
	for row in _rows:
		p_fn.call(row)


## 返回结果集中所有实体 ID 列表。
func entities() -> PackedInt64Array:
	var result := PackedInt64Array()
	for row in _rows:
		result.append(row.entity)
	return result


## 返回结果行数。
func count() -> int:
	return _rows.size()


## 获取指定索引处的行，越界时返回 null。
func get_row(p_index: int) -> EcsQueryPlan.EcsQueryRow:
	if p_index < 0 or p_index >= _rows.size():
		return null
	return _rows[p_index]


## 是否为空结果集。
func is_empty() -> bool:
	return _rows.is_empty()
