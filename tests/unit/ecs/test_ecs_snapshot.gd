# tests/unit/ecs/test_ecs_snapshot.gd
extends GutTest

var _world: GF_EcsWorld
var _builder: GF_EcsSnapshotBuilder
var _applier: GF_EcsSnapshotApplier


func before_each() -> void:
	_world = GF_EcsWorld.new()
	_builder = GF_EcsSnapshotBuilder.new()
	_applier = GF_EcsSnapshotApplier.new()


func after_each() -> void:
	_world.reset(); _world = null
	_builder = null; _applier = null


func test_build_captures_entities() -> void:
	var id1 := _world.spawn()
	_world.add_component(id1, FakeCompPosition, {"x": 10, "y": 20})
	var id2 := _world.spawn()
	_world.add_component(id2, FakeCompPosition, {"x": 30, "y": 40})

	var snapshot := _builder.build(_world)
	assert_not_null(snapshot)
	assert_eq(snapshot.entity_count(), 2)


func test_snapshot_independent_of_world_mutation() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 10, "y": 20})
	var snapshot := _builder.build(_world)
	_world.set_component(id, FakeCompPosition, {"x": 999, "y": 999})
	_applier.apply(_world, snapshot)
	assert_eq(_world.get_component(id, FakeCompPosition), {"x": 10, "y": 20})


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


func test_roundtrip_spawn_modify_restore() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 0, "y": 0})
	var snapshot := _builder.build(_world)
	_world.despawn(id)
	assert_eq(_world.entity_count(), 0)
	var result := _applier.apply(_world, snapshot)
	assert_true(result.is_ok())
	assert_eq(_world.entity_count(), 1)


func test_to_dict_and_from_dict_roundtrip() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 10, "y": 20})
	var snapshot := _builder.build(_world)
	var snap_dict := snapshot.to_dict()

	var restored := GF_EcsWorldSnapshot.new()
	restored.from_dict(snap_dict)

	var result := _applier.apply(_world, restored)
	assert_true(result.is_ok())
	assert_eq(_world.entity_count(), 1)
