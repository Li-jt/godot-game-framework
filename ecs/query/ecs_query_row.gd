## EcsQueryRow — 单行查询结果，包含实体 ID 和所有组件数据。
class_name EcsQueryRow
extends RefCounted

var entity: int = 0
var _components: Dictionary = {}


## 获取指定类型的组件数据。
func get_component(p_type: StringName) -> Variant:
	return _components.get(p_type, null)
