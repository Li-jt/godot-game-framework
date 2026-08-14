# tests/unit/ecs/test_spatial_grid_index.gd
## GF_GridIndex 单元测试：
## 往返、lazy eviction、miss 回调、显式注销、漂移防护。
extends GutTest

const CELL_A := Vector2i(3, 5)
const CELL_B := Vector2i(-2, 7)

var _world: GF_EcsWorld
var _index: GF_GridIndex
var _misses: Array = []  # 记录 miss 回调收到的格子坐标


func before_each() -> void:
	_world = GF_EcsWorld.new()
	_index = GF_GridIndex.new()
	_index.setup(_world, FakePositionComponent)
	_index.miss_callback = func(gx: int, gy: int) -> void: _misses.append(Vector2i(gx, gy))
	_misses = []


func after_each() -> void:
	_world.reset()
	_world = null
	_index = null


## 生成带 marker 的实体并登记到指定格。
func _spawn_at(p_grid: Vector2i) -> int:
	var entity := _world.spawn()
	_world.add_component(entity, FakePositionComponent, FakePositionComponent.new())
	_index.register(p_grid, entity)
	return entity


# ============================================================
# 基本往返
# ============================================================


func test_register_at_has_roundtrip() -> void:
	var entity := _spawn_at(CELL_A)
	assert_eq(_index.at(CELL_A), entity)
	assert_true(_index.has(CELL_A))
	assert_false(_index.has(CELL_B), "未登记格应返回 false")
	assert_eq(_index.count(), 1)


func test_clear_resets_index() -> void:
	_spawn_at(CELL_A)
	_spawn_at(CELL_B)
	_index.clear()
	assert_eq(_index.count(), 0)
	assert_eq(_index.at(CELL_A, false), 0)


func test_one_entity_multiple_cells() -> void:
	# 矿脉形态：一实体多格，各自独立寻址、独立清理
	var entity := _world.spawn()
	_world.add_component(entity, FakePositionComponent, FakePositionComponent.new())
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]:
		_index.register(cell, entity)
	assert_eq(_index.count(), 3)
	assert_eq(_index.at(Vector2i(1, 0)), entity)

	_world.despawn(entity)
	assert_eq(_index.at(Vector2i(0, 0)), 0)
	assert_eq(_index.count(), 2, "其余格在各自被查询到时逐一清除")
	assert_eq(_index.at(Vector2i(2, 0)), 0)
	assert_eq(_index.count(), 1)


# ============================================================
# lazy eviction
# ============================================================


func test_despawned_entity_is_evicted_on_query() -> void:
	var entity := _spawn_at(CELL_A)
	_world.despawn(entity)
	assert_eq(_index.at(CELL_A), 0)
	assert_false(_index.has(CELL_A))
	assert_eq(_index.count(), 0)
	assert_true(_misses.is_empty(), "已死实体清理不应触发 miss 回调")


func test_count_keeps_dead_entry_until_queried() -> void:
	var entity := _spawn_at(CELL_A)
	_world.despawn(entity)
	assert_eq(_index.count(), 1, "未被查询触达前已死条目仍计数")
	assert_eq(_index.at(CELL_A), 0)
	assert_eq(_index.count(), 0)


func test_marker_removed_while_alive_is_evicted() -> void:
	# 实体存活但 marker 组件被移除（如树被砍成空地）→ 同样视为死
	var entity := _spawn_at(CELL_A)
	_world.remove_component(entity, FakePositionComponent)
	assert_eq(_index.at(CELL_A), 0)
	assert_eq(_index.count(), 0)


# ============================================================
# miss 回调
# ============================================================


func test_at_empty_cell_fires_miss_callback() -> void:
	assert_eq(_index.at(CELL_B), 0)
	assert_eq(_misses, [CELL_B])


func test_at_empty_cell_no_miss_when_disabled() -> void:
	assert_eq(_index.at(CELL_B, false), 0)
	assert_true(_misses.is_empty(), "只读查询不应触发 miss 回调")


func test_has_does_not_fire_miss_callback() -> void:
	_index.has(CELL_B)
	assert_true(_misses.is_empty())


# ============================================================
# 显式注销（建筑拆除语义）
# ============================================================


func test_unregister_makes_cell_available_immediately() -> void:
	var entity := _spawn_at(CELL_A)
	_index.unregister(CELL_A)
	assert_eq(_index.at(CELL_A, false), 0, "实体仍存活也应返回空")

	var replacement := _spawn_at(CELL_A)
	assert_eq(_index.at(CELL_A), replacement, "注销后该格可立即再占用")


func test_unregister_then_query_fires_miss() -> void:
	# 注销后的空格按普通未命中处理（含 miss 回调）——
	# 门面层的条件回调保证 chunk 已生成时不重复请求
	_spawn_at(CELL_A)
	_index.unregister(CELL_A)
	assert_eq(_index.at(CELL_A), 0)
	assert_eq(_misses, [CELL_A])


# ============================================================
# 漂移防护
# ============================================================


func test_duplicate_register_warns_and_is_ignored() -> void:
	var first := _spawn_at(CELL_A)
	var second := _spawn_at(CELL_B)
	_index.register(CELL_A, second)
	assert_push_warning_count(1)
	assert_eq(_index.at(CELL_A), first, "重复 register 不应覆盖已有条目")


func test_unregister_absent_cell_warns() -> void:
	_index.unregister(CELL_B)
	assert_push_warning_count(1)
