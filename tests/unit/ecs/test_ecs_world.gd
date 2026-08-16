# tests/unit/ecs/test_ecs_world.gd
## GF_EcsWorld 单元测试。
## ECS 世界核心：实体生命周期、组件操作、版本管理。
extends GutTest

var _world: GF_EcsWorld


func before_each() -> void:
	_world = GF_EcsWorld.new()


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
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.despawn(id)
	assert_false(_world.has_component(id, FakeCompPosition))


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
	_world.add_component(1, FakeCompPosition, {"x": 0, "y": 0})
	_world.reset()

	assert_eq(_world.entity_count(), 0)
	assert_eq(_world.get_version(), 0)


# ============================================================
# 组件操作
# ============================================================

func test_add_component_stores_data() -> void:
	var id := _world.spawn()
	var result := _world.add_component(id, FakeCompPosition, {"x": 10, "y": 20})
	assert_true(result.is_ok())
	assert_eq(_world.get_component(id, FakeCompPosition), {"x": 10, "y": 20})


func test_add_component_fails_on_nonexistent_entity() -> void:
	var result := _world.add_component(99999, FakeCompPosition, {"x": 0, "y": 0})
	assert_true(result.is_fail())
	assert_eq(result.status_code, GF_OperationResult.ERR_NOT_FOUND)


func test_add_component_fails_on_duplicate() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	var result := _world.add_component(id, FakeCompPosition, {"x": 1, "y": 1})
	assert_true(result.is_fail())
	assert_eq(result.status_code, GF_OperationResult.ERR_CONFLICT)


func test_set_component_overwrites() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.set_component(id, FakeCompPosition, {"x": 100, "y": 200})
	assert_eq(_world.get_component(id, FakeCompPosition), {"x": 100, "y": 200})


func test_set_component_on_new_entity_works() -> void:
	var id := _world.spawn()
	var result := _world.set_component(id, FakeCompPosition, {"x": 5, "y": 5})
	assert_true(result.is_ok())
	assert_eq(_world.get_component(id, FakeCompPosition), {"x": 5, "y": 5})


func test_get_component_returns_null_for_nonexistent_entity() -> void:
	assert_null(_world.get_component(99999, FakeCompPosition))


func test_get_component_returns_null_for_nonexistent_type() -> void:
	var id := _world.spawn()
	assert_null(_world.get_component(id, FakeCompNonexistent))


func test_remove_component_clears() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.remove_component(id, FakeCompPosition)
	assert_false(_world.has_component(id, FakeCompPosition))


func test_remove_component_nonexistent_is_silent_no_version_change() -> void:
	# 探针对拍发现：对「实体没有该组件」的 remove 应静默——
	# 不递增 version、不记变更日志（与原生后端语义对齐）
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.remove_component(id, FakeCompPosition)
	_world.change_log.clear()
	var v0 := _world.get_version()
	_world.remove_component(id, FakeCompPosition)  # 已移除，第二次 remove
	assert_eq(_world.get_version(), v0, "remove 不存在组件不应递增版本")
	assert_false(_world.change_log.has_changes(), "remove 不存在组件不应记变更日志")


func test_has_component_true_after_add() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	assert_true(_world.has_component(id, FakeCompPosition))


func test_has_component_false_when_entity_despawned() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.despawn(id)
	assert_false(_world.has_component(id, FakeCompPosition))


func test_has_component_false_before_add() -> void:
	var id := _world.spawn()
	assert_false(_world.has_component(id, FakeCompPosition))


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
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	assert_eq(_world.get_version(), v0 + 1)


func test_version_changes_on_set_component() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	var v0 := _world.get_version()
	_world.set_component(id, FakeCompPosition, {"x": 1, "y": 1})
	assert_eq(_world.get_version(), v0 + 1)


func test_version_changes_on_remove_component() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	var v0 := _world.get_version()
	_world.remove_component(id, FakeCompPosition)
	assert_eq(_world.get_version(), v0 + 1)


func test_version_unchanged_on_read_only_ops() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	var v0 := _world.get_version()

	# 所有读操作不应改变 version
	_world.get_component(id, FakeCompPosition)
	_world.has_component(id, FakeCompPosition)
	_world.has_entity(id)
	_world.all_entities()
	_world.entity_count()

	assert_eq(_world.get_version(), v0)


# ============================================================
# max_entity_id（性能路线图 §1.1 分帧增量扫描游标）
# ============================================================

func test_max_entity_id_zero_when_empty() -> void:
	assert_eq(_world.max_entity_id(), 0)


func test_max_entity_id_increases_on_spawn() -> void:
	var id := _world.spawn()
	assert_eq(_world.max_entity_id(), id)
	var id2 := _world.spawn()
	assert_eq(_world.max_entity_id(), id2)


func test_max_entity_id_monotonic_after_despawn() -> void:
	_world.spawn()
	var id2 := _world.spawn()
	_world.spawn()
	_world.despawn(id2)
	# 实体 ID 单调递增不复用，despawn 不回退 max
	assert_eq(_world.max_entity_id(), 3)


func test_max_entity_id_after_force_spawn() -> void:
	# 快照恢复路径：force_spawn 大 ID 后 max 同步推进，后续 spawn 不再复用
	_world._force_spawn(100)
	assert_eq(_world.max_entity_id(), 100)
	var id := _world.spawn()
	assert_eq(id, 101)
	assert_eq(_world.max_entity_id(), 101)
