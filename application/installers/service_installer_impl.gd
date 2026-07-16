## ServiceInstallerImpl
## 安装 Framework 服务层：Resource / ConfigService / Save / InputService / UI / Audio / Debug
class_name ServiceInstallerImpl
extends ServiceInstaller

func install(p_deps: Dictionary) -> OperationResult:
	var bs: AppBootstrap = p_deps.get("_bootstrap")
	var deps: Dictionary = (p_deps.get("_engine_deps") as Dictionary).duplicate()
	var log: LogService = deps.log
	var pr: PathResolver = deps.path_resolver
	var al = deps.asset_loading
	var fs = deps.file_system
	var sc = deps.scene_factory
	var sh = deps.scene_host
	var ia = deps.input_adapter
	var sch = deps.scheduler
	var registry: ServiceRegistry = p_deps.get("_registry")

	# Resource
	var resource_svc := ResourceService.new()
	resource_svc.module_name = "ResourceService"
	if not bs._init_or_fail(resource_svc): return _fail()
	bs._track_module(resource_svc)
	if not bs._cfg_or_fail("ResourceService", resource_svc.configure(al, log), resource_svc): return _fail()

	# ConfigService
	var config_svc := ConfigService.new()
	config_svc.module_name = "ConfigService"
	if not bs._init_or_fail(config_svc): return _fail()
	bs._track_module(config_svc)
	if not bs._cfg_or_fail("ConfigService", config_svc.configure(fs, log), config_svc): return _fail()

	# SaveService
	var save_provider := _create_save_provider(bs, fs, pr, log, deps.config.save.provider)
	if save_provider.is_fail(): bs._fail_boot("SaveProvider", save_provider); return save_provider
	var save_service := SaveService.new()
	save_service.module_name = "SaveService"
	if not bs._init_or_fail(save_service): return _fail()
	bs._track_module(save_service)
	if not bs._cfg_or_fail("SaveService", save_service.configure(save_provider.data, pr, log), save_service): return _fail()

	# InputService
	var input_service := InputService.new()
	input_service.module_name = "InputService"
	if not bs._init_or_fail(input_service): return _fail()
	bs._track_module(input_service)
	if not bs._cfg_or_fail("InputService", input_service.configure(ia), input_service): return _fail()

	# AudioRuntime + AudioService
	var audio_runtime := AudioRuntime.new()
	audio_runtime.name = "AudioRuntime"
	bs.add_child(audio_runtime)
	bs._track_node(audio_runtime)

	var audio_service := AudioService.new()
	audio_service.module_name = "AudioService"
	if not bs._init_or_fail(audio_service): return _fail()
	bs._track_module(audio_service)
	if not bs._cfg_or_fail("AudioService", audio_service.configure(audio_runtime, resource_svc, log), audio_service): return _fail()

	# DebugService
	var debug_service := DebugService.new()
	debug_service.module_name = "DebugService"
	if not bs._init_or_fail(debug_service): return _fail()
	bs._track_module(debug_service)
	if not bs._cfg_or_fail("DebugService", debug_service.configure(deps.config.debug, log), debug_service): return _fail()
	sch.register(Scheduler.TickGroup.DEBUG, "DebugStats", debug_service.tick_stats, 0)

	# UiContext — 所有服务配置完成后构建，UIService 自动注入到每个面板
	var ui_context := UiContext.new()
	ui_context.scene_host = sh
	ui_context.input = input_service
	ui_context.log = log
	ui_context.event_bus = deps.event_bus
	ui_context.loc = deps.loc_service
	ui_context.config = deps.config
	ui_context.app_flow = deps.app_flow
	ui_context.save_service = save_service
	ui_context.config_service = config_svc
	ui_context.audio = audio_service
	ui_context.debug = debug_service

	# UIService
	var ui_service := UIService.new()
	ui_service.module_name = "UIService"
	if not bs._init_or_fail(ui_service): return _fail()
	bs._track_module(ui_service)
	if not bs._cfg_or_fail("UIService", ui_service.configure(ui_context), ui_service): return _fail()

	# 声明产出
	if registry != null:
		registry.add_required(ServiceRegistry.KEY_RESOURCE)
		registry.add_required(ServiceRegistry.KEY_CONFIG_SERVICE)
		registry.add_required(ServiceRegistry.KEY_SAVE)
		registry.add_required(ServiceRegistry.KEY_INPUT)
		registry.add_required(ServiceRegistry.KEY_AUDIO)
		registry.add_required(ServiceRegistry.KEY_AUDIO_RUNTIME)
		registry.add_required(ServiceRegistry.KEY_UI)
		registry.add_required(ServiceRegistry.KEY_DEBUG)

	deps.merge({
		"resource_svc": resource_svc, "config_svc": config_svc, "save_service": save_service,
		"input_service": input_service, "ui_service": ui_service, "audio_runtime": audio_runtime,
		"audio_service": audio_service, "debug_service": debug_service,
	})
	return OperationResult.ok(deps)


func _create_save_provider(p_bs: AppBootstrap, p_fs: FileSystemService, p_pr: PathResolver, p_log: LogService, p_mode: String) -> OperationResult:
	match p_mode.to_lower():
		"local":
			var provider := LocalSaveProvider.new()
			var r := provider.configure(p_fs, p_pr.get_save_root(), p_log)
			if r.is_fail(): return r
			return OperationResult.ok(provider)
		_:
			return OperationResult.fail(OperationResult.ERR_CONFIG, "不支持的 SaveProvider: %s" % p_mode, "Bootstrap")


func _fail() -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "ServiceInstallerImpl 失败", "ServiceInstallerImpl")
