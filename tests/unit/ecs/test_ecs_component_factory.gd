# tests/unit/ecs/test_ecs_component_factory.gd
## GF_EcsComponentFactory 单元测试。
## 组件工厂注册表：register/create/has/clear 及存档集成。
extends GutTest

const FACTORY_PATH := "res://ecs/save/ecs_component_factory.gd"

var _world: GF_EcsWorld
var _adapter: GF_EcsSaveAdapter
var _factory


func _new_factory():
	return load(FACTORY_PATH).new()


func before_each() -> void:
	_world = GF_EcsWorld.new()
	_adapter = GF_EcsSaveAdapter.new(1)
	_factory = _new_factory()


func after_each() -> void:
	_world.reset()
	_world = null
	_adapter = null
	_factory = null


# ============================================================
# 基础注册表操作
# ============================================================

func test_register_and_create() -> void:
	_factory.register(&"Health", func(p_data: Dictionary):
		return {"hp": p_data.hp, "max_hp": p_data.max_hp, "_reconstructed": true}
	)

	var result = _factory.create(&"Health", {"hp": 80, "max_hp": 100})
	assert_eq(result._reconstructed, true)
	assert_eq(result.hp, 80)
	assert_eq(result.max_hp, 100)


func test_create_returns_raw_data_when_no_factory() -> void:
	var data := {"x": 10, "y": 20}
	var result = _factory.create(&"Position", data)
	assert_eq(result, data)


func test_has_factory() -> void:
	assert_false(_factory.has_factory(&"Health"))
	_factory.register(&"Health", func(d): return d)
	assert_true(_factory.has_factory(&"Health"))


func test_unregister_removes_factory() -> void:
	_factory.register(&"Health", func(d): return d)
	_factory.unregister(&"Health")
	assert_false(_factory.has_factory(&"Health"))


func test_clear_removes_all() -> void:
	_factory.register(&"A", func(d): return d)
	_factory.register(&"B", func(d): return d)
	_factory.clear()
	assert_false(_factory.has_factory(&"A"))
	assert_false(_factory.has_factory(&"B"))


func test_registered_types_returns_all() -> void:
	_factory.register(&"A", func(d): return d)
	_factory.register(&"B", func(d): return d)
	assert_eq(_factory.registered_types().size(), 2)


# ============================================================
# 存档集成：factory 重建组件实例
# ============================================================

func test_save_load_with_factory_reconstructs_component() -> void:
	_factory.register(&"Health", func(p_data: Dictionary):
		return {"hp": p_data.hp, "max": p_data.max, "tag": "rebuilt"}
	)
	_adapter.component_factory = _factory

	var entity := _world.spawn()
	_world.add_component(entity, &"Health", {"hp": 50, "max": 100})
	var save_data := _adapter.save(_world)

	_world.reset()
	_adapter.load(_world, save_data)

	var restored = _world.get_component(entity, &"Health")
	assert_eq(restored.hp, 50)
	assert_eq(restored.max, 100)
	assert_eq(restored.tag, "rebuilt")


func test_save_load_without_factory_uses_raw_data() -> void:
	_adapter.component_factory = null

	var entity := _world.spawn()
	_world.add_component(entity, &"Position", {"x": 10, "y": 20})
	var save_data := _adapter.save(_world)

	_world.reset()
	var result := _adapter.load(_world, save_data)
	assert_true(result.is_ok())
	assert_eq(_world.get_component(entity, &"Position"), {"x": 10, "y": 20})


func test_mixed_factory_registered_and_unregistered_types() -> void:
	_factory.register(&"Health", func(p_data: Dictionary):
		return {"hp": p_data.hp, "_via_factory": true}
	)
	_adapter.component_factory = _factory

	var entity := _world.spawn()
	_world.add_component(entity, &"Health", {"hp": 75})
	_world.add_component(entity, &"Position", {"x": 5, "y": 5})
	var save_data := _adapter.save(_world)

	_world.reset()
	_adapter.load(_world, save_data)

	var health = _world.get_component(entity, &"Health")
	assert_true(health._via_factory)
	assert_eq(health.hp, 75)

	var pos = _world.get_component(entity, &"Position")
	assert_eq(pos, {"x": 5, "y": 5})


func test_multiple_entities_with_factory() -> void:
	_factory.register(&"Item", func(p_data: Dictionary):
		return {"name": p_data.name, "qty": p_data.qty, "rebuilt": true}
	)
	_adapter.component_factory = _factory

	for i in 10:
		var e := _world.spawn()
		_world.add_component(e, &"Item", {"name": "Item_%d" % i, "qty": i})

	var save_data := _adapter.save(_world)
	_world.reset()
	_adapter.load(_world, save_data)

	assert_eq(_world.entity_count(), 10)
	for i in 10:
		var e := i + 1
		var item = _world.get_component(e, &"Item")
		assert_true(item.rebuilt)
		assert_eq(item.name, "Item_%d" % i)


# ============================================================
# 边界条件
# ============================================================

func test_factory_returns_null_uses_null() -> void:
	_factory.register(&"Optional", func(_d: Dictionary):
		return null
	)
	_adapter.component_factory = _factory

	var entity := _world.spawn()
	_world.add_component(entity, &"Optional", {"key": "val"})
	var save_data := _adapter.save(_world)

	_world.reset()
	_adapter.load(_world, save_data)

	assert_null(_world.get_component(entity, &"Optional"))


func test_empty_factory_no_effect() -> void:
	_adapter.component_factory = _factory

	var entity := _world.spawn()
	_world.add_component(entity, &"Data", {"a": 1})
	var save_data := _adapter.save(_world)

	_world.reset()
	var result := _adapter.load(_world, save_data)
	assert_true(result.is_ok())
	assert_eq(_world.get_component(entity, &"Data"), {"a": 1})
