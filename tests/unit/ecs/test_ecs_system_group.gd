# tests/unit/ecs/test_ecs_system_group.gd
extends GutTest

var _world: GF_EcsWorld
var _group: GF_EcsSystemGroup


func before_each() -> void:
	_world = GF_EcsWorld.new()
	_group = GF_EcsSystemGroup.new("TestGroup")


func after_each() -> void:
	_world.reset(); _world = null
	_group = null


func test_add_system_increases_count() -> void:
	var sys := _make_system(func(_w, _e, _d): pass)
	_group.add_system(sys)
	assert_eq(_group.system_count(), 1)


func test_remove_system_decreases_count() -> void:
	var sys := _make_system(func(_w, _e, _d): pass)
	_group.add_system(sys)
	_group.remove_system(sys)
	assert_eq(_group.system_count(), 0)


func test_tick_executes_all_systems() -> void:
	var count_a := 0
	var count_b := 0
	_group.add_system(_make_system(func(_w, _e, _d): count_a += 1))
	_group.add_system(_make_system(func(_w, _e, _d): count_b += 1))
	_group.init_all(_world)

	var ecb := GF_EcsCommandBuffer.new()
	_group.tick(_world, ecb, 0.016)
	assert_eq(count_a, 1)
	assert_eq(count_b, 1)


func test_priority_order() -> void:
	var order: Array[String] = []
	var desc_a := GF_EcsSystemDescriptor.new()
	desc_a.system_name = "A"
	desc_a.priority = 100
	_group.add_system(_make_system(func(_w, _e, _d): order.append("A")), desc_a)

	var desc_b := GF_EcsSystemDescriptor.new()
	desc_b.system_name = "B"
	desc_b.priority = 10
	_group.add_system(_make_system(func(_w, _e, _d): order.append("B")), desc_b)

	_group.init_all(_world)
	var ecb := GF_EcsCommandBuffer.new()
	_group.tick(_world, ecb, 0.016)
	assert_eq(order[0], "B")
	assert_eq(order[1], "A")


func test_remove_by_name() -> void:
	var desc := GF_EcsSystemDescriptor.new()
	desc.system_name = "Removable"
	_group.add_system(_make_system(func(_w, _e, _d): pass), desc)
	assert_eq(_group.system_count(), 1)
	_group.remove_by_name("Removable")
	assert_eq(_group.system_count(), 0)


# ============================================================
# 辅助
# ============================================================

func _make_system(p_tick_fn: Callable) -> GF_EcsSystem:
	var s := GDScript.new()
	s.source_code = """
extends GF_EcsSystem
var _tick_fn
func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
	if _tick_fn: _tick_fn.call(p_world, p_ecb, p_delta)
"""
	s.reload()
	var sys: GF_EcsSystem = s.new()
	sys._tick_fn = p_tick_fn
	return sys
