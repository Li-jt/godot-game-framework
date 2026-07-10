## IEcsCommandBuffer — ECS 命令缓冲接口。
## 定义命令收集与 apply 契约，支持不同运行时策略（Local/Remote/Hybrid）。
class_name IEcsCommandBuffer
extends RefCounted

func spawn() -> int: _ni(); return 0
func add_component(p_entity: int, p_type: StringName, p_data: Variant) -> void: _ni()
func set_component(p_entity: int, p_type: StringName, p_data: Variant) -> void: _ni()
func remove_component(p_entity: int, p_type: StringName) -> void: _ni()
func despawn(p_entity: int) -> void: _ni()
func apply_to(p_world: EcsWorld) -> OperationResult: _ni(); return OperationResult.fail(500, "NI", "IEcsCommandBuffer")
func count() -> int: _ni(); return 0
func clear() -> void: _ni()
func debug_get_commands() -> Array: _ni(); return []

func _ni() -> void:
	push_error("IEcsCommandBuffer: 方法未实现")
