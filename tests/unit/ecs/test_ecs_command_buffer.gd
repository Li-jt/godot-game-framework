# tests/unit/ecs/test_ecs_command_buffer.gd
## GF_EcsCommandBuffer 单元测试。
## 命令缓冲：批量记录 ECS 操作，apply 前预校验，帧末统一 apply。
extends GutTest

var _world: GF_EcsWorld
var _ecb: GF_EcsCommandBuffer


func before_each() -> void:
	_world = GF_EcsWorld.new()
	_ecb = GF_EcsCommandBuffer.new()


func after_each() -> void:
	_world.reset()
	_world = null
	_ecb = null


func test_spawn_queued_not_in_world_yet() -> void:
	var temp_id := _ecb.spawn()
	assert_false(_world.has_entity(temp_id), "临时 ID 在 apply 前不应存在于 world")


func test_add_component_queued_not_visible() -> void:
	var real_id := _world.spawn()
	_ecb.add_component(real_id, FakeCompPosition, {"x": 10, "y": 20})
	assert_false(_world.has_component(real_id, FakeCompPosition), "命令在 apply 前不应生效")


func test_apply_executes_in_order() -> void:
	var result := _ecb.apply_to(_world)
	assert_true(result.is_ok())

	# spawn → add → set 顺序执行
	var temp_id := _ecb.spawn()
	_ecb.add_component(temp_id, FakeCompPosition, {"x": 0, "y": 0})
	_ecb.set_component(temp_id, FakeCompPosition, {"x": 100, "y": 200})

	var apply_result := _ecb.apply_to(_world)
	assert_true(apply_result.is_ok())

	var real_id: int = apply_result.data.get(temp_id, 0)
	assert_true(real_id > 0)
	assert_eq(_world.get_component(real_id, FakeCompPosition), {"x": 100, "y": 200})


func test_apply_clears_buffer() -> void:
	_ecb.spawn()
	_ecb.apply_to(_world)
	assert_eq(_ecb.count(), 0)


func test_clear_discards_all() -> void:
	_ecb.spawn()
	_ecb.add_component(1, FakeCompPosition, {"x": 0, "y": 0})
	_ecb.clear()
	assert_eq(_ecb.count(), 0)

	# clear 后 apply 不执行任何操作
	var prev_count := _world.entity_count()
	_ecb.apply_to(_world)
	assert_eq(_world.entity_count(), prev_count)


func test_despawn_queued_then_apply() -> void:
	var real_id := _world.spawn()
	_ecb.despawn(real_id)
	assert_true(_world.has_entity(real_id), "apply 前 entity 仍存在")
	_ecb.apply_to(_world)
	assert_false(_world.has_entity(real_id), "apply 后 entity 被移除")


func test_multiple_spawn_and_ref_inside_buffer() -> void:
	# 在 ECB 内部 spawn 两个临时 entity，第二个引用第一个
	var temp1 := _ecb.spawn()
	_ecb.add_component(temp1, FakeCompPosition, {"x": 0, "y": 0})
	var temp2 := _ecb.spawn()
	_ecb.add_component(temp2, FakeCompPosition, {"x": 100, "y": 100})

	var result := _ecb.apply_to(_world)
	assert_true(result.is_ok())
	assert_eq(_world.entity_count(), 2)


func test_validate_rejects_unspawned_reference() -> void:
	# 引用一个未 spawn 的临时 entity 应被预校验拒绝
	_ecb.add_component(-1, FakeCompPosition, {"x": 0, "y": 0})
	var result := _ecb.apply_to(_world)
	assert_true(result.is_fail())
	assert_eq(result.status_code, GF_OperationResult.ERR_PRECONDITION)
