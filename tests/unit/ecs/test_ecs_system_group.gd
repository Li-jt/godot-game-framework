# tests/unit/ecs/test_ecs_system_group.gd
## 使用 dynamic_ecs_system.was_ticked / was_shutdown 断言，
## 避免 GDScript 闭包对 bool 值类型按值捕获的问题。
extends GutTest

var _world: GF_EcsWorld


func before_each() -> void:
	_world = GF_EcsWorld.new()


func after_each() -> void:
	_world = null


func test_system_added_to_group() -> void:
	var group := GF_EcsSystemGroup.new()
	var sys := _make_system(func(_w, _ecb, _dt): pass)
	group.add_system(sys)
	assert_true(group.has_system(sys))


func test_system_removed_from_group() -> void:
	var group := GF_EcsSystemGroup.new()
	var sys := _make_system(func(_w, _ecb, _dt): pass)
	group.add_system(sys)
	group.remove_system(sys)
	assert_false(group.has_system(sys))


func test_tick_runs_all_systems() -> void:
	var group := GF_EcsSystemGroup.new()
	var ecb := GF_EcsCommandBuffer.new()
	var sys1 := _make_system(func(_w, _ecb, _dt): pass)
	var sys2 := _make_system(func(_w, _ecb, _dt): pass)
	group.add_system(sys1)
	group.add_system(sys2)
	group.tick(_world, ecb, 0.016)
	assert_true(sys1.was_ticked)
	assert_true(sys2.was_ticked)


func test_system_respects_priority_order() -> void:
	var group := GF_EcsSystemGroup.new()
	var ecb := GF_EcsCommandBuffer.new()
	var order: Array[String] = []
	var sys_a := _make_system(func(_w, _ecb, _dt): order.append("a"))
	var sys_b := _make_system(func(_w, _ecb, _dt): order.append("b"))
	# sys_a priority=1 (先), sys_b priority=10 (后)
	var desc_a := GF_EcsSystemDescriptor.new()
	desc_a.priority = 1
	group.add_system(sys_a, desc_a)
	var desc_b := GF_EcsSystemDescriptor.new()
	desc_b.priority = 10
	group.add_system(sys_b, desc_b)
	group.init_all(_world)
	group.tick(_world, ecb, 0.016)
	assert_eq(order[0], "a")
	assert_eq(order[1], "b")


func test_shutdown_called_on_remove_by_owner() -> void:
	var group := GF_EcsSystemGroup.new()
	var sys := _make_system(func(_w, _ecb, _dt): pass)
	var desc := GF_EcsSystemDescriptor.new()
	desc.owner = "mod_x"
	group.add_system(sys, desc)
	group.remove_by_owner("mod_x")
	assert_true(sys.was_shutdown)


func test_remove_by_name_returns_ok() -> void:
	var group := GF_EcsSystemGroup.new()
	var sys := _make_system(func(_w, _ecb, _dt): pass)
	var desc := GF_EcsSystemDescriptor.new()
	desc.system_name = "my_system"
	group.add_system(sys, desc)
	var result := group.remove_by_name("my_system")
	assert_true(result.is_ok())
	assert_false(group.has_system(sys))


# ============================================================
# 辅助
# ============================================================

func _make_system(p_tick_fn: Callable) -> GF_EcsSystem:
	var sys_script: GDScript = load("res://tests/helpers/dynamic_ecs_system.gd")
	var sys: GF_EcsSystem = sys_script.new()
	sys._tick_fn = p_tick_fn
	return sys
