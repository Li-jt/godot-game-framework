## GF_IEcsQuery — ECS 查询构建器接口。
## 定义查询条件组合与构建契约。
class_name GF_IEcsQuery
extends RefCounted

func with_component(p_type: GDScript) -> GF_IEcsQuery: _ni(); return self
func without_component(p_type: GDScript) -> GF_IEcsQuery: _ni(); return self
func optional_component(p_type: GDScript) -> GF_IEcsQuery: _ni(); return self
func build() -> GF_EcsQueryPlan: _ni(); return null
func reset() -> void: _ni()

func _ni() -> void:
	push_error("GF_IEcsQuery: 方法未实现")
