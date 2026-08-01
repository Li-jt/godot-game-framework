## GF_CoreInstaller
## 安装核心服务：Runtime / GF_PathResolver / FileSystem / Log / GF_EventBus / Loc / GF_AppFlow
class_name GF_CoreInstaller
extends GF_ServiceInstaller

## 返回 Dictionary：{runtime_svc, path_resolver, file_system, log, event_bus, loc_service, app_flow}
func install(p_deps: Dictionary) -> GF_OperationResult:
	var bs: GF_AppBootstrap = p_deps.get("_bootstrap")
	var registry: GF_ServiceRegistry = p_deps.get("_registry")

	# Runtime — 默认 Local 模式，Game 层可通过 Bootstrap Hook 覆盖
	var runtime_svc := GF_RuntimeService.new()
	runtime_svc.module_name = "RuntimeService"
	if not bs._init_or_fail(runtime_svc): return _fail()
	bs._track_module(runtime_svc)
	if not bs._cfg_or_fail("GF_RuntimeService", runtime_svc.configure(), runtime_svc):
		return _fail()

	# GF_PathResolver — 默认路径，Game 层可在 Hook 中覆盖
	var path_resolver := GF_PathResolver.new()
	if not bs._cfg_or_fail("GF_PathResolver", path_resolver.configure()): return _fail()

	# FileSystem
	var file_system := GF_FileSystemService.new()
	file_system.module_name = "FileSystemService"
	if not bs._init_or_fail(file_system): return _fail()
	bs._track_module(file_system)
	file_system.finalize_configuration()

	# Log — 默认 Debug/写文件，Game 层可覆盖
	var log := GF_LogService.new()
	log.module_name = "LogService"
	if not bs._init_or_fail(log): return _fail()
	bs._track_module(log)
	if not bs._cfg_or_fail("GF_LogService", log.configure(), log): return _fail()

	# GF_EventBus
	var event_bus := GF_EventBus.new()
	event_bus.module_name = "EventBus"
	if not bs._init_or_fail(event_bus): return _fail()
	bs._track_module(event_bus)
	event_bus.finalize_configuration()

	# Localization
	var loc_service := GF_LocalizationService.new()
	loc_service.module_name = "LocalizationService"
	if not bs._init_or_fail(loc_service): return _fail()
	bs._track_module(loc_service)
	if not bs._cfg_or_fail("GF_LocalizationService", loc_service.configure(file_system, log), loc_service): return _fail()

	# GF_AppFlow
	var app_flow := GF_AppFlow.new()
	app_flow.module_name = "AppFlow"
	if not bs._init_or_fail(app_flow): return _fail()
	bs._track_module(app_flow)
	if not bs._cfg_or_fail("GF_AppFlow", app_flow.configure(event_bus), app_flow): return _fail()

	# 声明产出
	if registry != null:
		registry.add_required(GF_ServiceRegistry.KEY_RUNTIME)
		registry.add_required(GF_ServiceRegistry.KEY_PATH_RESOLVER)
		registry.add_required(GF_ServiceRegistry.KEY_FILE_SYSTEM)
		registry.add_required(GF_ServiceRegistry.KEY_LOG)
		registry.add_required(GF_ServiceRegistry.KEY_EVENT_BUS)
		registry.add_required(GF_ServiceRegistry.KEY_LOCALIZATION)
		registry.add_required(GF_ServiceRegistry.KEY_FLOW)

	var deps: Dictionary = {
		"runtime_svc": runtime_svc, "path_resolver": path_resolver,
		"file_system": file_system, "log": log, "event_bus": event_bus,
		"loc_service": loc_service, "app_flow": app_flow,
	}
	return GF_OperationResult.ok(deps)


func _fail() -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "GF_CoreInstaller 失败", "GF_CoreInstaller")
