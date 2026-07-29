# tests/integration/test_ecs_save_roundtrip.gd
## 集成测试：ECS World ↔ 存档往返。
## EcsWorld + EcsSaveAdapter — 完整 save/load 流程。
extends GutTest

var _world: EcsWorld
var _adapter: EcsSaveAdapter


func before_each() -> void:
	_world = EcsWorld.new()
	_adapter = EcsSaveAdapter.new(1)


func after_each() -> void:
	_world.reset(); _world = null
	_adapter = null


func test_save_then_load_restores_all_entities() -> void:
	# 创建多个实体
	for i in range(5):
		var id := _world.spawn()
		_world.add_component(id, &"Position", {"x": i * 10, "y": 0})
		if i % 2 == 0:
			_world.add_component(id, &"Health", {"current": 100, "max": 100})

	var save_data := _adapter.save(_world)
	_world.reset()

	var result := _adapter.load(_world, save_data)
	assert_true(result.is_ok())
	assert_eq(_world.entity_count(), 5)


func test_roundtrip_preserves_multiple_components() -> void:
	var id := _world.spawn()
	_world.add_component(id, &"Position", {"x": 42, "y": 99})
	_world.add_component(id, &"Health", {"current": 75, "max": 100})
	_world.add_component(id, &"Name", {"value": "Hero"})

	var save_data := _adapter.save(_world)
	_world.reset()
	_adapter.load(_world, save_data)

	assert_eq(_world.get_component(id, &"Position"), {"x": 42, "y": 99})
	assert_eq(_world.get_component(id, &"Health"), {"current": 75, "max": 100})
	assert_eq(_world.get_component(id, &"Name"), {"value": "Hero"})
