## GF_EcsQueryRow — 单行查询结果，包含实体 ID 和所有组件数据。
class_name GF_EcsQueryRow
extends RefCounted

var entity: int = 0
var _components: Dictionary = {}


## 获取指定类型的组件数据。p_type 为 class_name 引用（如 Position）。
func get_component(p_type: GDScript) -> Variant:
	return _components.get(p_type, null)
