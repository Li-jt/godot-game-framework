# tests/unit/ecs/test_ecs_save_adapter.gd
## GF_EcsSaveAdapter 单元测试。
## ECS 存档适配器：save/load 往返、版本迁移。
extends GutTest

var _world: GF_EcsWorld
var _adapter: GF_EcsSaveAdapter


func before_each() -> void:
	_world = GF_EcsWorld.new()
	_adapter = GF_EcsSaveAdapter.new(1)


func after_each() -> void:
	_world.reset()
	_world = null
	_adapter = null


func test_save_returns_dictionary_with_version_and_snapshot() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 10, "y": 20})

	var save_data := _adapter.save(_world)
	assert_not_null(save_data)
	assert_eq(save_data.save_version, 1)
	assert_not_null(save_data.snapshot)


func test_load_restores_entities() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 1, "y": 2})

	var save_data := _adapter.save(_world)
	_world.reset()

	var result := _adapter.load(_world, save_data)
	assert_true(result.is_ok())
	assert_eq(_world.entity_count(), 1)


func test_roundtrip_preserves_component_data() -> void:
	var id := _world.spawn()
	var data := {"x": 42, "y": 99}
	_world.add_component(id, &"Position", data)

	var save_data := _adapter.save(_world)
	_world.reset()

	_adapter.load(_world, save_data)
	assert_eq(_world.get_component(id, &"Position"), data)


func test_set_and_get_save_version() -> void:
	_adapter.set_save_version(5)
	assert_eq(_adapter.get_save_version(), 5)
	assert_eq(_adapter.get_current_save_version(), 5)


func test_register_migration_and_load_old_version() -> void:
	_adapter.set_save_version(2)

	# 迁移函数：v1 → v2
	var migrated := false
	_adapter.register_migration(1, 2, func(p_data: Dictionary) -> Dictionary:
		migrated = true
		p_data["migrated"] = true
		return p_data
	)

	# 手动构造 v1 存档
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 1, "y": 1})
	var save_data := _adapter.save(_world)
	save_data.save_version = 1

	_world.reset()
	var result := _adapter.load(_world, save_data)
	assert_true(result.is_ok())


func test_unregister_migrations_by_owner() -> void:
	_adapter.set_save_version(3)
	_adapter.register_migration(1, 2, func(d): return d, "mod:test")
	_adapter.register_migration(2, 3, func(d): return d, "mod:test")

	var removed := _adapter.unregister_migrations_by_owner("mod:test")
	assert_true(removed >= 0)
