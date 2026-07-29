# tests/unit/ecs/test_ecs_snapshot.gd
extends GutTest

var _world: EcsWorld
var _builder: EcsSnapshotBuilder
var _applier: EcsSnapshotApplier


func before_each() -> void:
	_world = EcsWorld.new()
	_builder = EcsSnapshotBuilder.new()
	_applier = EcsSnapshotApplier.new()


func after_each() -> void:
	_world.reset(); _world = null
	_builder = null; _applier = null


func test_build_captures_entities() -> void:
	var id1 := _world.spawn()
	_world.add_component(id1, &"Position", {"x": 10, "y": 20})
	var id2 := _world.spawn()
	_world.add_component(id2, &"Position", {"x": 30, "y": 40})

	var snapshot := _builder.build(_world)
	assert_not_null(snapshot)
	assert_eq(snapshot.entity_count(), 2)


func test_snapshot_independent_of_world_mutation() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 10, "y": 20})
	var snapshot := _builder.build(_world)
	_world.set_component(id, &"Position", {"x": 999, "y": 999})
	_applier.apply(_world, snapshot)
	assert_eq(_world.get_component(id, &"Position"), {"x": 10, "y": 20})


func test_apply_restores_exact_state() -> void:
	var id1 := _world.spawn()
	_world.add_component(id1, &"Position", {"x": 1, "y": 2})
	var id2 := _world.spawn()
	_world.add_component(id2, &"Position", {"x": 3, "y": 4})
	_world.add_component(id2, &"Health", {"current": 50, "max": 100})

	var snapshot := _builder.build(_world)
	_world.set_component(id1, &"Position", {"x": 888, "y": 999})
	_world.remove_component(id2, &"Health")

	var result := _applier.apply(_world, snapshot)
	assert_true(result.is_ok())
	assert_eq(_world.get_component(id1, &"Position"), {"x": 1, "y": 2})
	assert_true(_world.has_component(id2, &"Health"))


func test_roundtrip_spawn_modify_restore() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 0, "y": 0})
	var snapshot := _builder.build(_world)
	_world.despawn(id)
	assert_eq(_world.entity_count(), 0)
	var result := _applier.apply(_world, snapshot)
	assert_true(result.is_ok())
	assert_eq(_world.entity_count(), 1)


func test_to_dict_and_from_dict_roundtrip() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 10, "y": 20})
	var snapshot := _builder.build(_world)
	var snap_dict := snapshot.to_dict()

	var restored := EcsWorldSnapshot.new()
	restored.from_dict(snap_dict)

	var result := _applier.apply(_world, restored)
	assert_true(result.is_ok())
	assert_eq(_world.entity_count(), 1)
