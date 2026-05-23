## EcsInstaller — ECS 服务安装器。
## 构建并配置 ECS 相关服务（EcsWorld、EcsScheduler、EcsSchedulerBridge），
## 产出 deps Dictionary 供后续 Installer 和 AppBootstrap 使用。
class_name EcsInstaller
extends ServiceInstaller


## 安装 ECS 服务组。依赖上游 EngineInstaller 提供的 scheduler。
func install(p_deps: Dictionary) -> OperationResult:
	var bs: AppBootstrap = p_deps.get("_bootstrap")
	var engine: Dictionary = p_deps.get("_engine_deps", {})
	var scheduler: Scheduler = engine.get("scheduler", null)
	if scheduler == null:
		return OperationResult.fail(OperationResult.ERR_PRECONDITION, "缺少 Framework Scheduler", "EcsInstaller")

	# EcsWorld
	var ecs_world := EcsWorld.new()

	# EcsScheduler
	var ecs_scheduler := EcsScheduler.new(ecs_world)

	# 桥接
	var bridge := EcsSchedulerBridge.new()
	var bind_result := bridge.bind(ecs_scheduler, scheduler)
	if bind_result.is_fail():
		return bind_result

	# 启动 ECS 调度器
	bridge.start_ecs()

	return OperationResult.ok({
		"ecs_world": ecs_world,
		"ecs_scheduler": ecs_scheduler,
		"ecs_bridge": bridge,
	})
