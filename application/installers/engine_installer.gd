## EngineInstaller
## 安装引擎适配层服务：AssetLoading / SceneFactory / SceneHost / Scheduler / Threading / InputAdapter
class_name EngineInstaller
extends ServiceInstaller

const SCENE_HOST_PATH := "res://src/framework/engine/scene_host/scene_host.tscn"


## 返回 Dictionary 并合并 p_core_deps
func install(p_deps: Dictionary) -> OperationResult:
	var bs: AppBootstrap = p_deps.get("_bootstrap")
	var core: Dictionary = p_deps.get("_core_deps")
	var pr: PathResolver = core.path_resolver
	var log: LogService = core.log
	var registry: ServiceRegistry = p_deps.get("_registry")
	var deps: Dictionary = core.duplicate()

	# 解析 SceneHost 场景路径（支持配置覆盖）
	var scene_host_path := pr.resolve_scene_host_path(SCENE_HOST_PATH)

	# AssetLoading
	var asset_loading := AssetLoadingService.new()
	asset_loading.module_name = "AssetLoadingService"
	if not bs._init_or_fail(asset_loading): return _fail()
	bs._track_module(asset_loading)
	if not bs._cfg_or_fail("AssetLoading", asset_loading.configure(pr, log), asset_loading): return _fail()

	# SceneFactory
	var scene_factory := SceneFactory.new()
	scene_factory.module_name = "SceneFactory"
	if not bs._init_or_fail(scene_factory): return _fail()
	bs._track_module(scene_factory)
	if not bs._cfg_or_fail("SceneFactory", scene_factory.configure(asset_loading, log), scene_factory): return _fail()

	# SceneHost — 从 .tscn 实例化，节点树在编辑器中可见
	var scene_host_scene := load(scene_host_path) as PackedScene
	if scene_host_scene == null:
		return OperationResult.fail(OperationResult.ERR_IO, "无法加载 SceneHost 场景: %s" % scene_host_path, "EngineInstaller")

	var scene_host := scene_host_scene.instantiate() as SceneHost
	scene_host.name = "SceneHost"
	if not bs._cfg_or_fail("SceneHost", scene_host.configure(scene_factory, log), null): return _fail()
	bs.add_child(scene_host)
	bs._track_node(scene_host)

	# Scheduler
	var scheduler := Scheduler.new()
	scheduler.name = "Scheduler"
	bs.add_child(scheduler)
	bs._track_node(scheduler)

	# ThreadingService
	var threading_svc := ThreadingService.new()
	threading_svc.module_name = "ThreadingService"
	if not bs._init_or_fail(threading_svc): return _fail()
	bs._track_module(threading_svc)
	if not bs._cfg_or_fail("ThreadingService", threading_svc.configure(core.config.threading, log), threading_svc): return _fail()
	scheduler.register(Scheduler.TickGroup.FRAME, "ThreadingServicePump", threading_svc.pump, -200)

	# InputAdapter
	var input_adapter := InputAdapter.new()

	# 声明产出
	if registry != null:
		registry.add_required(ServiceRegistry.KEY_ASSET_LOADING)
		registry.add_required(ServiceRegistry.KEY_SCENE_FACTORY)
		registry.add_required(ServiceRegistry.KEY_SCENE_HOST)
		registry.add_required(ServiceRegistry.KEY_SCHEDULER)
		registry.add_required(ServiceRegistry.KEY_THREADING)
		registry.add_required(ServiceRegistry.KEY_INPUT_ADAPTER)

	deps.merge({
		"asset_loading": asset_loading, "scene_factory": scene_factory,
		"scene_host": scene_host, "scheduler": scheduler, "input_adapter": input_adapter,
		"threading_svc": threading_svc,
	})
	return OperationResult.ok(deps)


func _fail() -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "EngineInstaller 失败", "EngineInstaller")
