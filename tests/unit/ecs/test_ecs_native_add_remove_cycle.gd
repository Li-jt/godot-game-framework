# tests/unit/ecs/test_ecs_native_add_remove_cycle.gd
## 原生后端组件 add/remove 压力回归测试。
## 覆盖 2026-08-20 崩溃修复：组件列（Variant*）补全 move/copy 生命周期钩子前，
## archetype 移动在源表空洞残留悬空指针；实体移回原 archetype 复用空洞时，
## move_dtor 先释放残留指针再把同一（已释放）指针 memcpy 进目标槽 →
## 后续 dtor double-free（SIGABRT / POINTER_BEING_FREED_WAS_NOT_ALLOCATED）。
## 此测试反复 add/remove 触发空洞复用路径：旧二进制下数据损坏/崩溃，
## 修复后稳定通过。
extends GutTest

const CYCLES := 200

var _world: GF_EcsWorld


func before_each() -> void:
	_world = GF_EcsWorld.new(GF_EcsStorageIndex.StorageBackend.NATIVE)


func after_each() -> void:
	_world.reset()
	_world = null


func test_add_remove_cycle_preserves_other_components() -> void:
	var id := _world.spawn()
	_world.add_component(id, FakeCompPosition, {"x": 1.0, "y": 2.0})
	_world.add_component(id, FakeCompName, {"name": "machine"})

	# 反复 add/remove 第三个组件：实体在 [Pos,Name,Health] 与 [Pos,Name]
	# 两个 archetype 间来回移动，每次移动都复用对方表的空洞
	for i in CYCLES:
		_world.add_component(id, FakeCompHealth, {"hp": i})
		var hp: Dictionary = _world.get_component(id, FakeCompHealth)
		assert_eq(int(hp.get("hp", -1)), i, "循环 %d add 后 Health 数据应正确" % i)

		_world.remove_component(id, FakeCompHealth)
		assert_false(_world.has_component(id, FakeCompHealth), "循环 %d remove 后应无 Health" % i)

		# 其它组件在 archetype 移动后应保持完好（修复前此处读到悬空指针）
		var pos: Dictionary = _world.get_component(id, FakeCompPosition)
		assert_eq(pos.get("x"), 1.0, "循环 %d 后 Position 应完好" % i)

	# reset（全量销毁）：修复前残留悬空指针在此处 double-free 崩溃
	_world.reset()
	assert_eq(_world.entity_count(), 0, "reset 后实体应清空")


func test_many_entities_add_remove_cycle() -> void:
	var ids: Array[int] = []
	for i in 100:
		var id := _world.spawn()
		_world.add_component(id, FakeCompPosition, {"x": float(i), "y": 0.0})
		_world.add_component(id, FakeCompName, {"name": "e%d" % i})
		ids.append(id)

	for round in 50:
		for id in ids:
			_world.add_component(id, FakeCompHealth, {"hp": round})
			_world.remove_component(id, FakeCompHealth)

	# 全部实体数据应完好
	for i in ids.size():
		var pos: Dictionary = _world.get_component(ids[i], FakeCompPosition)
		assert_eq(pos.get("x"), float(i), "实体 %d 数据应完好" % i)
		var name: Dictionary = _world.get_component(ids[i], FakeCompName)
		assert_eq(name.get("name"), "e%d" % i, "实体 %d 名称应完好" % i)

	_world.reset()
	assert_eq(_world.entity_count(), 0, "reset 后实体应清空")
