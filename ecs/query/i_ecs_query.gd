## IEcsQuery — ECS 查询构建器接口。
## 定义查询条件组合与构建契约。
class_name IEcsQuery
extends RefCounted

func with_component(p_type: StringName) -> IEcsQuery: _ni(); return self
func without_component(p_type: StringName) -> IEcsQuery: _ni(); return self
func optional_component(p_type: StringName) -> IEcsQuery: _ni(); return self
func build() -> EcsQueryPlan: _ni(); return null
func reset() -> void: _ni()

func _ni() -> void:
	push_error("IEcsQuery: 方法未实现")
