# tests/unit/ecs/test_ecs_delta.gd
## GF_EcsDelta / GF_EcsDeltaBuilder / apply_delta 单元测试（性能路线图 §3.1）。
## 变更日志构建、upsert/remove 混合、空 delta、乱序应用、序列化往返。
extends GutTest

var _world: GF_EcsWorld
var _builder: GF_EcsDeltaBuilder
var _applier: GF_EcsSnapshotApplier


func before_each() -> void:
	_world = GF_EcsWorld.new()
	_builder = GF_EcsDeltaBuilder.new()
	_applier = GF_EcsSnapshotApplier.new()


func after_each() -> void:
	_world.reset()
	_world = null
	_builder = null
	_applier = null


# ============================================================
# Builder：从变更日志构建
# ============================================================

func test_build_captures_component_add_as_upsert() -> void:
	var id := _world.spawn()
	_world.change_log.clear()
	_world.add_component(id, FakeCompPosition, {"x": 1, "y": 2})
	var delta := _builder.build(_world)
	assert_eq(delta.upserts.size(), 1)
	assert_eq(delta.upserts[id]["FakeCompPosition"], {"x": 1, "y": 2})
	assert_true(delta.removed_components.is_empty())
	assert_true(delta.removed_entities.is_empty())


func test_build_set_overrides_upsert() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.change_log.clear()
	_world.set_component(id, FakeCompPosition, {"x": 9, "y": 9})
	var delta := _builder.build(_world)
	assert_eq(delta.upserts[id]["FakeCompPosition"], {"x": 9, "y": 9})


func test_build_captures_component_remove() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.change_log.clear()
	_world.remove_component(id, FakeCompPosition)
	var delta := _builder.build(_world)
	assert_true(delta.upserts.is_empty())
	assert_eq(delta.removed_components.size(), 1)
	assert_eq(delta.removed_components[0].entity, id)
	assert_eq(delta.removed_components[0].type_name, "FakeCompPosition")


func test_build_captures_despawn() -> void:
	var id := _world.spawn()
	_world.change_log.clear()
	_world.despawn(id)
	var delta := _builder.build(_world)
	assert_eq(delta.removed_entities.size(), 1)
	assert_eq(delta.removed_entities[0], id)


func test_build_empty_log_gives_empty_delta() -> void:
	_world.change_log.clear()
	var delta := _builder.build(_world)
	assert_true(delta.is_empty())


# ============================================================
# apply_delta：upsert 与删除语义
# ============================================================

func test_apply_delta_upsert_creates_entity() -> void:
	var delta := GF_EcsDelta.new()
	delta.upserts[1] = {"FakeCompPosition": {"x": 5, "y": 5}}
	var result := _applier.apply_delta(_world, delta)
	assert_true(result.is_ok())
	assert_true(_world.has_entity(1))
	assert_eq(_world.get_component(1, FakeCompPosition), {"x": 5, "y": 5})


func test_apply_delta_removes_component() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	_world.add_component(id, FakeCompHealth, {"hp": 1})

	var delta := GF_EcsDelta.new()
	delta.removed_components.append({"entity": id, "type_name": "FakeCompPosition"})
	_applier.apply_delta(_world, delta)

	assert_false(_world.has_component(id, FakeCompPosition))
	assert_true(_world.has_component(id, FakeCompHealth), "其他组件不受影响")


func test_apply_delta_removes_entity() -> void:
	var id := _world.spawn()
	var delta := GF_EcsDelta.new()
	delta.removed_entities.append(id)
	_applier.apply_delta(_world, delta)
	assert_false(_world.has_entity(id))


func test_apply_delta_remove_then_upsert_same_component() -> void:
	# 同帧 remove→set：先删后设，最终为新值
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})

	var delta := GF_EcsDelta.new()
	delta.removed_components.append({"entity": id, "type_name": "FakeCompPosition"})
	delta.upserts[id] = {"FakeCompPosition": {"x": 7, "y": 7}}
	_applier.apply_delta(_world, delta)

	assert_true(_world.has_component(id, FakeCompPosition))
	assert_eq(_world.get_component(id, FakeCompPosition), {"x": 7, "y": 7})


func test_apply_delta_despawn_then_upsert_revives_entity() -> void:
	# despawn 后 upsert 可复活实体（乱序应用健壮性）
	var delta := GF_EcsDelta.new()
	delta.removed_entities.append(5)
	delta.upserts[5] = {"FakeCompHealth": {"hp": 50}}
	_applier.apply_delta(_world, delta)

	assert_true(_world.has_entity(5))
	assert_eq(_world.get_component(5, FakeCompHealth), {"hp": 50})


func test_apply_delta_empty_no_side_effects() -> void:
	_world.spawn()
	var v0 := _world.get_version()
	var result := _applier.apply_delta(_world, GF_EcsDelta.new())
	assert_true(result.is_ok())
	assert_eq(_world.entity_count(), 1)
	assert_eq(_world.get_version(), v0)


# ============================================================
# 序列化往返（§3.2 DELTA 存档模式预留）
# ============================================================

func test_delta_to_dict_from_dict_roundtrip() -> void:
	var delta := GF_EcsDelta.new()
	delta.upserts[3] = {"FakeCompPosition": {"x": 1, "y": 2}}
	delta.removed_entities.append(7)
	delta.removed_components.append({"entity": 9, "type_name": "FakeCompHealth"})

	var restored := GF_EcsDelta.new()
	restored.from_dict(delta.to_dict())

	assert_eq(restored.upserts[3]["FakeCompPosition"], {"x": 1, "y": 2})
	assert_eq(restored.removed_entities.size(), 1)
	assert_eq(restored.removed_entities[0], 7)
	assert_eq(restored.removed_components.size(), 1)
	assert_eq(restored.removed_components[0].entity, 9)


func test_delta_json_roundtrip_preserves_int_keys() -> void:
	# JSON.stringify 会把 int key 转字符串，from_dict 需转回 int
	var delta := GF_EcsDelta.new()
	delta.upserts[42] = {"FakeCompPosition": {"x": 0, "y": 0}}

	var restored := GF_EcsDelta.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(delta.to_dict())))

	assert_true(restored.upserts.has(42), "JSON 往返后 entity key 应为 int")
	var pos: Dictionary = restored.upserts[42]["FakeCompPosition"]
	# JSON 标准语义：数字解析为 float（0 → 0.0）
	assert_eq(pos.x, 0.0)
	assert_eq(pos.y, 0.0)
