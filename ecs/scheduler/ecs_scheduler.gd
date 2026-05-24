## EcsScheduler — ECS 调度器。
## 驱动 Initialization / Simulation / Presentation 三组系统。
## 每组使用独立 EcsCommandBuffer，组末统一 apply 到世界。
class_name EcsScheduler
extends RefCounted

# 标准分组名称常量
const GROUP_INITIALIZATION: StringName = &"Initialization"
const GROUP_SIMULATION: StringName = &"Simulation"
const GROUP_PRESENTATION: StringName = &"Presentation"

var _groups: Dictionary = {}  # StringName -> EcsSystemGroup
var _group_order: Array[StringName] = []
var _world: EcsWorld = null
var _ecb_pool: EcsCommandBufferPool = null
var _active: bool = false
var _framework_handle = null  # Scheduler.TickHandle


func _init(p_world: EcsWorld = null) -> void:
	_world = p_world
	_ecb_pool = EcsCommandBufferPool.new()
	# 预设三组默认顺序
	add_group(GROUP_INITIALIZATION)
	add_group(GROUP_SIMULATION)
	add_group(GROUP_PRESENTATION)


## 设置 ECS 世界引用。
func set_world(p_world: EcsWorld) -> void:
	_world = p_world


## 添加一个系统分组。
func add_group(p_group_name: StringName) -> EcsSystemGroup:
	if _groups.has(p_group_name):
		return _groups[p_group_name]
	var group := EcsSystemGroup.new(p_group_name)
	_groups[p_group_name] = group
	_group_order.append(p_group_name)
	return group


## 向指定分组注册系统。
func register_system(p_system: EcsSystem, p_group_name: StringName, p_descriptor: EcsSystemDescriptor = null) -> OperationResult:
	if p_system == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "系统不能为空", "EcsScheduler")
	var group: EcsSystemGroup = _groups.get(p_group_name, null)
	if group == null:
		group = add_group(p_group_name)
	group.add_system(p_system, p_descriptor)
	return OperationResult.ok()


## 启动调度器（初始化所有系统）。
func start() -> void:
	if _world == null:
		return
	for group_name in _group_order:
		var group: EcsSystemGroup = _groups[group_name]
		group.init_all(_world)
	_active = true


## 执行一帧。
func tick(p_delta: float) -> void:
	if not _active or _world == null:
		return

	for group_name in _group_order:
		var group: EcsSystemGroup = _groups[group_name]
		if group.system_count() == 0:
			continue

		var ecb := _ecb_pool.acquire()
		group.tick(_world, ecb, p_delta)
		var apply_result := ecb.apply_to(_world)
		_ecb_pool.release(ecb)

		if apply_result.is_fail():
			push_error("[EcsScheduler] 命令应用失败 [%s]: %s" % [group_name, apply_result.error.message if apply_result.error != null else "未知错误"])


## 停止调度器（关闭所有系统）。
func stop() -> void:
	_active = false
	for group_name in _group_order:
		var group: EcsSystemGroup = _groups[group_name]
		group.shutdown_all()


## 是否正在运行。
func is_active() -> bool:
	return _active


## 返回指定分组。
func get_group(p_group_name: StringName) -> EcsSystemGroup:
	return _groups.get(p_group_name, null)


## 返回所有分组名称。
func get_group_names() -> Array[StringName]:
	return _group_order.duplicate()


## 将自身注册到 Framework Scheduler，确保 ECS tick 在正确的阶段执行。
## 绑定后 EcsScheduler.tick() 会由 Framework Scheduler 自动驱动。
func bind_to_framework_scheduler(p_scheduler: Scheduler) -> OperationResult:
	if p_scheduler == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "Framework 调度器不能为空", "EcsScheduler")
	_framework_handle = p_scheduler.register(
		Scheduler.TickGroup.SIMULATION,
		"EcsScheduler",
		_framework_tick,
		0
	)
	return OperationResult.ok()


## 启动调度器（初始化所有系统）。
func start_ecs_scheduler() -> void:
	start()


## 停止调度器（关闭所有系统）。
func stop_ecs_scheduler() -> void:
	stop()


func _framework_tick(p_delta: float) -> void:
	tick(p_delta)
