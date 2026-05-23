## IEcsScheduler — ECS 调度器接口。
## 定义系统注册、分组管理和 tick 驱动契约。
class_name IEcsScheduler
extends RefCounted

func register_system(p_system: EcsSystem, p_group_name: StringName, p_descriptor: EcsSystemDescriptor = null) -> OperationResult: _ni(); return OperationResult.fail(500, "NI", "IEcsScheduler")
func start() -> void: _ni()
func tick(p_delta: float) -> void: _ni()
func stop() -> void: _ni()
func is_active() -> bool: _ni(); return false

func _ni() -> void:
	push_error("IEcsScheduler: 方法未实现")
