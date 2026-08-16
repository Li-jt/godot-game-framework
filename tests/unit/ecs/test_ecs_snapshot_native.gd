# tests/unit/ecs/test_ecs_snapshot_native.gd
## GF_EcsWorld NATIVE（Flecs）后端的快照/增量/存档对拍测试。
## 与 test_ecs_snapshot.gd / test_ecs_delta.gd 的核心行为约定对齐，
## 验证快照模块经公共 API 在原生后端上的行为一致性。
extends GutTest

var _world: GF_EcsWorld
var _builder: GF_EcsSnapshotBuilder
var _applier: GF_EcsSnapshotApplier


func before_each() -> void:
	_world = GF_EcsWorld.new(GF_EcsStorageIndex.StorageBackend.NATIVE)
	_builder = GF_EcsSnapshotBuilder.new()
	_applier = GF_EcsSnapshotApplier.new()


func after_each() -> void:
	_world.reset()
	_world = null
	_builder = null
	_applier = null


# ============================================================
# 快照构建
# ============================================================

func test_build_captures_entities() -> void:
	var id1 := _world.spawn()
	_world.add_component(id1, FakeCompPosition, {"x": 10, "y": 20})
	var id2 := _world.spawn()
	_world.add_component(id2, FakeCompPosition, {"x": 30, "y": 40})

	var snapshot := _builder.build(_world)
	assert_not_null(snapshot)
	assert_eq(snapshot.entity_count(), 2)


func test_build_captures_multiple_component_types() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 1, "y": 2})
	_world.add_component(id, FakeCompHealth, {"current": 50, "max": 100})

	var snapshot := _builder.build(_world)
	assert_eq(snapshot.entity_count(), 1)
	# 组件数据以 type_name 为键存于 entities[0].components
	var components: Dictionary = snapshot.entities[0]["components"]
	assert_eq(components.size(), 2, "两种组件类型都应入快照")


func test_build_skips_entities_without_components() -> void:
	# 裸实体（无组件）也应入快照（component 字典为空）
	var id := _world.spawn()
	var snapshot := _builder.build(_world)
	assert_eq(snapshot.entity_count(), 1)
	assert_eq(snapshot.entities[0]["entity"], id)


# ============================================================
# 快照应用（含 _force_spawn 强制 ID 恢复）
# ============================================================

func test_apply_restores_exact_state() -> void:
	var id1 := _world.spawn()
	_world.add_component(id1, FakeCompPosition, {"x": 1, "y": 2})
	var id2 := _world.spawn()
	_world.add_component(id2, FakeCompPosition, {"x": 3, "y": 4})
	_world.add_component(id2, FakeCompHealth, {"current": 50, "max": 100})

	var snapshot := _builder.build(_world)
	_world.set_component(id1, FakeCompPosition, {"x": 888, "y": 999})
	_world.remove_component(id2, FakeCompHealth)

	var result := _applier.apply(_world, snapshot)
	assert_true(result.is_ok())
	assert_eq(_world.get_component(id1, FakeCompPosition), {"x": 1, "y": 2})
	assert_true(_world.has_component(id2, FakeCompHealth))


func test_apply_restores_entity_ids_exactly() -> void:
	# _force_spawn 语义：恢复后的实体 ID 与快照一致（ID 单调映射必须支持指定 ID）
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 7, "y": 8})
	var snapshot := _builder.build(_world)

	_world.despawn(id)
	_world.spawn()  # 占用一个新 ID，确认 apply 用 _force_spawn 恢复原 ID

	_applier.apply(_world, snapshot)
	assert_true(_world.has_entity(id), "快照恢复必须还原原实体 ID")
	assert_eq(_world.get_component(id, FakeCompPosition), {"x": 7, "y": 8})


func test_snapshot_independent_of_world_mutation() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 10, "y": 20})
	var snapshot := _builder.build(_world)
	_world.set_component(id, FakeCompPosition, {"x": 999, "y": 999})
	_applier.apply(_world, snapshot)
	assert_eq(_world.get_component(id, FakeCompPosition), {"x": 10, "y": 20})


# ============================================================
# 增量 delta 构建与应用
# ============================================================

func test_delta_build_captures_component_add_as_upsert() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 1, "y": 2})
	_world.change_log.clear()
	_world.add_component(id, FakeCompVelocity, {"vx": 3, "vy": 4})

	var delta := GF_EcsDeltaBuilder.new().build(_world)
	assert_eq(delta.upserts.size(), 1)
	assert_eq(delta.removed_entities.size(), 0)


func test_delta_build_captures_despawn() -> void:
	var id := _world.spawn()
	_world.change_log.clear()
	_world.despawn(id)

	var delta := GF_EcsDeltaBuilder.new().build(_world)
	assert_eq(delta.removed_entities.size(), 1)
	assert_eq(delta.removed_entities[0], id)


func test_apply_delta_upsert_creates_entity() -> void:
	var delta := GF_EcsDelta.new()
	delta.upserts[100] = {"FakeCompPosition": {"x": 5, "y": 6}}

	var result := _applier.apply_delta(_world, delta)
	assert_true(result.is_ok())
	assert_true(_world.has_entity(100))
	assert_eq(_world.get_component(100, FakeCompPosition), {"x": 5, "y": 6})


func test_apply_delta_removes_component() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.add_component(id, FakeCompVelocity, {"vx": 1, "vy": 0})

	var delta := GF_EcsDelta.new()
	delta.removed_components.append({"entity": id, "type_name": "FakeCompPosition"})

	var result := _applier.apply_delta(_world, delta)
	assert_true(result.is_ok())
	assert_false(_world.has_component(id, FakeCompPosition))
	assert_true(_world.has_component(id, FakeCompVelocity), "无关组件不受影响")


func test_apply_delta_despawn_then_upsert_revives_entity() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})

	var delta := GF_EcsDelta.new()
	delta.removed_entities.append(id)
	delta.upserts[id] = {"FakeCompPosition": {"x": 9, "y": 9}}

	var result := _applier.apply_delta(_world, delta)
	assert_true(result.is_ok())
	assert_true(_world.has_entity(id), "despawn 后 upsert 应复活实体")
	assert_eq(_world.get_component(id, FakeCompPosition), {"x": 9, "y": 9})


# ============================================================
# 存档适配（快照 → JSON → 恢复全链路）
# ============================================================

func test_save_adapter_roundtrip() -> void:
	var id1 := _world.spawn()
	_world.add_component(id1, FakeCompPosition, {"x": 1, "y": 2})
	var id2 := _world.spawn()
	_world.add_component(id2, FakeCompPosition, {"x": 3, "y": 4})
	_world.add_component(id2, FakeCompHealth, {"current": 50, "max": 100})

	var adapter := GF_EcsSaveAdapter.new(1)
	var save_data := adapter.save(_world)

	# 破坏世界
	_world.reset()
	assert_eq(_world.entity_count(), 0)

	var result := adapter.load(_world, save_data)
	assert_true(result.is_ok())
	assert_eq(_world.entity_count(), 2)
	assert_true(_world.has_entity(id1))
	assert_eq(_world.get_component(id1, FakeCompPosition), {"x": 1, "y": 2})
	assert_true(_world.has_component(id2, FakeCompHealth))
