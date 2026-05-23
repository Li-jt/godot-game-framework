## EcsSchedulerBridge — ECS 调度器与 Framework Scheduler 的桥接。
## 将 EcsScheduler.tick() 注册为 Framework Scheduler 的 SIMULATION 回调，
## 确保 ECS 系统在正确的 Tick 阶段执行。
class_name EcsSchedulerBridge
extends RefCounted

var _ecs_scheduler: EcsScheduler = null
var _framework_scheduler: Scheduler = null
var _handle = null  # Scheduler.TickHandle


## 绑定 ECS 调度器和 Framework 调度器。
func bind(p_ecs_scheduler: EcsScheduler, p_framework_scheduler: Scheduler) -> OperationResult:
	if p_ecs_scheduler == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "ECS 调度器不能为空", "EcsSchedulerBridge")
	if p_framework_scheduler == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "Framework 调度器不能为空", "EcsSchedulerBridge")

	_ecs_scheduler = p_ecs_scheduler
	_framework_scheduler = p_framework_scheduler

	_handle = _framework_scheduler.register(
		Scheduler.TickGroup.SIMULATION,
		"EcsScheduler",
		_tick_ecs,
		0
	)
	return OperationResult.ok()


## 解除绑定。
func unbind() -> void:
	if _handle != null:
		_handle.unregister()
		_handle = null
	_ecs_scheduler = null
	_framework_scheduler = null


## 启�� ECS 调度器。
func start_ecs() -> void:
	if _ecs_scheduler != null:
		_ecs_scheduler.start()


## 停止 ECS 调度器。
func stop_ecs() -> void:
	if _ecs_scheduler != null:
		_ecs_scheduler.stop()


func _tick_ecs(p_delta: float) -> void:
	if _ecs_scheduler != null:
		_ecs_scheduler.tick(p_delta)
