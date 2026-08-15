# tests/unit/ecs/test_ecs_change_log.gd
## GF_EcsChangeLog 单元测试（性能路线图 §1.4）。
## 各 mutation 自动记录、ECB 批量追加、clear/reset、溢出降级。
extends GutTest

var _world: GF_EcsWorld


func before_each() -> void:
	_world = GF_EcsWorld.new()


func after_each() -> void:
	_world.reset()
	_world = null


# ============================================================
# 实体增删记录
# ============================================================

func test_spawn_records_added_entity() -> void:
	var id := _world.spawn()
	assert_eq(_world.change_log.added_entities.size(), 1)
	assert_eq(_world.change_log.added_entities[0], id)


func test_despawn_records_removed_entity() -> void:
	var id := _world.spawn()
	_world.change_log.clear()
	_world.despawn(id)
	assert_eq(_world.change_log.removed_entities.size(), 1)
	assert_eq(_world.change_log.removed_entities[0], id)


func test_despawn_nonexistent_not_recorded() -> void:
	_world.change_log.clear()
	_world.despawn(99999)
	assert_eq(_world.change_log.removed_entities.size(), 0)


# ============================================================
# 组件变更记录
# ============================================================

func test_add_component_records_added() -> void:
	var id := _world.spawn()
	_world.change_log.clear()
	var data := {"x": 10, "y": 20}
	_world.add_component(id, FakeCompPosition, data)
	var log := _world.change_log
	assert_eq(log.component_changes.size(), 1)
	var change: Dictionary = log.component_changes[0]
	assert_eq(change.entity, id)
	assert_eq(change.kind, GF_EcsChangeLog.ChangeKind.COMPONENT_ADDED)
	assert_eq(change.component, data)


func test_set_component_records_changed() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.change_log.clear()
	var data := {"x": 100, "y": 200}
	_world.set_component(id, FakeCompPosition, data)
	var change: Dictionary = _world.change_log.component_changes[0]
	assert_eq(change.kind, GF_EcsChangeLog.ChangeKind.COMPONENT_CHANGED)
	assert_eq(change.component, data)


func test_remove_component_records_removed() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.change_log.clear()
	_world.remove_component(id, FakeCompPosition)
	var change: Dictionary = _world.change_log.component_changes[0]
	assert_eq(change.kind, GF_EcsChangeLog.ChangeKind.COMPONENT_REMOVED)
	assert_null(change.component)


func test_component_change_carries_type_id() -> void:
	var id := _world.spawn()
	_world.change_log.clear()
	_world.add_component(id, FakeCompHealth, {"hp": 100})
	var change: Dictionary = _world.change_log.component_changes[0]
	assert_true(change.type_id > 0)
	assert_eq(change.type_id, _world._get_registry().type_id_of(FakeCompHealth))


# ============================================================
# ECB apply 批量追加
# ============================================================

func test_ecb_apply_records_all_mutations() -> void:
	_world.change_log.clear()
	var doomed := _world.spawn()  # 直接 spawn：记 1 条 added
	var ecb := GF_EcsCommandBuffer.new()
	var temp_id := ecb.spawn()
	ecb.add_component(temp_id, FakeCompPosition, {"x": 1, "y": 1})
	ecb.set_component(temp_id, FakeCompPosition, {"x": 2, "y": 2})
	ecb.despawn(doomed)
	ecb.apply_to(_world)

	var log := _world.change_log
	assert_eq(log.added_entities.size(), 2, "直接 spawn + ECB spawn 各一条")
	assert_eq(log.removed_entities.size(), 1, "ECB despawn 应记录 removed")
	assert_eq(log.component_changes.size(), 2, "add + set 各一条组件变更")


# ============================================================
# 生命周期管理
# ============================================================

func test_clear_empties_log() -> void:
	_world.spawn()
	_world.change_log.clear()
	assert_false(_world.change_log.has_changes())
	assert_eq(_world.change_log.added_entities.size(), 0)
	assert_eq(_world.change_log.component_changes.size(), 0)


func test_has_changes_reflects_state() -> void:
	assert_false(_world.change_log.has_changes())
	_world.spawn()
	assert_true(_world.change_log.has_changes())


func test_reset_clears_log() -> void:
	_world.spawn()
	_world.add_component(1, FakeCompPosition, {"x": 0, "y": 0})
	_world.reset()
	assert_false(_world.change_log.has_changes())


# ============================================================
# 溢出降级
# ============================================================

func test_overflow_sets_flag_and_stops_recording() -> void:
	_world.change_log.max_entries = 3
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.set_component(id, FakeCompPosition, {"x": 1, "y": 1})
	_world.remove_component(id, FakeCompPosition)
	# 第 4 次组件变更：达上限，置 overflowed 并丢弃该记录
	var id2 := _world.spawn()
	_world.add_component(id2, FakeCompHealth, {"hp": 1})
	assert_true(_world.change_log.overflowed)
	assert_eq(_world.change_log.component_changes.size(), 3, "超限后不再追加")
