## GF_EcsInstaller — ECS 服务安装器。
## 构建并配置 ECS 相关服务（GF_EcsWorld、GF_EcsScheduler），
## GF_EcsScheduler 直接注册到 Framework GF_Scheduler，无需中间桥接对象。
## 产出 deps Dictionary 供后续 Installer 和 GF_AppBootstrap 使用。
class_name GF_EcsInstaller
extends GF_ServiceInstaller


## 安装 ECS 服务组。依赖上游 GF_EngineInstaller 提供的 scheduler。
func install(p_deps: Dictionary) -> GF_OperationResult:
	var engine: Dictionary = p_deps.get("_engine_deps", {})
	var scheduler: GF_Scheduler = engine.get("scheduler", null)
	var registry: GF_ServiceRegistry = p_deps.get("_registry")
	if scheduler == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_PRECONDITION, "缺少 Framework GF_Scheduler", "GF_EcsInstaller")

	# GF_EcsWorld
	var ecs_world := GF_EcsWorld.new()

	# GF_EcsScheduler
	var ecs_scheduler := GF_EcsScheduler.new(ecs_world)

	# 直接绑定到 Framework GF_Scheduler（无需桥接对象，避免 RefCounted GC）
	var bind_result := ecs_scheduler.bind_to_framework_scheduler(scheduler)
	if bind_result.is_fail():
		return bind_result

	# 启动 ECS 调度器
	ecs_scheduler.start_ecs_scheduler()

	# 声明产出
	if registry != null:
		registry.add_required(GF_ServiceRegistry.KEY_ECS_WORLD)
		registry.add_required(GF_ServiceRegistry.KEY_ECS_SCHEDULER)

	return GF_OperationResult.ok({
		"ecs_world": ecs_world,
		"ecs_scheduler": ecs_scheduler,
	})
