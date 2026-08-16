# modules/ecs/core/gf_ecs_native_backend.gd
## GF_EcsNativeBackend — GF_EcsWorld 的原生（Flecs/GDExtension）后端门面。
## 包装 C++ 的 GF_EcsNativeWorld，负责三个语义适配：
##
## 1. **实体 ID 映射**：框架约定「ID 单调递增不复用」，Flecs 原生
##    index+generation 会复用——门面维护 framework_id ↔ flecs_id 双向映射，
##    对外只暴露 framework_id；
## 2. **变更日志组装**：原生事件是有序流，映射为 GF_EcsChangeLog 的三列表，
##    并在操作语义处应用两条过滤规则（见 _pump_events）；
## 3. **type_key 对齐**：原生组件类型键 = GDScript 侧 GF_EcsComponentTypeRegistry
##    的 type_id，由 GF_EcsWorld 在调用前解析后传入。
##
## 事件过滤规则（§1.8 探针数据点 3 的两个适配点）：
## - set 首次（组件此前不存在）：Flecs 发 ADDED+CHANGED 两条，
##   框架语义只记一条 CHANGED → 丢弃其中的 ADDED；
## - despawn：Flecs 自动发组件 REMOVED 事件，框架语义只记 removed_entity
##   → 丢弃该实体的全部组件事件。
class_name GF_EcsNativeBackend
extends RefCounted

var _native: GF_EcsNativeWorld = null
var _id_map: Dictionary = {}       # framework_id -> flecs_id
var _reverse_map: Dictionary = {}  # flecs_id -> framework_id
var _next_id: int = 1
var _version: int = 0
## 世界级变更日志（与 GF_EcsWorld 原生实现同构的 API 面）
var change_log: GF_EcsChangeLog = null


func _init() -> void:
	_native = GF_EcsNativeWorld.new()
	change_log = GF_EcsChangeLog.new()


# ============================================================
# 实体生命周期
# ============================================================

func spawn() -> int:
	var framework_id: int = _next_id
	_next_id += 1
	var flecs_id: int = _native.spawn()
	_id_map[framework_id] = flecs_id
	_reverse_map[flecs_id] = framework_id
	_version += 1
	_pump_events()
	return framework_id


## 强制使用指定 ID 创建实体（供快照恢复使用，不自动分配 ID）。
func force_spawn(p_entity: int) -> void:
	var flecs_id: int = _native.spawn()
	_id_map[p_entity] = flecs_id
	_reverse_map[flecs_id] = p_entity
	_next_id = maxi(_next_id, p_entity + 1)
	_version += 1
	_pump_events()


func despawn(p_entity: int) -> bool:
	var flecs_id: int = _id_map.get(p_entity, 0)
	if flecs_id == 0 or not _native.has_entity(flecs_id):
		return false
	_native.despawn(flecs_id)
	_id_map.erase(p_entity)
	_version += 1
	# 适配点 2：丢弃该实体的组件事件，只保留 ENTITY_REMOVED
	_pump_events(_drop_comp_events_for(flecs_id))
	# 事件泵之后才擦除反向映射（ENTITY_REMOVED 需要它完成 framework_id 反查）
	_reverse_map.erase(flecs_id)
	return true


func has_entity(p_entity: int) -> bool:
	var flecs_id: int = _id_map.get(p_entity, 0)
	if flecs_id == 0:
		return false
	return _native.has_entity(flecs_id)


func entity_count() -> int:
	return _native.entity_count()


## 已分配的最大实体 ID（ID 单调不复用，游标扫描用）。
func max_entity_id() -> int:
	return _next_id - 1


func all_entities() -> PackedInt64Array:
	var result := PackedInt64Array()
	for flecs_id in _native.all_entities():
		var framework_id: int = _reverse_map.get(flecs_id, 0)
		if framework_id != 0:
			result.append(framework_id)
	return result


# ============================================================
# 组件操作（type_key = GDScript 侧 registry 的 type_id）
# ============================================================

func add_component(p_entity: int, p_type_key: int, p_data: Variant) -> bool:
	var flecs_id: int = _id_map.get(p_entity, 0)
	if flecs_id == 0:
		return false
	if not _native.add_component(flecs_id, p_type_key, p_data):
		return false  # 实体不存在或已有该组件（对齐 GF_EcsWorld 的 ERR_CONFLICT）
	_version += 1
	_pump_events()
	return true


func set_component(p_entity: int, p_type_key: int, p_data: Variant) -> bool:
	var flecs_id: int = _id_map.get(p_entity, 0)
	if flecs_id == 0:
		return false
	# 适配点 1：set 首次（组件此前不存在）时丢弃原生多发的 ADDED
	var was_missing: bool = not _native.has_component(flecs_id, p_type_key)
	if not _native.set_component(flecs_id, p_type_key, p_data):
		return false
	_version += 1
	if was_missing:
		_pump_events(_drop_added_for(flecs_id, p_type_key))
	else:
		_pump_events()
	return true


func get_component(p_entity: int, p_type_key: int) -> Variant:
	var flecs_id: int = _id_map.get(p_entity, 0)
	if flecs_id == 0:
		return null
	return _native.get_component(flecs_id, p_type_key)


func remove_component(p_entity: int, p_type_key: int) -> void:
	var flecs_id: int = _id_map.get(p_entity, 0)
	if flecs_id == 0:
		return
	if not _native.has_component(flecs_id, p_type_key):
		return  # 无此组件：静默返回，不递增版本、不记变更日志
	if not _native.remove_component(flecs_id, p_type_key):
		return
	_version += 1
	_pump_events()


func has_component(p_entity: int, p_type_key: int) -> bool:
	var flecs_id: int = _id_map.get(p_entity, 0)
	if flecs_id == 0:
		return false
	return _native.has_component(flecs_id, p_type_key)


func entities_with(p_type_key: int) -> PackedInt64Array:
	## 收集拥有指定组件的全部实体（framework_id）。供 GF_EcsQueryPlan 原生分支使用。
	var result := PackedInt64Array()
	var cb := func(flecs_id: int) -> void:
		var framework_id: int = _reverse_map.get(flecs_id, 0)
		if framework_id != 0:
			result.append(framework_id)
	_native.for_each(p_type_key, cb)
	return result


# ============================================================
# 版本与重置
# ============================================================

func get_version() -> int:
	return _version


func reset() -> void:
	_native.reset()
	_id_map.clear()
	_reverse_map.clear()
	_next_id = 1
	_version = 0
	change_log.clear()


# ============================================================
# 事件泵与过滤规则
# ============================================================

## 拉取原生事件流，过滤后组装为 change_log 三列表。
## [param p_drop] 返回 true 的事件被丢弃（默认全保留）。
func _pump_events(p_drop: Callable = Callable()) -> void:
	for ev in _native.flush_events():
		var kind: int = ev["kind"]
		if p_drop.is_valid() and p_drop.call(ev["entity"], ev["type_key"], kind):
			continue
		match kind:
			0:  # ENTITY_ADDED
				change_log.record_added_entity(_to_framework_id(ev["entity"]))
			1:  # ENTITY_REMOVED
				change_log.record_removed_entity(_to_framework_id(ev["entity"]))
			2:  # COMPONENT_ADDED
				change_log.record_component_change(
					_to_framework_id(ev["entity"]), ev["type_key"],
					GF_EcsChangeLog.ChangeKind.COMPONENT_ADDED,
					_native.get_component(ev["entity"], ev["type_key"]))
			3:  # COMPONENT_CHANGED
				change_log.record_component_change(
					_to_framework_id(ev["entity"]), ev["type_key"],
					GF_EcsChangeLog.ChangeKind.COMPONENT_CHANGED,
					_native.get_component(ev["entity"], ev["type_key"]))
			_:  # COMPONENT_REMOVED
				change_log.record_component_change(
					_to_framework_id(ev["entity"]), ev["type_key"],
					GF_EcsChangeLog.ChangeKind.COMPONENT_REMOVED)


func _to_framework_id(p_flecs_id: int) -> int:
	var framework_id: int = _reverse_map.get(p_flecs_id, 0)
	return framework_id if framework_id != 0 else -p_flecs_id


## 丢弃「指定实体的全部组件事件」（despawn 用）。
func _drop_comp_events_for(p_flecs_id: int) -> Callable:
	return func(entity: int, _type_key: int, kind: int) -> bool:
		return entity == p_flecs_id and kind >= 2


## 丢弃「指定实体 + 指定类型的 ADDED 事件」（set 首次用）。
func _drop_added_for(p_flecs_id: int, p_type_key: int) -> Callable:
	return func(entity: int, type_key: int, kind: int) -> bool:
		return entity == p_flecs_id and type_key == p_type_key and kind == 2
