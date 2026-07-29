## GF_IEcsSystemGroup — ECS 系统分组接口。
## 定义组内系统增删与批量生命周期管理契约。
class_name GF_IEcsSystemGroup
extends RefCounted

func add_system(p_system: GF_EcsSystem, p_descriptor: GF_EcsSystemDescriptor = null) -> void: _ni()
func init_all(p_world: GF_EcsWorld) -> void: _ni()
func tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void: _ni()
func shutdown_all() -> void: _ni()
func system_count() -> int: _ni(); return 0
func is_initialized() -> bool: _ni(); return false

func _ni() -> void:
	push_error("GF_IEcsSystemGroup: 方法未实现")
