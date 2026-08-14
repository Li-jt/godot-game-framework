## GF_RStarSpatialIndex — R* 树空间索引（增量更新模式）。
## 适用场景：大部分静态 + 少量移动的混合场景——建筑 + 少数动物。
##
## 实现要点：
## - ChooseSubtree 最小面积增长 + QuadraticSplit 节点分裂，页大小 MAX_ENTRIES。
## - R* 核心改进 forced reinsertion：叶层溢出时不立即分裂，先把中心距离最远的
##   REINSERT_COUNT 个条目从根重插（单次插入传播中每层限一次），再次溢出才分裂——
##   这是 R* 优于标准 R-tree 的全部秘密。内部层溢出直接分裂（KISS 取舍，
##   内部层重插需子树重挂逻辑、收益低）。
## - update = remove + insert；remove 后节点下溢走 condense 回收（下溢节点
##   展开为数据条目重插），防止树退化。
## - 变化实体比例过高时由 GF_SpatialIndexSyncSystem 的阈值退化路径触发整体重建。
class_name GF_RStarSpatialIndex
extends GF_ISpatialIndex

const MAX_ENTRIES := 8
const MIN_ENTRIES := 3
const REINSERT_COUNT := 3

var _root: _RNode = null
var _entity_bounds: Dictionary = {}  # {int entity: Rect2 bounds}，与树内条目同步
var _reinserted_levels: Dictionary = {}  # {int level: bool}，单次插入传播中每层至多重插一次


func insert(p_entity: int, p_bounds: Rect2) -> void:
	if _entity_bounds.has(p_entity):
		push_warning("[GF_RStarSpatialIndex] insert 已存在的实体 %d，索引与 ECS 状态漂移" % p_entity)
		return
	_entity_bounds[p_entity] = p_bounds
	_reinserted_levels.clear()
	_insert_entry({"entity": p_entity, "bounds": p_bounds})


func update(p_entity: int, p_new_bounds: Rect2) -> void:
	if not _entity_bounds.has(p_entity):
		push_warning("[GF_RStarSpatialIndex] update 不存在的实体 %d，索引与 ECS 状态漂移" % p_entity)
		return
	remove(p_entity)
	insert(p_entity, p_new_bounds)


func remove(p_entity: int) -> void:
	if not _entity_bounds.has(p_entity):
		push_warning("[GF_RStarSpatialIndex] remove 不存在的实体 %d，索引与 ECS 状态漂移" % p_entity)
		return
	var bounds: Rect2 = _entity_bounds[p_entity]
	_entity_bounds.erase(p_entity)
	_reinserted_levels.clear()
	if _root == null:
		return

	var orphans: Array = []
	_remove_recursive(_root, p_entity, bounds, orphans)

	# 根收缩：内部根只剩一个子节点时降级；空根清空
	while _root != null and not _root.is_leaf and _root.entries.size() == 1:
		_root = _root.entries[0].child
	if _root != null and _root.entries.is_empty():
		_root = null

	# condense 收集的孤儿条目重插
	for entry in orphans:
		_insert_entry(entry)


func clear() -> void:
	_root = null
	_entity_bounds.clear()
	_reinserted_levels.clear()


func rebuild(p_entries: Dictionary) -> void:
	clear()
	_entity_bounds = p_entries.duplicate()
	_reinserted_levels.clear()
	for entity in _entity_bounds:
		_insert_entry({"entity": entity, "bounds": _entity_bounds[entity]})


func query_rect(p_rect: Rect2) -> Array[int]:
	var result: Array[int] = []
	if _root != null:
		_query_rect_recursive(_root, p_rect, result)
	return result


func query_nearest(p_point: Vector2, p_count: int) -> Array[int]:
	if p_count <= 0 or _root == null:
		return []
	var candidates: Array = []
	_nearest_recursive(_root, p_point, p_count, candidates, INF)
	sort_candidates(candidates)
	var result: Array[int] = []
	for c in candidates:
		result.append(c.entity)
	return result


func count() -> int:
	return _entity_bounds.size()


func has_entity(p_entity: int) -> bool:
	return _entity_bounds.has(p_entity)


# ============================================================
# 插入路径
# ============================================================


## 插入数据条目（孤儿重插、reinsert 共用入口，不做查重与计数）。
## 注意：不在此处清空 _reinserted_levels——forced reinsertion 的条目
## 从根重插必须保留层级标记，否则重插条目再次填满节点时同层反复
## reinsert 形成递归风暴。标记只在顶层公开操作入口（insert/rebuild/remove）清除。
func _insert_entry(p_entry: Dictionary) -> void:
	if _root == null:
		_root = _RNode.new(true)
		_root.entries.append(p_entry)
		_root.bounds = p_entry.bounds
		return
	var split_node := _insert_recursive(_root, p_entry, 0)
	if split_node != null:
		_root = _make_new_root(_root, split_node)


## 递归插入，返回分裂出的新节点（无分裂返回 null）。
func _insert_recursive(p_node: _RNode, p_entry: Dictionary, p_level: int) -> _RNode:
	if p_node.is_leaf:
		p_node.entries.append(p_entry)
	else:
		var target: _RNode = _choose_subtree(p_node, p_entry.bounds)
		var split_node := _insert_recursive(target, p_entry, p_level + 1)
		# 同步 target 的 bounds 快照：子节点插入/分裂后 bounds 已变化，
		# 父节点的 entry.bounds 是值快照必须显式刷新，否则父 bounds 计算
		# 陈旧 → 查询剪枝错误（R-tree 经典陷阱）
		for entry in p_node.entries:
			if entry.child == target:
				entry.bounds = target.bounds
				break
		if split_node != null:
			p_node.entries.append({"child": split_node, "bounds": split_node.bounds})

	if p_node.entries.size() > MAX_ENTRIES:
		var split := _handle_overflow(p_node, p_level)
		if split != null:
			return split
	p_node.bounds = _compute_bounds(p_node)
	return null


## 选择面积增长最小的子节点（平手取面积小者）。
func _choose_subtree(p_node: _RNode, p_bounds: Rect2) -> _RNode:
	var best_child: _RNode = null
	var best_growth := INF
	var best_area := INF
	for entry in p_node.entries:
		var merged: Rect2 = entry.bounds.merge(p_bounds)
		var growth: float = merged.get_area() - float(entry.bounds.get_area())
		if growth < best_growth or (is_equal_approx(growth, best_growth) and entry.bounds.get_area() < best_area):
			best_child = entry.child
			best_growth = growth
			best_area = entry.bounds.get_area()
	return best_child


## 溢出处理：叶层首次溢出走 forced reinsertion，否则分裂。
func _handle_overflow(p_node: _RNode, p_level: int) -> _RNode:
	if p_node.is_leaf and not _reinserted_levels.has(p_level):
		_reinserted_levels[p_level] = true
		_reinsert_far_entries(p_node)
		return null
	return _quadratic_split(p_node)


## 叶层 forced reinsertion：挑中心距离最远的 REINSERT_COUNT 个条目从根重插。
func _reinsert_far_entries(p_node: _RNode) -> void:
	var center := rect_center(p_node.bounds)
	var sorted: Array = p_node.entries.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return rect_center(a.bounds).distance_squared_to(center) > rect_center(b.bounds).distance_squared_to(center))
	var removed: Array = []
	for i in range(REINSERT_COUNT):
		var entry: Dictionary = sorted[i]
		p_node.entries.erase(entry)
		removed.append(entry)
	p_node.bounds = _compute_bounds(p_node)
	for entry in removed:
		_insert_entry(entry)


## QuadraticSplit：返回新节点（p_node 保留 group_a，新节点持有 group_b）。
func _quadratic_split(p_node: _RNode) -> _RNode:
	var entries: Array = p_node.entries

	# 1. 种子对：合并面积浪费最大
	var seed_a := 0
	var seed_b := 1
	var worst_waste := -INF
	for i in range(entries.size()):
		for j in range(i + 1, entries.size()):
			var waste: float = float(entries[i].bounds.merge(entries[j].bounds).get_area()) \
				- float(entries[i].bounds.get_area()) - float(entries[j].bounds.get_area())
			if waste > worst_waste:
				worst_waste = waste
				seed_a = i
				seed_b = j

	var group_a: Array = [entries[seed_a]]
	var group_b: Array = [entries[seed_b]]
	var bounds_a: Rect2 = entries[seed_a].bounds
	var bounds_b: Rect2 = entries[seed_b].bounds

	# 2. 剩余条目按「两组面积增长差」分配
	var remaining: Array = []
	for i in range(entries.size()):
		if i != seed_a and i != seed_b:
			remaining.append(entries[i])
	while not remaining.is_empty():
		# 组过小时直接补齐，防止 MIN_ENTRIES 下溢
		if group_a.size() + remaining.size() <= MIN_ENTRIES:
			for entry in remaining:
				group_a.append(entry)
				bounds_a = bounds_a.merge(entry.bounds)
			remaining.clear()
			break
		if group_b.size() + remaining.size() <= MIN_ENTRIES:
			for entry in remaining:
				group_b.append(entry)
				bounds_b = bounds_b.merge(entry.bounds)
			remaining.clear()
			break
		# 选「加入两组面积增长差」最大的条目
		var best_idx := 0
		var best_diff := -INF
		for i in range(remaining.size()):
			var growth_a := bounds_a.merge(remaining[i].bounds).get_area() - bounds_a.get_area()
			var growth_b := bounds_b.merge(remaining[i].bounds).get_area() - bounds_b.get_area()
			var diff := absf(growth_a - growth_b)
			if diff > best_diff:
				best_diff = diff
				best_idx = i
		# 分配给增长较小的一组（平手：面积小者）
		var entry: Dictionary = remaining[best_idx]
		remaining.remove_at(best_idx)
		var growth_a := bounds_a.merge(entry.bounds).get_area() - bounds_a.get_area()
		var growth_b := bounds_b.merge(entry.bounds).get_area() - bounds_b.get_area()
		if growth_a < growth_b or (is_equal_approx(growth_a, growth_b) and bounds_a.get_area() <= bounds_b.get_area()):
			group_a.append(entry)
			bounds_a = bounds_a.merge(entry.bounds)
		else:
			group_b.append(entry)
			bounds_b = bounds_b.merge(entry.bounds)

	# 3. 重装节点
	p_node.entries = group_a
	p_node.bounds = bounds_a
	var new_node := _RNode.new(p_node.is_leaf)
	new_node.entries = group_b
	new_node.bounds = bounds_b
	return new_node


func _make_new_root(p_left: _RNode, p_right: _RNode) -> _RNode:
	var new_root := _RNode.new(false)
	new_root.entries.append({"child": p_left, "bounds": p_left.bounds})
	new_root.entries.append({"child": p_right, "bounds": p_right.bounds})
	new_root.bounds = p_left.bounds.merge(p_right.bounds)
	return new_root


# ============================================================
# 删除路径（condense）
# ============================================================


## 递归定位并删除叶条目；下溢节点展开为数据条目进 p_orphans。
func _remove_recursive(p_node: _RNode, p_entity: int, p_bounds: Rect2, p_orphans: Array) -> void:
	if p_node.is_leaf:
		for i in range(p_node.entries.size()):
			if p_node.entries[i].entity == p_entity:
				p_node.entries.remove_at(i)
				break
		p_node.bounds = _compute_bounds(p_node)
		return

	var to_remove: Array = []
	for entry in p_node.entries:
		if not entry.bounds.intersects(p_bounds, true):
			continue
		var child: _RNode = entry.child
		_remove_recursive(child, p_entity, p_bounds, p_orphans)
		if child.entries.size() < MIN_ENTRIES:
			_expand_leaf_entries(child, p_orphans)
			to_remove.append(entry)
		else:
			entry.bounds = child.bounds  # 同步删除收缩后的快照
	for entry in to_remove:
		p_node.entries.erase(entry)
	p_node.bounds = _compute_bounds(p_node)


## 递归展开节点为数据条目（condense 孤儿回收用）。
func _expand_leaf_entries(p_node: _RNode, p_out: Array) -> void:
	if p_node.is_leaf:
		for entry in p_node.entries:
			p_out.append(entry)
		return
	for entry in p_node.entries:
		_expand_leaf_entries(entry.child, p_out)


# ============================================================
# 查询路径
# ============================================================


func _query_rect_recursive(p_node: _RNode, p_rect: Rect2, p_result: Array[int]) -> void:
	if not p_node.bounds.intersects(p_rect, true):
		return
	if p_node.is_leaf:
		for entry in p_node.entries:
			if entry.bounds.intersects(p_rect, true):
				p_result.append(entry.entity)
		return
	for entry in p_node.entries:
		_query_rect_recursive(entry.child, p_rect, p_result)


## 返回更新后的最远候选距离平方（值类型传参，需回传）。
func _nearest_recursive(p_node: _RNode, p_point: Vector2, p_count: int, p_candidates: Array, p_best_dist_sq: float) -> float:
	# 剪枝：节点包围盒到查询点的最小距离已超过第 k 远候选
	if p_candidates.size() >= p_count and rect_min_dist_sq(p_node.bounds, p_point) > p_best_dist_sq:
		return p_best_dist_sq
	if p_node.is_leaf:
		for entry in p_node.entries:
			var center: Vector2 = rect_center(entry.bounds)
			var dist_sq := center.distance_squared_to(p_point)
			# 候选已满且本条目不更近时跳过 append（平手必须入候选，
			# 暴力排序平手按 entity 升序，相等距离可能挤出当前第 k 远）
			if p_candidates.size() >= p_count and dist_sq > p_best_dist_sq:
				continue
			push_candidate(p_candidates, entry.entity, dist_sq, p_count)
			if p_candidates.size() == p_count:
				p_best_dist_sq = worst_dist_sq(p_candidates)
		return p_best_dist_sq
	# 内部节点：按包围盒最小距离升序访问，加速剪枝
	var ordered: Array = p_node.entries.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return rect_min_dist_sq(a.bounds, p_point) < rect_min_dist_sq(b.bounds, p_point))
	for entry in ordered:
		p_best_dist_sq = _nearest_recursive(entry.child, p_point, p_count, p_candidates, p_best_dist_sq)
	return p_best_dist_sq


# ============================================================
# 内部工具
# ============================================================


## 重算节点合并包围盒（entries 为空时返回零尺寸矩形）。
func _compute_bounds(p_node: _RNode) -> Rect2:
	if p_node.entries.is_empty():
		return Rect2()
	var result: Rect2 = p_node.entries[0].bounds
	for i in range(1, p_node.entries.size()):
		result = result.merge(p_node.entries[i].bounds)
	return result


# ============================================================
# 内部类
# ============================================================


class _RNode:
	var is_leaf: bool = true
	var bounds: Rect2
	## 叶层: {entity: int, bounds: Rect2}；内部层: {child: _RNode, bounds: Rect2}
	var entries: Array = []

	func _init(p_leaf: bool = true) -> void:
		is_leaf = p_leaf
