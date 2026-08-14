## GF_ISpatialIndex — 空间索引接口（2D AABB）。
## 纯内存结构，RefCounted，不继承 GF_ModuleLifecycle——
## 与 modules/algorithm 的 A* 同一定位：纯数据结构，不参与 Bootstrap 装配。
##
## 对框架 CLAUDE.md §6「公共 API 返回 OperationResult」的豁免说明：
## - query_rect / query_nearest 返回 Array[int]：空结果是合法查询结果，不是失败。
## - insert / update / remove 返回 void：纯内存索引无 I/O、无资源竞争，
##   这些操作唯一的失败形态是「索引与 ECS 世界状态漂移」（重复 insert、
##   悬空 update/remove）——这属于框架使用错误而非运行时业务失败，
##   由实现类用 push_warning 暴露（CLAUDE.md §16.1 不静默吞错误）。
##
## 索引只存实体句柄（entity id），不存组件数据副本——组件是唯一数据源。
## 同步周期内 despawn 的实体会以陈旧句柄形式短暂留存于索引，
## 调用方必须用 world.has_entity() 过滤查询结果后再使用。
class_name GF_ISpatialIndex
extends RefCounted


## 插入实体包围盒。已存在的实体视为索引与 ECS 状态漂移。
func insert(p_entity: int, p_bounds: Rect2) -> void:
	push_error("GF_ISpatialIndex.insert() 必须由子类实现")


## 更新实体包围盒。不存在的实体视为索引与 ECS 状态漂移。
func update(p_entity: int, p_new_bounds: Rect2) -> void:
	push_error("GF_ISpatialIndex.update() 必须由子类实现")


## 移除实体。不存在的实体视为索引与 ECS 状态漂移。
func remove(p_entity: int) -> void:
	push_error("GF_ISpatialIndex.remove() 必须由子类实现")


## 清空全部条目。
func clear() -> void:
	push_error("GF_ISpatialIndex.clear() 必须由子类实现")


## 用给定条目集整体重建索引。p_entries 形如 {entity: Rect2}。
## GF_SpatialIndexSyncSystem 的全量重建模式与阈值退化路径调用此方法。
func rebuild(p_entries: Dictionary) -> void:
	push_error("GF_ISpatialIndex.rebuild() 必须由子类实现")


## 查询包围盒与矩形相交的实体（贴边视为相交）。
## 返回的实体可能已 despawn，调用方需 world.has_entity() 过滤。
func query_rect(p_rect: Rect2) -> Array[int]:
	push_error("GF_ISpatialIndex.query_rect() 必须由子类实现")
	return []


## 查询距 p_point 最近的至多 p_count 个实体，按距离升序（平手按 entity 升序）。
## 距离按实体包围盒中心点计算。
func query_nearest(p_point: Vector2, p_count: int) -> Array[int]:
	push_error("GF_ISpatialIndex.query_nearest() 必须由子类实现")
	return []


## 当前条目总数。
func count() -> int:
	push_error("GF_ISpatialIndex.count() 必须由子类实现")
	return 0


## 是否已索引指定实体。
func has_entity(p_entity: int) -> bool:
	push_error("GF_ISpatialIndex.has_entity() 必须由子类实现")
	return false


# ============================================================
# 共享几何/候选工具（实现类共用，避免两处复制）
# ============================================================


## 矩形到点的最小距离平方（点在矩形内时为 0）。
static func rect_min_dist_sq(p_rect: Rect2, p_point: Vector2) -> float:
	var dx := maxf(p_rect.position.x - p_point.x, maxf(0.0, p_point.x - p_rect.end.x))
	var dy := maxf(p_rect.position.y - p_point.y, maxf(0.0, p_point.y - p_rect.end.y))
	return dx * dx + dy * dy


## 矩形中心点。
static func rect_center(p_rect: Rect2) -> Vector2:
	return p_rect.position + p_rect.size * 0.5


## 向候选列表追加并维持容量上限 p_max（超出时剔除最远候选）。
## 候选元素形如 {entity: int, dist_sq: float}。
static func push_candidate(p_candidates: Array, p_entity: int, p_dist_sq: float, p_max: int) -> void:
	p_candidates.append({"entity": p_entity, "dist_sq": p_dist_sq})
	if p_candidates.size() <= p_max:
		return
	var worst_idx := 0
	for i in range(1, p_candidates.size()):
		if p_candidates[i].dist_sq > p_candidates[worst_idx].dist_sq:
			worst_idx = i
	p_candidates.remove_at(worst_idx)


## 候选列表中最大距离平方（nearest 查询剪枝界维护用）。
static func worst_dist_sq(p_candidates: Array) -> float:
	var worst := -INF
	for c in p_candidates:
		if c.dist_sq > worst:
			worst = c.dist_sq
	return worst


## 候选按距离升序排序（平手按 entity 升序）。
## 固定排序规则使查询结果可复现、可与暴力扫描对拍。
static func sort_candidates(p_candidates: Array) -> void:
	p_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.dist_sq != b.dist_sq:
			return a.dist_sq < b.dist_sq
		return a.entity < b.entity)
