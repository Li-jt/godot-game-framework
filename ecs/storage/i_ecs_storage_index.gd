## IEcsStorageIndex — ECS 存储索引接口。
## 定义组件类型到存储实例的映射契约。
class_name IEcsStorageIndex
extends RefCounted

func get_storage(p_type_id: int) -> IEcsStorage: _ni(); return null
func get_or_create_storage(p_type_id: int) -> IEcsStorage: _ni(); return null
func remove_storage(p_type_id: int) -> void: _ni()
func has_storage(p_type_id: int) -> bool: _ni(); return false
func all_type_ids() -> Array[int]: _ni(); return []
func clear() -> void: _ni()

func _ni() -> void:
	push_error("IEcsStorageIndex: 方法未实现")
