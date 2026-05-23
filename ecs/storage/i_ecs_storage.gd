## IEcsStorage — ECS 组件存储接口。
## 定义组件数据的 CRUD 和实体遍历契约，SparseSet/Archetype 均需实现。
class_name IEcsStorage
extends RefCounted

func insert(p_entity: int, p_data: Variant) -> void: _ni()
func erase(p_entity: int) -> void: _ni()
func contains(p_entity: int) -> bool: _ni(); return false
func get_data(p_entity: int) -> Variant: _ni(); return null
func entities() -> PackedInt64Array: _ni(); return PackedInt64Array()
func count() -> int: _ni(); return 0
func clear() -> void: _ni()

func _ni() -> void:
	push_error("IEcsStorage: 方法未实现")
