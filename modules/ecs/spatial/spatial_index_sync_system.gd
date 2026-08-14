## GF_SpatialIndexSyncSystem — 空间索引自动同步系统。
## 对应 bevy_spatial 的 AutomaticUpdate：周期性扫描带 marker 组件的实体，
## 与快照镜像 diff 后驱动索引 insert/update/remove，despawn 实体自动清理——
## 游戏层零清理代码，与框架 lazy eviction 哲学统一。
##
## 装配（游戏层）：
## [codeblock]
## var sync := GF_SpatialIndexSyncSystem.new()
## sync.index = monster_index
## sync.marker = MonsterComponent
## sync.bounds_extractor = func(c): return c.position_bounds()
## var desc := GF_EcsSystemDescriptor.new()
## desc.tick_interval = 0.25   # 同步频率（秒），由框架调度器按时间节流
## ecs_sched.register_system(sync, GF_EcsScheduler.GROUP_PRESENTATION, desc)
## [/codeblock]
##
## 注意：
## - 必须注册到 GROUP_PRESENTATION（或任意 Simulation 之后的组）：Simulation 组的
##   ECB 在组末才 apply，本系统若在组内会看到 apply 前的旧世界状态，死亡清理
##   会额外慢一轮。组序见 GF_EcsScheduler.tick()。
## - 索引是系统持有的外部结构，不经过 ECB 写入——ECB 只负责 ECS 世界存储
##   （CLAUDE.md §9.2 针对 World 存储，本系统不违反）。
## - GF_KDTreeSpatialIndex 请开启 rebuild_every_sync（全量重建模式）；
##   GF_RStarSpatialIndex 用默认 diff 模式 + 阈值退化。
## - 快照镜像字典是「组件版本号」的等价物（框架 ECS 尚无 Added/Changed tick）。
##   将来组件存储加版本号后，可优化为只扫 Changed 实体。
class_name GF_SpatialIndexSyncSystem
extends GF_EcsSystem

## 目标索引实例（GF_ISpatialIndex 任一实现）
var index: GF_ISpatialIndex = null
## 跟踪标记组件类（游戏层组件，class_name 引用）
var marker: GDScript = null
## 包围盒提取器：(component) -> Rect2，游戏层桥接
var bounds_extractor: Callable = Callable()
## true 时每轮同步整体重建索引（KDTree 模式）；false 时增量 diff（R* 模式）
var rebuild_every_sync: bool = false
## 增量模式下，变化实体比例达到该值时退化为整体重建（防 R* 退化）
var rebuild_threshold: float = 0.3

var _snapshot: Dictionary = {}  # {int entity: Rect2 bounds}，上次同步的镜像
var _plan: GF_EcsQueryPlan = null


func on_init(p_world: GF_EcsWorld) -> void:
	if index == null or marker == null or not bounds_extractor.is_valid():
		push_warning("[GF_SpatialIndexSyncSystem] 配置不完整（index/marker/bounds_extractor），同步停用")
		return
	# 预编译查询计划一次，tick 中复用（GF_EcsQueryPlan 设计意图）
	_plan = GF_EcsQuery.new().with_component(marker).build()


func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
	if _plan == null:
		return

	# 1. 扫描当前带 marker 的实体，提取包围盒
	var current: Dictionary = {}
	var rows := _plan.execute(p_world)
	for i in range(rows.count()):
		var row := rows.get_row(i)
		var comp: Variant = row.get_component(marker)
		current[row.entity] = bounds_extractor.call(comp)

	# 2. 重建模式：整体重建，跳过 diff（KDTree 路径）
	if rebuild_every_sync:
		index.rebuild(current)
		_snapshot = current
		return

	# 3. 与镜像 diff，驱动增量更新（R* 路径）
	var changed := 0
	for entity in current:
		if not _snapshot.has(entity):
			index.insert(entity, current[entity])
			changed += 1
		elif _snapshot[entity] != current[entity]:
			index.update(entity, current[entity])
			changed += 1
	for entity in _snapshot:
		if not current.has(entity):
			index.remove(entity)
			changed += 1

	# 4. 变化比例超阈值 → 整体重建（R* 退化路径）
	var total := maxi(1, current.size())
	if changed > 0 and float(changed) / float(total) >= rebuild_threshold:
		index.rebuild(current)

	_snapshot = current
