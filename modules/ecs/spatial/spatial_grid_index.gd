## GF_GridIndex — 格子空间索引（O(1) 按格寻址，静态实体专用）。
## 与 GF_ISpatialIndex 树族并列，共同构成框架空间索引的两条腿：
## - 树族（GF_KDTreeSpatialIndex / GF_RStarSpatialIndex）：动态实体（怪物/动物），
##   周期同步 diff 维护，query_rect / query_nearest 范围与近邻查询，键为 AABB。
## - 本类：静态实体（地形/树/矿脉/建筑），创建时显式 register 一次，
##   at() 点查询，键为格子坐标（一实体可登记多格）。
## 键类型、生命周期策略、查询语义均不同，故不实现 GF_ISpatialIndex——
## 硬套接口是假抽象，两个平级类同住 modules/ecs/spatial/。
##
## 生命周期语义（与树族的本质区别）：
## - 写入：实体创建时显式 register（静态实体无移动，登记一次终身有效）。
## - 清理：lazy eviction——at()/has() 命中时发现实体已死或 marker 组件已移除
##   → 顺手清条目返回空。实体死亡零事件、零显式清理。
## - 例外：玩家拆除类实体（建筑）用 unregister 显式注销——拆除后该格
##   立即可再占用，不能等查询时懒清（放置校验会命中幽灵条目）。
## - miss 回调：查询未命中且 p_trigger_miss 时回调 (gx, gy)。回调是游戏语义
##   （如「chunk 未生成 → 触发生成请求」），框架只提供挂载点。
##
## 纯内存结构，RefCounted，不继承 GF_ModuleLifecycle——与树族同一定位。
## 对框架 CLAUDE.md §6「公共 API 返回 OperationResult」的豁免说明：
## - at() 返回裸 int：0 表示「空/已死」，是合法查询结果，不是失败。
## - register/unregister/clear 返回 void：纯内存索引唯一的失败形态是
##   「索引与 ECS 状态漂移」（重复 register、注销不存在的格）——这属于
##   框架使用错误而非运行时业务失败，用 push_warning 暴露（§16.1 不静默吞错误）。
##
## 仅主线程使用（at()/has() 内部访问 ECS 世界做判死）。
class_name GF_GridIndex
extends RefCounted

## 未命中回调 func(gx: int, gy: int) -> void。默认空，未绑定不触发。
var miss_callback: Callable = Callable()

## 判死组件（游戏层组件类，class_name 引用——树=TreeComponent、矿脉=OreDepotComponent）
var _marker: GDScript = null
var _world: GF_IEcsWorld = null
var _cells: Dictionary = {}  # {Vector2i: int entity}


## 注入 ECS 世界与判死 marker（使用前必须调用）。
## [param p_world] ECS 世界（GF_EcsWorld 满足接口）
## [param p_marker] 判死组件类：查询命中时 get_component 为 null 即视为已死
func setup(p_world: GF_IEcsWorld, p_marker: GDScript) -> void:
	if p_world == null or p_marker == null:
		push_error("[GF_GridIndex] setup 参数不能为 null（world/marker）")
		return
	_world = p_world
	_marker = p_marker


## 登记一格。已登记的格子视为索引与 ECS 状态漂移（push_warning，不覆盖）。
## 重登记前必须先 unregister。
func register(p_grid: Vector2i, p_entity: int) -> void:
	if _cells.has(p_grid):
		push_warning("[GF_GridIndex] register 已登记的格 %s（实体 %d → %d），索引与 ECS 状态漂移" % [p_grid, _cells[p_grid], p_entity])
		return
	_cells[p_grid] = p_entity


## 显式注销一格（玩家拆除类实体专用；生成类资源不需要——死亡由 lazy eviction 兜底）。
## 不存在的格视为索引与 ECS 状态漂移（push_warning）。
func unregister(p_grid: Vector2i) -> void:
	if not _cells.has(p_grid):
		push_warning("[GF_GridIndex] unregister 不存在的格 %s，索引与 ECS 状态漂移" % p_grid)
		return
	_cells.erase(p_grid)


## 查询格上实体。0 = 空 / 实体已死（已死条目被顺手清理，且不触发 miss 回调——
## 实体死亡不是「未生成」）。
## [param p_trigger_miss] true 时未命中触发 miss_callback（只读查询传 false）
func at(p_grid: Vector2i, p_trigger_miss: bool = true) -> int:
	var entity: int = _cells.get(p_grid, 0)
	if entity == 0:
		if p_trigger_miss and miss_callback.is_valid():
			miss_callback.call(p_grid.x, p_grid.y)
		return 0
	# lazy eviction：索引命中但实体已死（或 marker 已移除）→ 清条目
	if _world.get_component(entity, _marker) == null:
		_cells.erase(p_grid)
		return 0
	return entity


## 格上是否有活实体。等价于 at(p_grid, false) != 0，共享同一条 eviction 路径。
func has(p_grid: Vector2i) -> bool:
	return at(p_grid, false) != 0


## 当前条目总数（含尚未被查询触达清理的已死条目）。
func count() -> int:
	return _cells.size()


## 清空全部条目。
func clear() -> void:
	_cells.clear()
