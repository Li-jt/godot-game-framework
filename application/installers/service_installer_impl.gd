## GF_ServiceInstallerImpl
## 安装 Framework 服务层：Resource / GF_ConfigService / Save / GF_InputService / UI / Audio / Debug
class_name GF_ServiceInstallerImpl
extends GF_ServiceInstaller

func install(p_deps: Dictionary) -> GF_OperationResult:
	var bs: GF_AppBootstrap = p_deps.get("_bootstrap")
	var deps: Dictionary = (p_deps.get("_engine_deps") as Dictionary).duplicate()
	var log: GF_LogService = deps.log
	var pr: GF_PathResolver = deps.path_resolver
	var al = deps.asset_loading
	var fs = deps.file_system
	var sc = deps.scene_factory
	var sh = deps.scene_host
	var ia = deps.input_adapter
	var sch = deps.scheduler
	var registry: GF_ServiceRegistry = p_deps.get("_registry")

	# Resource
	var resource_svc := GF_ResourceService.new()
	resource_svc.module_name = "ResourceService"
	if not bs._init_or_fail(resource_svc): return _fail()
	bs._track_module(resource_svc)
	if not bs._cfg_or_fail("GF_ResourceService", resource_svc.configure(al, log), resource_svc): return _fail()

	# GF_ConfigService
	var config_svc := GF_ConfigService.new()
	config_svc.module_name = "ConfigService"
	if not bs._init_or_fail(config_svc): return _fail()
	bs._track_module(config_svc)
	if not bs._cfg_or_fail("GF_ConfigService", config_svc.configure(fs, log), config_svc): return _fail()

	# GF_SaveService
	var save_provider := _create_save_provider(bs, fs, pr, log, deps.config.save.provider)
	if save_provider.is_fail(): bs._fail_boot("GF_SaveProvider", save_provider); return save_provider
	var save_service := GF_SaveService.new()
	save_service.module_name = "SaveService"
	if not bs._init_or_fail(save_service): return _fail()
	bs._track_module(save_service)
	if not bs._cfg_or_fail("GF_SaveService", save_service.configure(save_provider.data, pr, log), save_service): return _fail()

	# GF_InputService
	var input_service := GF_InputService.new()
	input_service.module_name = "InputService"
	if not bs._init_or_fail(input_service): return _fail()
	bs._track_module(input_service)
	if not bs._cfg_or_fail("GF_InputService", input_service.configure(ia), input_service): return _fail()

	# GF_AudioRuntime + GF_AudioService
	var audio_runtime := GF_AudioRuntime.new()
	audio_runtime.name = "GF_AudioRuntime"
	bs.add_child(audio_runtime)
	bs._track_node(audio_runtime)

	var audio_service := GF_AudioService.new()
	audio_service.module_name = "AudioService"
	if not bs._init_or_fail(audio_service): return _fail()
	bs._track_module(audio_service)
	if not bs._cfg_or_fail("GF_AudioService", audio_service.configure(audio_runtime, resource_svc, log), audio_service): return _fail()

	# GF_DebugService
	var debug_service := GF_DebugService.new()
	debug_service.module_name = "DebugService"
	if not bs._init_or_fail(debug_service): return _fail()
	bs._track_module(debug_service)
	if not bs._cfg_or_fail("GF_DebugService", debug_service.configure(deps.config.debug, log), debug_service): return _fail()
	sch.register(GF_Scheduler.TickGroup.DEBUG, "DebugStats", debug_service.tick_stats, 0)

	# GF_UiContext — 所有服务配置完成后构建，GF_UIService 自动注入到每个面板
	var ui_context := GF_UiContext.new()
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

	# GF_UIService
	var ui_service := GF_UIService.new()
	ui_service.module_name = "UIService"
	if not bs._init_or_fail(ui_service): return _fail()
	bs._track_module(ui_service)
	if not bs._cfg_or_fail("GF_UIService", ui_service.configure(ui_context), ui_service): return _fail()

	# GF_UIDragManager — 挂到场景树接收 _input 事件
	var drag_manager := ui_service.get_drag_manager()
	if drag_manager != null:
		bs.add_child(drag_manager)
		bs._track_node(drag_manager)

	# 声明产出
	if registry != null:
		registry.add_required(GF_ServiceRegistry.KEY_RESOURCE)
		registry.add_required(GF_ServiceRegistry.KEY_CONFIG_SERVICE)
		registry.add_required(GF_ServiceRegistry.KEY_SAVE)
		registry.add_required(GF_ServiceRegistry.KEY_INPUT)
		registry.add_required(GF_ServiceRegistry.KEY_AUDIO)
		registry.add_required(GF_ServiceRegistry.KEY_AUDIO_RUNTIME)
		registry.add_required(GF_ServiceRegistry.KEY_UI)
		registry.add_required(GF_ServiceRegistry.KEY_DEBUG)

	deps.merge({
		"resource_svc": resource_svc, "config_svc": config_svc, "save_service": save_service,
		"input_service": input_service, "ui_service": ui_service, "audio_runtime": audio_runtime,
		"audio_service": audio_service, "debug_service": debug_service,
	})
	return GF_OperationResult.ok(deps)


func _create_save_provider(p_bs: GF_AppBootstrap, p_fs: GF_FileSystemService, p_pr: GF_PathResolver, p_log: GF_LogService, p_mode: String) -> GF_OperationResult:
	match p_mode.to_lower():
		"local":
			var provider := GF_LocalSaveProvider.new()
			var r := provider.configure(p_fs, p_pr.get_save_root(), p_log)
			if r.is_fail(): return r
			return GF_OperationResult.ok(provider)
		_:
			return GF_OperationResult.fail(GF_OperationResult.ERR_CONFIG, "不支持的 GF_SaveProvider: %s" % p_mode, "Bootstrap")


func _fail() -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "GF_ServiceInstallerImpl 失败", "GF_ServiceInstallerImpl")
