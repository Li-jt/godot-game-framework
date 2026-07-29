# tests/unit/ecs/test_ecs_component_type_registry.gd
## EcsComponentTypeRegistry 单元测试。
## 组件类型注册：StringName → type_id 映射。
extends GutTest

var _registry: EcsComponentTypeRegistry


func before_each() -> void:
	_registry = EcsComponentTypeRegistry.new()


func after_each() -> void:
	_registry = null


func test_register_type_returns_consistent_id() -> void:
	var result := _registry.register_type(&"Position")
	assert_true(result.is_ok())
	var type_id: int = result.data
	assert_true(type_id > 0)


func test_register_same_type_returns_same_id() -> void:
	var r1 := _registry.register_type(&"Position")
	var r2 := _registry.register_type(&"Position")
	assert_eq(r1.data, r2.data)


func test_different_types_get_different_ids() -> void:
	var r1 := _registry.register_type(&"Position")
	var r2 := _registry.register_type(&"Velocity")
	assert_ne(r1.data, r2.data)


func test_type_id_of_returns_zero_for_unknown() -> void:
	assert_eq(_registry.type_id_of(&"Nonexistent"), 0)


func test_type_id_of_returns_correct() -> void:
	var result := _registry.register_type(&"Health")
	var type_id: int = result.data
	assert_eq(_registry.type_id_of(&"Health"), type_id)
