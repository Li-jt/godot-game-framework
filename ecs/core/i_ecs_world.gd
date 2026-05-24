## IEcsWorld — ECS 世界接口。
## 定义实体生命周期和组件操作的契约，便于替换存储实现与 mock 测试。
class_name IEcsWorld
extends RefCounted

func spawn() -> int: _ni(); return 0
func despawn(p_entity: int) -> bool: _ni(); return false
func has_entity(p_entity: int) -> bool: _ni(); return false
func entity_count() -> int: _ni(); return 0
func add_component(p_entity: int, p_type: StringName, p_data: Variant) -> OperationResult: _ni(); return OperationResult.fail(500, "NI", "IEcsWorld")
func set_component(p_entity: int, p_type: StringName, p_data: Variant) -> OperationResult: _ni(); return OperationResult.fail(500, "NI", "IEcsWorld")
func get_component(p_entity: int, p_type: StringName) -> Variant: _ni(); return null
func remove_component(p_entity: int, p_type: StringName) -> void: _ni()
func has_component(p_entity: int, p_type: StringName) -> bool: _ni(); return false
func get_version() -> int: _ni(); return 0
func all_entities() -> PackedInt64Array: _ni(); return PackedInt64Array()

func _ni() -> void:
	push_error("[%s] 方法未实现" % get_script().resource_path)
