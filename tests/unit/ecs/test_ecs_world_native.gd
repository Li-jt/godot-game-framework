# tests/unit/ecs/test_ecs_world_native.gd
## GF_EcsWorld NATIVE（Flecs）后端对拍测试。
## 与 test_ecs_world.gd / test_ecs_change_log.gd 的核心行为约定对齐，
## 额外覆盖原生后端的语义适配点：
##   - 实体 ID 单调不复用（Flecs index+generation 被门面映射隐藏）
##   - change log 两过滤规则：set 首次只记 CHANGED、despawn 不泄漏组件 REMOVED
##   - reset 后组件类型键复用
extends GutTest

var _world: GF_EcsWorld


func before_each() -> void:
	_world = GF_EcsWorld.new(GF_EcsStorageIndex.StorageBackend.NATIVE)


func after_each() -> void:
	_world.reset()
	_world = null


# ============================================================
# 实体生命周期
# ============================================================

func test_spawn_returns_unique_increasing_ids() -> void:
	var id1 := _world.spawn()
	var id2 := _world.spawn()
	assert_ne(id1, id2)
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
	_world.despawn(id)
	assert_false(_world.has_entity(id))


func test_despawn_decrements_entity_count() -> void:
	var id := _world.spawn()
	assert_eq(_world.entity_count(), 1)
	_world.despawn(id)
	assert_eq(_world.entity_count(), 0)


func test_entity_ids_never_reused_after_despawn() -> void:
	# 语义适配点：Flecs 原生复用 index，门面必须保持「ID 单调不复用」
	var id1 := _world.spawn()
	_world.despawn(id1)
	var id2 := _world.spawn()
	assert_true(id2 > id1, "despawn 后新实体 ID 必须大于旧 ID（不复用）")


func test_max_entity_id_monotonic() -> void:
	var id1 := _world.spawn()
	var id2 := _world.spawn()
	assert_eq(_world.max_entity_id(), id2)
	_world.despawn(id2)
	assert_eq(_world.max_entity_id(), id2, "despawn 后 max_entity_id 不回退")
	var id3 := _world.spawn()
	assert_true(id3 > id2)
	assert_eq(_world.max_entity_id(), id3)


func test_all_entities_contains_spawned() -> void:
	var id1 := _world.spawn()
	var id2 := _world.spawn()
	_world.despawn(id1)
	var all := _world.all_entities()
	assert_eq(all.size(), 1)
	assert_eq(all[0], id2)


# ============================================================
# 组件操作
# ============================================================

func test_add_component_then_get_returns_data() -> void:
	var id := _world.spawn()
	var result := _world.add_component(id, FakeCompPosition, {"x": 10, "y": 20})
	assert_true(result.is_ok())
	var data: Dictionary = _world.get_component(id, FakeCompPosition)
	assert_eq(data["x"], 10)
	assert_eq(data["y"], 20)


func test_add_component_existing_fails_and_preserves_data() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 1, "y": 1})
	var result := _world.add_component(id, FakeCompPosition, {"x": 99, "y": 99})
	assert_true(result.is_fail())
	var data: Dictionary = _world.get_component(id, FakeCompPosition)
	assert_eq(data["x"], 1, "add 已有组件失败时原数据不被覆盖")


func test_set_component_updates_data() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.set_component(id, FakeCompPosition, {"x": 5, "y": 6})
	var data: Dictionary = _world.get_component(id, FakeCompPosition)
	assert_eq(data["x"], 5)
	assert_eq(data["y"], 6)


func test_set_component_first_time_behaves_like_set() -> void:
	var id := _world.spawn()
	_world.set_component(id, FakeCompPosition, {"x": 7, "y": 8})
	var data: Dictionary = _world.get_component(id, FakeCompPosition)
	assert_eq(data["x"], 7)


func test_get_component_nonexistent_returns_null() -> void:
	var id := _world.spawn()
	assert_null(_world.get_component(id, FakeCompPosition))
	assert_null(_world.get_component(id, FakeCompNonexistent))


func test_has_component_lifecycle() -> void:
	var id := _world.spawn()
	assert_false(_world.has_component(id, FakeCompPosition))
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	assert_true(_world.has_component(id, FakeCompPosition))
	_world.remove_component(id, FakeCompPosition)
	assert_false(_world.has_component(id, FakeCompPosition))


func test_remove_component_nonexistent_is_silent() -> void:
	var id := _world.spawn()
	var v0 := _world.get_version()
	_world.change_log.clear()
	_world.remove_component(id, FakeCompPosition)
	assert_eq(_world.get_version(), v0, "remove 不存在组件不应递增版本")
	assert_false(_world.change_log.has_changes())


func test_version_changes_only_on_mutation() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	var v0 := _world.get_version()
	# 只读操作不改版本
	_world.get_component(id, FakeCompPosition)
	_world.has_component(id, FakeCompPosition)
	_world.has_entity(id)
	_world.entity_count()
	_world.all_entities()
	assert_eq(_world.get_version(), v0)
	# 写操作递增
	_world.set_component(id, FakeCompPosition, {"x": 1, "y": 1})
	assert_eq(_world.get_version(), v0 + 1)


# ============================================================
# 变更日志对拍（关键语义适配点）
# ============================================================

func test_change_log_spawn_records_added_entity() -> void:
	var id := _world.spawn()
	assert_eq(_world.change_log.added_entities.size(), 1)
	assert_eq(_world.change_log.added_entities[0], id)


func test_change_log_despawn_records_removed_entity_only() -> void:
	# 适配点 2：despawn 不泄漏组件 REMOVED 事件（框架语义只记 removed_entity）
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.change_log.clear()
	_world.despawn(id)
	assert_eq(_world.change_log.removed_entities.size(), 1)
	assert_eq(_world.change_log.removed_entities[0], id)
	assert_eq(_world.change_log.component_changes.size(), 0,
		"despawn 不应泄漏组件变更事件")


func test_change_log_add_records_single_added_with_data() -> void:
	var id := _world.spawn()
	_world.change_log.clear()
	_world.add_component(id, FakeCompPosition, {"x": 3, "y": 4})
	assert_eq(_world.change_log.component_changes.size(), 1, "add 只记一条")
	var ch: Dictionary = _world.change_log.component_changes[0]
	assert_eq(ch.entity, id)
	assert_eq(ch.kind, GF_EcsChangeLog.ChangeKind.COMPONENT_ADDED)
	assert_eq(ch.component.x, 3, "事件携带组件数据快照")


func test_change_log_set_first_time_records_single_changed() -> void:
	# 适配点 1：set 首次（组件不存在）只记一条 CHANGED——
	# Flecs 原生发 ADDED+CHANGED 两条，门面过滤 ADDED
	var id := _world.spawn()
	_world.change_log.clear()
	_world.set_component(id, FakeCompPosition, {"x": 9, "y": 9})
	assert_eq(_world.change_log.component_changes.size(), 1, "set 首次只记一条 CHANGED")
	var ch: Dictionary = _world.change_log.component_changes[0]
	assert_eq(ch.kind, GF_EcsChangeLog.ChangeKind.COMPONENT_CHANGED)


func test_change_log_set_existing_records_changed() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.change_log.clear()
	_world.set_component(id, FakeCompPosition, {"x": 1, "y": 1})
	assert_eq(_world.change_log.component_changes.size(), 1)
	assert_eq(_world.change_log.component_changes[0].kind, GF_EcsChangeLog.ChangeKind.COMPONENT_CHANGED)


func test_change_log_remove_records_removed() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.change_log.clear()
	_world.remove_component(id, FakeCompPosition)
	assert_eq(_world.change_log.component_changes.size(), 1)
	var ch: Dictionary = _world.change_log.component_changes[0]
	assert_eq(ch.kind, GF_EcsChangeLog.ChangeKind.COMPONENT_REMOVED)
	assert_null(ch.component, "remove 事件不带组件数据")


func test_change_log_type_id_matches_registry() -> void:
	# 原生 type_key 必须与 GDScript registry 的 type_id 对齐
	var id := _world.spawn()
	_world.add_component(id, FakeCompVelocity, {"vx": 1, "vy": 0})
	var ch: Dictionary = _world.change_log.component_changes[0]
	assert_eq(ch.type_id, _world._get_registry().type_id_of(FakeCompVelocity))


func test_change_log_clear_marks_consumed() -> void:
	_world.spawn()
	_world.change_log.clear()
	assert_true(_world.change_log.consumed)
	assert_false(_world.change_log.has_changes())


# ============================================================
# Query 对拍
# ============================================================

func test_query_with_single_type_filters() -> void:
	var with_pos := _world.spawn()
	_world.add_component(with_pos, FakeCompPosition, {"x": 0, "y": 0})
	var without_pos := _world.spawn()
	_world.add_component(without_pos, FakeCompVelocity, {"vx": 1, "vy": 0})

	var query := GF_EcsQuery.new().with_component(FakeCompPosition).build()
	var result := query.execute_entities(_world)
	assert_eq(result.size(), 1)
	assert_eq(result[0], with_pos)


func test_query_with_multiple_types() -> void:
	var both := _world.spawn()
	_world.add_component(both, FakeCompPosition, {"x": 0, "y": 0})
	_world.add_component(both, FakeCompVelocity, {"vx": 1, "vy": 0})
	var pos_only := _world.spawn()
	_world.add_component(pos_only, FakeCompPosition, {"x": 0, "y": 0})

	var query := GF_EcsQuery.new() \
		.with_component(FakeCompPosition) \
		.with_component(FakeCompVelocity).build()
	var result := query.execute_entities(_world)
	assert_eq(result.size(), 1)
	assert_eq(result[0], both)


func test_query_without_excludes() -> void:
	var a := _world.spawn()
	_world.add_component(a, FakeCompPosition, {"x": 0, "y": 0})
	var b := _world.spawn()
	_world.add_component(b, FakeCompPosition, {"x": 0, "y": 0})
	_world.add_component(b, FakeCompVelocity, {"vx": 1, "vy": 0})

	var query := GF_EcsQuery.new() \
		.with_component(FakeCompPosition) \
		.without_component(FakeCompVelocity).build()
	var result := query.execute_entities(_world)
	assert_eq(result.size(), 1)
	assert_eq(result[0], a)


func test_query_execute_returns_rows_with_data() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 42, "y": 0})

	var query := GF_EcsQuery.new().with_component(FakeCompPosition).build()
	var rows := query.execute(_world)
	assert_eq(rows.count(), 1)
	var row := rows.get_row(0)
	assert_eq(row.entity, id)
	var data: Dictionary = row._components[FakeCompPosition]
	assert_eq(data["x"], 42)


func test_query_empty_result() -> void:
	var id := _world.spawn()
	var query := GF_EcsQuery.new().with_component(FakeCompNonexistent).build()
	assert_eq(query.execute_entities(_world).size(), 0)
	assert_eq(query.execute(_world).count(), 0)


func test_query_no_with_returns_all_alive() -> void:
	var id1 := _world.spawn()
	var id2 := _world.spawn()
	var dead := _world.spawn()
	_world.despawn(dead)
	var query := GF_EcsQuery.new().build()
	var result := query.execute_entities(_world)
	assert_eq(result.size(), 2)


# ============================================================
# reset 与组件类型键复用
# ============================================================

func test_reset_clears_everything() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.reset()
	assert_eq(_world.entity_count(), 0)
	assert_eq(_world.get_version(), 0)
	assert_false(_world.has_entity(id))
	assert_false(_world.change_log.has_changes())


func test_reset_allows_reuse_of_type_keys() -> void:
	# reset 后 GDScript registry 重建（type_id 从 1 重新分配），
	# 原生侧组件类型注册保留但键必须重新对齐
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.reset()
	var id2 := _world.spawn()
	var result := _world.add_component(id2, FakeCompPosition, {"x": 7, "y": 7})
	assert_true(result.is_ok())
	var data: Dictionary = _world.get_component(id2, FakeCompPosition)
	assert_eq(data["x"], 7)
	assert_eq(_world.change_log.component_changes.size(), 1)
