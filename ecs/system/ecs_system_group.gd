## EcsSystemGroup — 系统分组。
## 管理组内系统列表和执行顺序，按 descriptor.priority 排序，
## 按 descriptor.tick_interval 做节流。
class_name EcsSystemGroup
extends IEcsSystemGroup

var group_name: String = ""
var _systems: Array[EcsSystem] = []
var _descriptors: Array[EcsSystemDescriptor] = []
var _initialized: bool = false
var _accumulators: Array[float] = []
var _time_since_init: float = 0.0


func _init(p_group_name: String = "") -> void:
	group_name = p_group_name


func add_system(p_system: EcsSystem, p_descriptor: EcsSystemDescriptor = null) -> void:
	if _systems.has(p_system):
		return
	_systems.append(p_system)
	if p_descriptor != null:
		_descriptors.append(p_descriptor)
	else:
		_descriptors.append(EcsSystemDescriptor.new())
	_accumulators.append(0.0)


func init_all(p_world: EcsWorld) -> void:
	_sort_by_priority()
	for sys in _systems:
		sys.on_init(p_world)
	_initialized = true
	_time_since_init = 0.0


func tick(p_world: EcsWorld, p_ecb: EcsCommandBuffer, p_delta: float) -> void:
	_time_since_init += p_delta
	for i in range(_systems.size()):
		var desc: EcsSystemDescriptor = _descriptors[i]
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


func _sort_by_priority() -> void:
	var pairs: Array = []
	for i in range(_systems.size()):
		pairs.append({"sys": _systems[i], "desc": _descriptors[i], "acc": _accumulators[i]})
	pairs.sort_custom(func(a, b): return a.desc.priority < b.desc.priority)
	for i in range(pairs.size()):
		_systems[i] = pairs[i].sys
		_descriptors[i] = pairs[i].desc
		_accumulators[i] = pairs[i].acc
