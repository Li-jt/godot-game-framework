## EcsSystemGroup — 系统分组。
## 管理组内系统列表和执行顺序，支持 before/after 依赖排序。
class_name EcsSystemGroup
extends RefCounted

var group_name: String = ""
var _systems: Array[EcsSystem] = []
var _descriptors: Array[EcsSystemDescriptor] = []
var _initialized: bool = false


func _init(p_group_name: String = "") -> void:
	group_name = p_group_name


## 添加系统到组内。
func add_system(p_system: EcsSystem, p_descriptor: EcsSystemDescriptor = null) -> void:
	if _systems.has(p_system):
		return
	_systems.append(p_system)
	if p_descriptor != null:
		_descriptors.append(p_descriptor)
	else:
		_descriptors.append(EcsSystemDescriptor.new())


## 初始化组内所有系统（调用 on_init）。
func init_all(p_world: EcsWorld) -> void:
	for sys in _systems:
		sys.on_init(p_world)
	_initialized = true


## 执行组内所有系统。
func tick(p_world: EcsWorld, p_ecb: EcsCommandBuffer, p_delta: float) -> void:
	for sys in _systems:
		sys.on_tick(p_world, p_ecb, p_delta)


## 关闭组内所有系统。
func shutdown_all() -> void:
	for sys in _systems:
		sys.on_shutdown()
	_initialized = false


## 返回组内系统数量。
func system_count() -> int:
	return _systems.size()


## 是否已初始化。
func is_initialized() -> bool:
	return _initialized
