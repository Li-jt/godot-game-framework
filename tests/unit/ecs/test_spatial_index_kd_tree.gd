# tests/unit/ecs/test_spatial_index_kd_tree.gd
## GF_KDTreeSpatialIndex 单元测试：
## 往返、惰性重建、随机对拍、不一致漂移防护。
extends GutTest

const RNG_SEED := 12345

var _index: GF_KDTreeSpatialIndex
var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_index = GF_KDTreeSpatialIndex.new()
	_rng.seed = RNG_SEED


# ============================================================
# 基本往返
# ============================================================


func test_insert_update_remove_roundtrip() -> void:
	_index.insert(1, Rect2(10, 10, 4, 4))
	_index.insert(2, Rect2(100, 100, 6, 6))
	assert_eq(_index.count(), 2)
	assert_true(_index.has_entity(1))
	assert_true(_index.has_entity(2))
	assert_false(_index.has_entity(99))

	# update 后旧位置查不到、新位置查得到
	_index.update(1, Rect2(200, 200, 4, 4))
	assert_eq(_index.query_rect(Rect2(8, 8, 8, 8)), [])
	assert_eq(_index.query_rect(Rect2(195, 195, 20, 20)), [1])

	# remove 后消失
	_index.remove(1)
	assert_false(_index.has_entity(1))
	assert_eq(_index.count(), 1)


func test_clear_and_rebuild() -> void:
	_index.insert(1, Rect2(0, 0, 10, 10))
	_index.insert(2, Rect2(50, 50, 10, 10))
	_index.clear()
	assert_eq(_index.count(), 0)
	assert_true(_index.query_rect(Rect2(-100, -100, 1000, 1000)).is_empty())

	_index.rebuild({3: Rect2(-5, -5, 2, 2), 4: Rect2(90, 90, 2, 2)})
	assert_eq(_index.count(), 2)
	assert_true(_index.has_entity(3))
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
	assert_eq(_index.query_nearest(Vector2.ZERO, 0), [], "p_count <= 0 返回空")


# ============================================================
# 不一致漂移防护（push_warning + 行为忽略）
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
	# Arrange：200 个随机实体
	var entries: Dictionary = {}
	for i in range(200):
		var entity := i + 1
		var bounds := SpatialIndexTestUtils.random_bounds(_rng, 2000.0)
		entries[entity] = bounds
		_index.insert(entity, bounds)

	# Act / Assert：100 轮随机查询对拍
	SpatialIndexTestUtils.assert_queries_match(self, _index, entries, _rng, 100)


func test_lazy_rebuild_after_inserts() -> void:
	# insert 后不显式 rebuild，查询前应惰性重建
	var entries: Dictionary = {}
	for i in range(100):
		var entity := i + 1
		var bounds := SpatialIndexTestUtils.random_bounds(_rng, 500.0)
		entries[entity] = bounds
		_index.insert(entity, bounds)

	assert_eq(_index.count(), 100)
	SpatialIndexTestUtils.assert_queries_match(self, _index, entries, _rng, 30)

	# 部分 update / remove 后再查询，仍应一致
	for entity in [1, 2, 3, 4, 5]:
		entries[entity] = SpatialIndexTestUtils.random_bounds(_rng, 500.0)
		_index.update(entity, entries[entity])
	for entity in [10, 20, 30]:
		entries.erase(entity)
		_index.remove(entity)
	SpatialIndexTestUtils.assert_queries_match(self, _index, entries, _rng, 30)


func test_mixed_random_operations_match_brute_force() -> void:
	# 混合随机 insert/update/remove 后对拍（惰性重建 + 镜像一致性）
	var entries: Dictionary = {}
	var next_id := 1
	for step in range(60):
		var op := _rng.randi_range(0, 9)
		if op < 4 and entries.size() < 100:
			# insert 新实体
			entries[next_id] = SpatialIndexTestUtils.random_bounds(_rng, 800.0)
			_index.insert(next_id, entries[next_id])
			next_id += 1
		elif op < 8 and not entries.is_empty():
			# update 随机实体
			var keys := entries.keys()
			var entity: int = keys[_rng.randi_range(0, keys.size() - 1)]
			entries[entity] = SpatialIndexTestUtils.random_bounds(_rng, 800.0)
			_index.update(entity, entries[entity])
		elif not entries.is_empty():
			# remove 随机实体
			var keys := entries.keys()
			var entity: int = keys[_rng.randi_range(0, keys.size() - 1)]
			entries.erase(entity)
			_index.remove(entity)

		if (step + 1) % 10 == 0:
			SpatialIndexTestUtils.assert_queries_match(self, _index, entries, _rng, 5)
