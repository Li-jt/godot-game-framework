## GF_EcsSystemGroup — 系统分组。
## 管理组内系统列表和执行顺序，按 descriptor.priority 排序，
## 按 descriptor.tick_interval 做节流。
class_name GF_EcsSystemGroup
extends GF_IEcsSystemGroup

var group_name: String = ""
## 固定步长组：由 GF_EcsScheduler.tick_fixed() 驱动（delta 恒为
## GF_Scheduler.fixed_step_seconds），普通组由 tick() 驱动（可变 delta）。
## 决定论系统声明入 fixed 组（性能路线图 §2）。
var fixed_tick: bool = false
var _systems: Array[GF_EcsSystem] = []
var _descriptors: Array[GF_EcsSystemDescriptor] = []
var _initialized: bool = false
var _accumulators: Array[float] = []
var _time_since_init: float = 0.0


func _init(p_group_name: String = "", p_fixed_tick: bool = false) -> void:
	group_name = p_group_name
	fixed_tick = p_fixed_tick


func add_system(p_system: GF_EcsSystem, p_descriptor: GF_EcsSystemDescriptor = null) -> void:
	if _systems.has(p_system):
		return
	_systems.append(p_system)
	if p_descriptor != null:
		_descriptors.append(p_descriptor)
	else:
		_descriptors.append(GF_EcsSystemDescriptor.new())
	_accumulators.append(0.0)


func init_all(p_world: GF_EcsWorld) -> void:
	_sort_by_priority()
	for sys in _systems:
		sys.on_init(p_world)
	_initialized = true
	_time_since_init = 0.0


func tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
	_time_since_init += p_delta
	for i in range(_systems.size()):
		var desc: GF_EcsSystemDescriptor = _descriptors[i]
		if desc.tick_interval <= 0.0:
			_systems[i].on_tick(p_world, p_ecb, p_delta)
		else:
			_accumulators[i] += p_delta
			if _accumulators[i] >= desc.tick_interval:
				var elapsed: float = _accumulators[i]
				_accumulators[i] = 0.0
				_systems[i].on_tick(p_world, p_ecb, elapsed)


func shutdown_all() -> void:
	for sys in _systems:
		sys.on_shutdown()
	_initialized = false


func system_count() -> int:
	return _systems.size()


func is_initialized() -> bool:
	return _initialized


## 检查系统是否在组内。
func has_system(p_system: GF_EcsSystem) -> bool:
	return _systems.has(p_system)


## 移除系统。
func remove_system(p_system: GF_EcsSystem) -> void:
	var idx := _systems.find(p_system)
	if idx >= 0:
		_systems.remove_at(idx)
		_descriptors.remove_at(idx)
		_accumulators.remove_at(idx)


## 按名称移除。
func remove_by_name(p_name: String) -> GF_OperationResult:
	for i in range(_systems.size()):
		var desc: GF_EcsSystemDescriptor = _descriptors[i]
		if desc.system_name == p_name:
			_systems.remove_at(i)
			_descriptors.remove_at(i)
			_accumulators.remove_at(i)
			return GF_OperationResult.ok()
	return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "GF_EcsSystemGroup", "系统未找到: %s" % p_name)


## 按 owner 移除。返回被移除的系统名称列表。
func remove_by_owner(p_owner: String) -> Array[String]:
	var removed: Array[String] = []
	var i := _systems.size() - 1
	while i >= 0:
		var desc: GF_EcsSystemDescriptor = _descriptors[i]
		if desc.owner == p_owner:
			_systems[i].on_shutdown()
			removed.append(desc.system_name)
			_systems.remove_at(i)
			_descriptors.remove_at(i)
			_accumulators.remove_at(i)
		i -= 1
	return removed


func _sort_by_priority() -> void:
	var pairs: Array = []
	for i in range(_systems.size()):
		pairs.append({"sys": _systems[i], "desc": _descriptors[i], "acc": _accumulators[i]})
	pairs.sort_custom(func(a, b): return a.desc.priority < b.desc.priority)
	for i in range(pairs.size()):
		_systems[i] = pairs[i].sys
		_descriptors[i] = pairs[i].desc
		_accumulators[i] = pairs[i].acc
