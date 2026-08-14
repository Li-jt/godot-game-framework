## GF_KDTreeSpatialIndex — KD 树空间索引（全量重建模式）。
## 适用场景：实体大多在移动、总量不大（推荐 ≤ 2000）——怪物群、动物群。
##
## 设计：
## - 树按实体 AABB 中心点沿 x/y 轴交替中位数分割构建，节点保存子树合并 AABB 用于查询剪枝。
## - insert/update/remove 只修改条目镜像并标记 dirty，下一次查询前惰性重建（O(N log N)）。
## - 配合 GF_SpatialIndexSyncSystem 时开启 rebuild_every_sync，
##   重建在同步 tick 内显式执行，查询路径零额外成本。
## - 与增量维护的 GF_RStarSpatialIndex 相比：无节点分裂/下溢逻辑，结构紧致、
##   查询快；代价是不支持廉价增量更新，逐实体增删改不即时反映到树结构。
class_name GF_KDTreeSpatialIndex
extends GF_ISpatialIndex

const AXIS_X := 0
const AXIS_Y := 1

var _entries: Dictionary = {}  # {int entity: Rect2 bounds}
var _nodes: Array = []         # Array[_Node]，整数索引互链
var _root: int = -1
var _dirty: bool = false


func insert(p_entity: int, p_bounds: Rect2) -> void:
	if _entries.has(p_entity):
		push_warning("[GF_KDTreeSpatialIndex] insert 已存在的实体 %d，索引与 ECS 状态漂移" % p_entity)
		return
	_entries[p_entity] = p_bounds
	_dirty = true


func update(p_entity: int, p_new_bounds: Rect2) -> void:
	if not _entries.has(p_entity):
		push_warning("[GF_KDTreeSpatialIndex] update 不存在的实体 %d，索引与 ECS 状态漂移" % p_entity)
		return
	_entries[p_entity] = p_new_bounds
	_dirty = true


func remove(p_entity: int) -> void:
	if not _entries.has(p_entity):
		push_warning("[GF_KDTreeSpatialIndex] remove 不存在的实体 %d，索引与 ECS 状态漂移" % p_entity)
		return
	_entries.erase(p_entity)
	_dirty = true


func clear() -> void:
	_entries.clear()
	_nodes.clear()
	_root = -1
	_dirty = false


func rebuild(p_entries: Dictionary) -> void:
	_entries = p_entries.duplicate()
	_build_tree()


func query_rect(p_rect: Rect2) -> Array[int]:
	_ensure_tree()
	var result: Array[int] = []
	_query_rect_recursive(_root, p_rect, result)
	return result


func query_nearest(p_point: Vector2, p_count: int) -> Array[int]:
	_ensure_tree()
	if p_count <= 0 or _root < 0:
		return []
	var candidates: Array = []
	_nearest_recursive(_root, p_point, p_count, candidates, INF)
	sort_candidates(candidates)
	var result: Array[int] = []
	for c in candidates:
		result.append(c.entity)
	return result


func count() -> int:
	return _entries.size()


func has_entity(p_entity: int) -> bool:
	return _entries.has(p_entity)


# ============================================================
# 内部实现
# ============================================================


func _ensure_tree() -> void:
	if _dirty:
		_build_tree()


func _build_tree() -> void:
	_nodes.clear()
	_root = -1
	if _entries.is_empty():
		_dirty = false
		return
	var items: Array = []
	for entity in _entries:
		items.append({"entity": entity, "bounds": _entries[entity]})
	_root = _build_recursive(items, AXIS_X)
	_dirty = false


func _build_recursive(p_items: Array, p_axis: int) -> int:
	if p_items.is_empty():
		return -1
	if p_items.size() == 1:
		var only: Dictionary = p_items[0]
		var node := _Node.new(only.bounds, only.entity)
		_nodes.append(node)
		return _nodes.size() - 1

	# 按当前轴的中心坐标排序取中位数
	var axis_pos := 0 if p_axis == AXIS_X else 1
	p_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return rect_center(a.bounds)[axis_pos] < rect_center(b.bounds)[axis_pos])

	var mid := p_items.size() / 2
	var mid_item: Dictionary = p_items[mid]
	var node := _Node.new(mid_item.bounds, mid_item.entity)
	var node_idx := _nodes.size()
	_nodes.append(node)
	var next_axis := AXIS_Y if p_axis == AXIS_X else AXIS_X
	node.left = _build_recursive(p_items.slice(0, mid), next_axis)
	node.right = _build_recursive(p_items.slice(mid + 1), next_axis)

	# 合并子树 AABB 用于查询剪枝
	if node.left >= 0:
		node.bounds = node.bounds.merge(_nodes[node.left].bounds)
	if node.right >= 0:
		node.bounds = node.bounds.merge(_nodes[node.right].bounds)
	_nodes[node_idx] = node
	return node_idx


func _query_rect_recursive(p_idx: int, p_rect: Rect2, p_result: Array[int]) -> void:
	if p_idx < 0:
		return
	var node: _Node = _nodes[p_idx]
	# 节点 bounds 是子树合并框，只能剪枝不能判定
	if not node.bounds.intersects(p_rect, true):
		return
	# 实体自身 bounds 精确判定
	if _entries.get(node.entity, Rect2()).intersects(p_rect, true):
		p_result.append(node.entity)
	_query_rect_recursive(node.left, p_rect, p_result)
	_query_rect_recursive(node.right, p_rect, p_result)


## 返回更新后的最远候选距离平方（值类型传参，需回传）。
func _nearest_recursive(p_idx: int, p_point: Vector2, p_count: int, p_candidates: Array, p_best_dist_sq: float) -> float:
	if p_idx < 0:
		return p_best_dist_sq
	var node: _Node = _nodes[p_idx]
	# 剪枝：子树包围盒到查询点的最小距离已超过第 k 远候选
	if p_candidates.size() >= p_count and rect_min_dist_sq(node.bounds, p_point) > p_best_dist_sq:
		return p_best_dist_sq

	var entity_bounds: Rect2 = _entries.get(node.entity, Rect2())
	var dist_sq := rect_center(entity_bounds).distance_squared_to(p_point)
	push_candidate(p_candidates, node.entity, dist_sq, p_count)
	if p_candidates.size() == p_count:
		p_best_dist_sq = worst_dist_sq(p_candidates)

	# 先访问更近的子树，加速剪枝
	var left_d := rect_min_dist_sq(_nodes[node.left].bounds, p_point) if node.left >= 0 else INF
	var right_d := rect_min_dist_sq(_nodes[node.right].bounds, p_point) if node.right >= 0 else INF
	if left_d <= right_d:
		p_best_dist_sq = _nearest_recursive(node.left, p_point, p_count, p_candidates, p_best_dist_sq)
		p_best_dist_sq = _nearest_recursive(node.right, p_point, p_count, p_candidates, p_best_dist_sq)
	else:
		p_best_dist_sq = _nearest_recursive(node.right, p_point, p_count, p_candidates, p_best_dist_sq)
		p_best_dist_sq = _nearest_recursive(node.left, p_point, p_count, p_candidates, p_best_dist_sq)
	return p_best_dist_sq


# ============================================================
# 内部类
# ============================================================


class _Node:
	var bounds: Rect2
	var entity: int = 0
	var left: int = -1
	var right: int = -1

	func _init(p_bounds: Rect2, p_entity: int) -> void:
		bounds = p_bounds
		entity = p_entity
