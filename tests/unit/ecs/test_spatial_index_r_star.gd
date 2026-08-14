# tests/unit/ecs/test_spatial_index_r_star.gd
## GF_RStarSpatialIndex 单元测试：
## 往返、增量维护对拍（覆盖分裂/forced reinsertion/condense）、漂移防护。
extends GutTest

const RNG_SEED := 54321

var _index: GF_RStarSpatialIndex
var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_index = GF_RStarSpatialIndex.new()
	_rng.seed = RNG_SEED


# ============================================================
# 基本往返
# ============================================================


func test_insert_update_remove_roundtrip() -> void:
	_index.insert(1, Rect2(10, 10, 4, 4))
	_index.insert(2, Rect2(100, 100, 6, 6))
	assert_eq(_index.count(), 2)
	assert_true(_index.has_entity(1))
	assert_false(_index.has_entity(99))

	_index.update(1, Rect2(200, 200, 4, 4))
	assert_eq(_index.query_rect(Rect2(8, 8, 8, 8)), [])
	assert_eq(_index.query_rect(Rect2(195, 195, 20, 20)), [1])

	_index.remove(1)
	assert_false(_index.has_entity(1))
	assert_eq(_index.count(), 1)
	assert_eq(_index.query_rect(Rect2(195, 195, 20, 20)), [])


func test_clear_and_rebuild() -> void:
	_index.insert(1, Rect2(0, 0, 10, 10))
	_index.insert(2, Rect2(50, 50, 10, 10))
	_index.clear()
	assert_eq(_index.count(), 0)
	assert_true(_index.query_rect(Rect2(-100, -100, 1000, 1000)).is_empty())

	_index.rebuild({3: Rect2(-5, -5, 2, 2), 4: Rect2(90, 90, 2, 2)})
	assert_eq(_index.count(), 2)
	assert_eq(_index.query_rect(Rect2(-10, -10, 10, 10)), [3])
	assert_eq(_index.query_rect(Rect2(85, 85, 10, 10)), [4])


func test_nearest_returns_sorted_and_limited() -> void:
	_index.rebuild({
		1: Rect2(0, 0, 4, 4),
		2: Rect2(100, 0, 4, 4),
		3: Rect2(0, 50, 4, 4),
		4: Rect2(10, 10, 4, 4),
	})
	var result := _index.query_nearest(Vector2.ZERO, 2)
	assert_eq(result.size(), 2)
	assert_eq(result[0], 1, "最近应为实体 1")
	assert_eq(result[1], 4, "次近应为实体 4")


func test_query_empty_index() -> void:
	assert_eq(_index.query_rect(Rect2(-1000, -1000, 2000, 2000)), [])
	assert_eq(_index.query_nearest(Vector2.ZERO, 5), [])


# ============================================================
# 不一致漂移防护
# ============================================================


func test_duplicate_insert_is_ignored() -> void:
	_index.insert(1, Rect2(0, 0, 10, 10))
	_index.insert(1, Rect2(500, 500, 10, 10))
	assert_push_warning_count(1)
	assert_eq(_index.count(), 1)
	assert_eq(_index.query_rect(Rect2(495, 495, 20, 20)), [], "重复 insert 不应覆盖已有条目")


func test_update_missing_entity_is_ignored() -> void:
	_index.update(42, Rect2(0, 0, 10, 10))
	assert_push_warning_count(1)
	assert_eq(_index.count(), 0)


func test_remove_missing_entity_is_ignored() -> void:
	_index.insert(1, Rect2(0, 0, 10, 10))
	_index.remove(42)
	assert_push_warning_count(1)
	assert_eq(_index.count(), 1)


# ============================================================
# 随机对拍
# ============================================================


func test_queries_match_brute_force_randomized() -> void:
	# 200 个随机实体批量 rebuild 后对拍
	var entries: Dictionary = {}
	for i in range(200):
		var entity := i + 1
		var bounds := SpatialIndexTestUtils.random_bounds(_rng, 2000.0)
		entries[entity] = bounds
	_index.rebuild(entries)
	SpatialIndexTestUtils.assert_queries_match(self, _index, entries, _rng, 100)


func test_incremental_ops_match_brute_force() -> void:
	# 增量 insert/update/remove 混合 100 步，每 10 步对拍。
	# 覆盖：节点分裂、叶层 forced reinsertion、remove condense 下溢回收。
	var entries: Dictionary = {}
	var next_id := 1
	for step in range(100):
		var op := _rng.randi_range(0, 9)
		if op < 4 and entries.size() < 120:
			entries[next_id] = SpatialIndexTestUtils.random_bounds(_rng, 1500.0)
			_index.insert(next_id, entries[next_id])
			next_id += 1
		elif op < 8 and not entries.is_empty():
			var keys := entries.keys()
			var entity: int = keys[_rng.randi_range(0, keys.size() - 1)]
			entries[entity] = SpatialIndexTestUtils.random_bounds(_rng, 1500.0)
			_index.update(entity, entries[entity])
		elif not entries.is_empty():
			var keys := entries.keys()
			var entity: int = keys[_rng.randi_range(0, keys.size() - 1)]
			entries.erase(entity)
			_index.remove(entity)

		if (step + 1) % 10 == 0:
			SpatialIndexTestUtils.assert_queries_match(self, _index, entries, _rng, 5)


func test_mass_remove_condenses_underflow() -> void:
	# 大量删除触发连锁下溢与根收缩，树仍需保持正确
	var entries: Dictionary = {}
	for i in range(150):
		entries[i + 1] = SpatialIndexTestUtils.random_bounds(_rng, 2000.0)
	_index.rebuild(entries)

	var to_remove: Array = []
	for entity in entries:
		to_remove.append(entity)
	to_remove.shuffle()  # shuffle 无种子，顺序随机即可——测试只关心正确性

	for entity in to_remove.slice(0, 140):
		entries.erase(entity)
		_index.remove(entity)
	SpatialIndexTestUtils.assert_queries_match(self, _index, entries, _rng, 30)
	assert_eq(_index.count(), 10)


func test_remove_until_empty() -> void:
	_index.rebuild({
		1: Rect2(0, 0, 4, 4),
		2: Rect2(10, 10, 4, 4),
		3: Rect2(20, 20, 4, 4),
	})
	_index.remove(1)
	_index.remove(2)
	_index.remove(3)
	assert_eq(_index.count(), 0)
	assert_eq(_index.query_rect(Rect2(-100, -100, 1000, 1000)), [])
	# 空树后继续 insert 应正常工作
	_index.insert(9, Rect2(0, 0, 4, 4))
	assert_eq(_index.query_rect(Rect2(0, 0, 4, 4)), [9])
