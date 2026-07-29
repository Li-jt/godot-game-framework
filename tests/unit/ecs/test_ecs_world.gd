# tests/unit/ecs/test_ecs_world.gd
## EcsWorld 单元测试。
## ECS 世界核心：实体生命周期、组件操作、版本管理。
extends GutTest

var _world: EcsWorld


func before_each() -> void:
	_world = EcsWorld.new()


func after_each() -> void:
	_world.reset()
	_world = null


# ============================================================
# 实体生命周期
# ============================================================

func test_spawn_returns_unique_ids() -> void:
	var id1 := _world.spawn()
	var id2 := _world.spawn()
	assert_ne(id1, id2)


func test_spawn_ids_are_increasing() -> void:
	var id1 := _world.spawn()
	var id2 := _world.spawn()
	assert_true(id2 > id1)


func test_spawn_increments_version() -> void:
	var v0 := _world.get_version()
	_world.spawn()
	assert_eq(_world.get_version(), v0 + 1)


func test_has_entity_true_after_spawn() -> void:
	var id := _world.spawn()
	assert_true(_world.has_entity(id))


func test_has_entity_false_for_random_id() -> void:
	assert_false(_world.has_entity(99999))


func test_despawn_removes_entity() -> void:
	var id := _world.spawn()
	assert_true(_world.despawn(id))
	assert_false(_world.has_entity(id))


func test_despawn_nonexistent_returns_false() -> void:
	assert_false(_world.despawn(99999))


func test_despawn_removes_components() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 0, "y": 0})
	_world.despawn(id)
	assert_false(_world.has_component(id, &"Position"))


func test_all_entities_returns_living_entities() -> void:
	var id1 := _world.spawn()
	var id2 := _world.spawn()
	var id3 := _world.spawn()
	_world.despawn(id2)

	var entities := _world.all_entities()
	assert_eq(entities.size(), 2)
	assert_true(entities.has(id1))
	assert_false(entities.has(id2))
	assert_true(entities.has(id3))


func test_entity_count_tracks_correctly() -> void:
	assert_eq(_world.entity_count(), 0)
	var id1 := _world.spawn()
	assert_eq(_world.entity_count(), 1)
	var id2 := _world.spawn()
	assert_eq(_world.entity_count(), 2)
	_world.despawn(id1)
	assert_eq(_world.entity_count(), 1)


func test_reset_clears_all() -> void:
	_world.spawn()
	_world.spawn()
	_world.add_component(1, &"Position", {"x": 0, "y": 0})
	_world.reset()

	assert_eq(_world.entity_count(), 0)
	assert_eq(_world.get_version(), 0)


# ============================================================
# 组件操作
# ============================================================

func test_add_component_stores_data() -> void:
	var id := _world.spawn()
	var result := _world.add_component(id, &"Position", {"x": 10, "y": 20})
	assert_true(result.is_ok())
	assert_eq(_world.get_component(id, &"Position"), {"x": 10, "y": 20})


func test_add_component_fails_on_nonexistent_entity() -> void:
	var result := _world.add_component(99999, &"Position", {"x": 0, "y": 0})
	assert_true(result.is_fail())
	assert_eq(result.status_code, OperationResult.ERR_NOT_FOUND)


func test_add_component_fails_on_duplicate() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 0, "y": 0})
	var result := _world.add_component(id, &"Position", {"x": 1, "y": 1})
	assert_true(result.is_fail())
	assert_eq(result.status_code, OperationResult.ERR_CONFLICT)


func test_set_component_overwrites() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 0, "y": 0})
	_world.set_component(id, &"Position", {"x": 100, "y": 200})
	assert_eq(_world.get_component(id, &"Position"), {"x": 100, "y": 200})


func test_set_component_on_new_entity_works() -> void:
	var id := _world.spawn()
	var result := _world.set_component(id, &"Position", {"x": 5, "y": 5})
	assert_true(result.is_ok())
	assert_eq(_world.get_component(id, &"Position"), {"x": 5, "y": 5})


func test_get_component_returns_null_for_nonexistent_entity() -> void:
	assert_null(_world.get_component(99999, &"Position"))


func test_get_component_returns_null_for_nonexistent_type() -> void:
	var id := _world.spawn()
	assert_null(_world.get_component(id, &"Nonexistent"))


func test_remove_component_clears() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 0, "y": 0})
	_world.remove_component(id, &"Position")
	assert_false(_world.has_component(id, &"Position"))


func test_has_component_true_after_add() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 0, "y": 0})
	assert_true(_world.has_component(id, &"Position"))


func test_has_component_false_when_entity_despawned() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 0, "y": 0})
	_world.despawn(id)
	assert_false(_world.has_component(id, &"Position"))


func test_has_component_false_before_add() -> void:
	var id := _world.spawn()
	assert_false(_world.has_component(id, &"Position"))


# ============================================================
# 版本管理
# ============================================================

func test_version_changes_on_spawn() -> void:
	var v0 := _world.get_version()
	_world.spawn()
	assert_eq(_world.get_version(), v0 + 1)


func test_version_changes_on_despawn() -> void:
	var id := _world.spawn()
	var v0 := _world.get_version()
	_world.despawn(id)
	assert_eq(_world.get_version(), v0 + 1)


func test_version_changes_on_add_component() -> void:
	var id := _world.spawn()
	var v0 := _world.get_version()
	_world.add_component(id, &"Position", {"x": 0, "y": 0})
	assert_eq(_world.get_version(), v0 + 1)


func test_version_changes_on_set_component() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 0, "y": 0})
	var v0 := _world.get_version()
	_world.set_component(id, &"Position", {"x": 1, "y": 1})
	assert_eq(_world.get_version(), v0 + 1)


func test_version_changes_on_remove_component() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 0, "y": 0})
	var v0 := _world.get_version()
	_world.remove_component(id, &"Position")
	assert_eq(_world.get_version(), v0 + 1)


func test_version_unchanged_on_read_only_ops() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 0, "y": 0})
	var v0 := _world.get_version()

	# 所有读操作不应改变 version
	_world.get_component(id, &"Position")
	_world.has_component(id, &"Position")
	_world.has_entity(id)
	_world.all_entities()
	_world.entity_count()

	assert_eq(_world.get_version(), v0)
