# tests/helpers/spatial_index_test_utils.gd
## 测试辅助：空间索引暴力扫描对拍工具。
## 暴力实现与索引实现必须使用相同规则：
## - rect 查询：Rect2.intersects(include_borders = true)
## - nearest 查询：按包围盒中心距离升序，平手按 entity 升序
class_name SpatialIndexTestUtils
extends RefCounted


## 暴力范围查询：遍历所有条目与矩形相交判定。
static func brute_rect(p_entries: Dictionary, p_rect: Rect2) -> Array[int]:
	var result: Array[int] = []
	for entity in p_entries:
		var bounds: Rect2 = p_entries[entity]
		if bounds.intersects(p_rect, true):
			result.append(entity)
	result.sort()
	return result


## 暴力最近邻：按包围盒中心距离排序，取前 p_count 个。
static func brute_nearest(p_entries: Dictionary, p_point: Vector2, p_count: int) -> Array[int]:
	var candidates: Array = []
	for entity in p_entries:
		var bounds: Rect2 = p_entries[entity]
		candidates.append({"entity": entity, "dist_sq": bounds.get_center().distance_squared_to(p_point)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.dist_sq != b.dist_sq:
			return a.dist_sq < b.dist_sq
		return a.entity < b.entity)
	var result: Array[int] = []
	for i in range(mini(p_count, candidates.size())):
		result.append(candidates[i].entity)
	return result


## 对拍：随机 rect / nearest 查询与暴力扫描结果一致。
## p_entries 为测试侧维护的条目镜像 {entity: Rect2}。
static func assert_queries_match(p_test, p_index: GF_ISpatialIndex, p_entries: Dictionary, p_rng: RandomNumberGenerator, p_rounds: int) -> void:
	for round in range(p_rounds):
		var q_rect := random_bounds(p_rng, 2000.0)
		var expected_rect := brute_rect(p_entries, q_rect)
		var actual_rect := p_index.query_rect(q_rect)
		actual_rect.sort()
		p_test.assert_eq(actual_rect, expected_rect, "round %d: query_rect 与暴力扫描不一致" % round)

		var q_point := random_point(p_rng, 3000.0)
		var q_count := p_rng.randi_range(1, 12)
		var expected_near := brute_nearest(p_entries, q_point, q_count)
		var actual_near := p_index.query_nearest(q_point, q_count)
		p_test.assert_eq(actual_near, expected_near, "round %d: query_nearest 与暴力扫描不一致" % round)


## 生成随机包围盒（位置散布 ±p_spread，尺寸 1~50）。
static func random_bounds(p_rng: RandomNumberGenerator, p_spread: float) -> Rect2:
	return Rect2(random_point(p_rng, p_spread), Vector2(p_rng.randf_range(1.0, 50.0), p_rng.randf_range(1.0, 50.0)))


## 生成随机点（坐标散布 ±p_spread）。
static func random_point(p_rng: RandomNumberGenerator, p_spread: float) -> Vector2:
	return Vector2(p_rng.randf_range(-p_spread, p_spread), p_rng.randf_range(-p_spread, p_spread))
