## IEcsWorld — ECS 世界接口。
## 定义实体生命周期和组件操作的契约，便于替换存储实现与 mock 测试。
class_name IEcsWorld
extends RefCounted

func spawn() -> int: _not_implemented(); return 0
func despawn(p_entity: int) -> bool: _not_implemented(); return false
func has_entity(p_entity: int) -> bool: _not_implemented(); return false
func entity_count() -> int: _not_implemented(); return 0
func add_component(p_entity: int, p_type: StringName, p_data: Variant) -> OperationResult: _not_implemented(); return OperationResult.fail(500, "NI", "IEcsWorld")
func set_component(p_entity: int, p_type: StringName, p_data: Variant) -> OperationResult: _not_implemented(); return OperationResult.fail(500, "NI", "IEcsWorld")
func get_component(p_entity: int, p_type: StringName) -> Variant: _not_implemented(); return null
func remove_component(p_entity: int, p_type: StringName) -> void: _not_implemented()
func has_component(p_entity: int, p_type: StringName) -> bool: _not_implemented(); return false
func get_version() -> int: _not_implemented(); return 0
func all_entities() -> PackedInt64Array: _not_implemented(); return PackedInt64Array()

func _not_implemented() -> void:
	push_error("[%s] 方法未实现" % get_script().resource_path)
