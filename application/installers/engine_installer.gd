## GF_EngineInstaller
## 安装引擎适配层服务：AssetLoading / GF_SceneFactory / GF_SceneHost / GF_Scheduler / Threading / GF_InputAdapter
class_name GF_EngineInstaller
extends GF_ServiceInstaller

const SCENE_HOST_PATH := "res://addons/godot-game-framework/engine/scene_host/scene_host.tscn"


## 返回 Dictionary 并合并 p_core_deps
func install(p_deps: Dictionary) -> GF_OperationResult:
	var bs: GF_AppBootstrap = p_deps.get("_bootstrap")
	var core: Dictionary = p_deps.get("_core_deps")
	var pr: GF_PathResolver = core.path_resolver
	var log: GF_LogService = core.log
	var registry: GF_ServiceRegistry = p_deps.get("_registry")
	var deps: Dictionary = core.duplicate()

	# 解析 GF_SceneHost 场景路径（支持配置覆盖）
	var scene_host_path := pr.resolve_scene_host_path(SCENE_HOST_PATH)

	# AssetLoading
	var asset_loading := GF_AssetLoadingService.new()
	asset_loading.module_name = "AssetLoadingService"
	if not bs._init_or_fail(asset_loading): return _fail()
	bs._track_module(asset_loading)
	if not bs._cfg_or_fail("AssetLoading", asset_loading.configure(pr, log), asset_loading): return _fail()

	# GF_SceneFactory
	var scene_factory := GF_SceneFactory.new()
	scene_factory.module_name = "SceneFactory"
	if not bs._init_or_fail(scene_factory): return _fail()
	bs._track_module(scene_factory)
	if not bs._cfg_or_fail("GF_SceneFactory", scene_factory.configure(asset_loading, log), scene_factory): return _fail()

	# GF_SceneHost — 从 .tscn 实例化，节点树在编辑器中可见
	var scene_host_scene := load(scene_host_path) as PackedScene
	if scene_host_scene == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_IO, "无法加载 GF_SceneHost 场景: %s" % scene_host_path, "GF_EngineInstaller")

	var scene_host := scene_host_scene.instantiate() as GF_SceneHost
	scene_host.name = "GF_SceneHost"
	if not bs._cfg_or_fail("GF_SceneHost", scene_host.configure(scene_factory, log), null): return _fail()
	bs.add_child(scene_host)
	bs._track_node(scene_host)

	# GF_Scheduler
	var scheduler := GF_Scheduler.new()
	scheduler.name = "GF_Scheduler"
	bs.add_child(scheduler)
	bs._track_node(scheduler)

	# GF_ThreadingService
	var threading_svc := GF_ThreadingService.new()
	threading_svc.module_name = "ThreadingService"
	if not bs._init_or_fail(threading_svc): return _fail()
	bs._track_module(threading_svc)
	if not bs._cfg_or_fail("GF_ThreadingService", threading_svc.configure(core.config.threading, log), threading_svc): return _fail()
	scheduler.register(GF_Scheduler.TickGroup.FRAME, "ThreadingServicePump", threading_svc.pump, -200)

	# GF_InputAdapter
	var input_adapter := GF_InputAdapter.new()

	# 声明产出
	if registry != null:
		registry.add_required(GF_ServiceRegistry.KEY_ASSET_LOADING)
		registry.add_required(GF_ServiceRegistry.KEY_SCENE_FACTORY)
		registry.add_required(GF_ServiceRegistry.KEY_SCENE_HOST)
		registry.add_required(GF_ServiceRegistry.KEY_SCHEDULER)
		registry.add_required(GF_ServiceRegistry.KEY_THREADING)
		registry.add_required(GF_ServiceRegistry.KEY_INPUT_ADAPTER)

	deps.merge({
		"asset_loading": asset_loading, "scene_factory": scene_factory,
		"scene_host": scene_host, "scheduler": scheduler, "input_adapter": input_adapter,
		"threading_svc": threading_svc,
	})
	return GF_OperationResult.ok(deps)


func _fail() -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "GF_EngineInstaller 失败", "GF_EngineInstaller")
