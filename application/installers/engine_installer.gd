## EngineInstaller
## 安装引擎适配层服务：AssetLoading / SceneFactory / SceneHost / Scheduler / InputAdapter
class_name EngineInstaller
extends ServiceInstaller

## 返回 Dictionary 并合并 p_core_deps
func install(p_deps: Dictionary) -> OperationResult:
	var bs: AppBootstrap = p_deps.get("_bootstrap")
	var core: Dictionary = p_deps.get("_core_deps")
	var pr: PathResolver = core.path_resolver
	var log: LogService = core.log
	var deps: Dictionary = core.duplicate()

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

	# SceneHost
	var scene_host := SceneHost.new()
	scene_host.name = "SceneHost"
	if not bs._cfg_or_fail("SceneHost", scene_host.configure(scene_factory, log), null): return _fail()
	bs.add_child(scene_host)
	bs._track_node(scene_host)

	# Scheduler
	var scheduler := Scheduler.new()
	scheduler.name = "Scheduler"
	bs.add_child(scheduler)
	bs._track_node(scheduler)

	# InputAdapter
	var input_adapter := InputAdapter.new()

	deps.merge({
		"asset_loading": asset_loading, "scene_factory": scene_factory,
		"scene_host": scene_host, "scheduler": scheduler, "input_adapter": input_adapter,
	})
	return OperationResult.ok(deps)


func _fail() -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "EngineInstaller 失败", "EngineInstaller")
