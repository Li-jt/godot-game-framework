## CoreInstaller
## 安装核心服务：Config / Runtime / PathResolver / FileSystem / Log / EventBus / Loc / AppFlow
class_name CoreInstaller
extends ServiceInstaller

## 返回 Dictionary：{config, runtime_svc, path_resolver, file_system, log, event_bus, loc_service, app_flow}
func install(p_deps: Dictionary) -> OperationResult:
	var bs: AppBootstrap = p_deps.get("_bootstrap")

	# Config
	var loader := AppConfigLoader.new()
	var r := loader.load("res://")
	if r.is_fail(): bs._fail_boot("ConfigLoader", r); return r
	var config: AppConfig = r.data

	# Runtime
	var runtime_svc := RuntimeService.new()
	runtime_svc.module_name = "RuntimeService"
	if not bs._init_or_fail(runtime_svc): return _fail()
	bs._track_module(runtime_svc)
	if not bs._cfg_or_fail("RuntimeService", runtime_svc.configure(config.runtime), runtime_svc):
		return _fail()

	# PathResolver
	var path_resolver := PathResolver.new()
	if not bs._cfg_or_fail("PathResolver", path_resolver.configure_from_app_config(config)): return _fail()

	# FileSystem
	var file_system := FileSystemService.new()
	file_system.module_name = "FileSystemService"
	if not bs._init_or_fail(file_system): return _fail()
	bs._track_module(file_system)
	file_system.finalize_configuration()

	# Log
	var log := LogService.new()
	log.module_name = "LogService"
	if not bs._init_or_fail(log): return _fail()
	bs._track_module(log)
	if not bs._cfg_or_fail("LogService", log.configure(config.logging, path_resolver), log): return _fail()

	# EventBus
	var event_bus := EventBus.new()
	event_bus.module_name = "EventBus"
	if not bs._init_or_fail(event_bus): return _fail()
	bs._track_module(event_bus)
	event_bus.finalize_configuration()

	# Localization
	var loc_service := LocalizationService.new()
	loc_service.module_name = "LocalizationService"
	if not bs._init_or_fail(loc_service): return _fail()
	bs._track_module(loc_service)
	if not bs._cfg_or_fail("LocalizationService", loc_service.configure(file_system, log), loc_service): return _fail()

	# AppFlow
	var app_flow := AppFlow.new()
	app_flow.module_name = "AppFlow"
	if not bs._init_or_fail(app_flow): return _fail()
	bs._track_module(app_flow)
	if not bs._cfg_or_fail("AppFlow", app_flow.configure(event_bus), app_flow): return _fail()

	var deps: Dictionary = {
		"config": config, "runtime_svc": runtime_svc, "path_resolver": path_resolver,
		"file_system": file_system, "log": log, "event_bus": event_bus,
		"loc_service": loc_service, "app_flow": app_flow,
	}
	return OperationResult.ok(deps)


func _fail() -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "CoreInstaller 失败", "CoreInstaller")
