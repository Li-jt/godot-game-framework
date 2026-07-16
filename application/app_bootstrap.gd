## AppBootstrap（Application 层启动基类）
## 使用 Installer 模式装配 Framework 服务。
## 提供 10 个可重写的生命周期 Hook，允许 Game 层和 Mod 在各安装阶段之间注入逻辑。
class_name AppBootstrap
extends Node

enum BootState { COLD, LOADING, READY, FAILED }
var state: BootState = BootState.COLD
var _boot_modules: Array[ModuleLifecycle] = []
var _boot_nodes: Array[Node] = []

# ============================================================
# 生命周期 Hook 方法（按执行顺序，子类可覆写）
# ============================================================

## 在任何 Installer 运行之前调用。
func _on_before_any_install() -> void:
	pass

## CoreInstaller 运行前调用。
func _on_before_core_install() -> void:
	pass

## CoreInstaller 运行后调用。可以在此注册 Mod 的基础服务。
func _on_after_core_install(p_deps: Dictionary) -> void:
	pass

## EngineInstaller 运行前调用。
func _on_before_engine_install(p_deps: Dictionary) -> void:
	pass

## EngineInstaller 运行后调用。可以在此注册 Mod 的引擎级依赖。
func _on_after_engine_install(p_deps: Dictionary) -> void:
	pass

## EcsInstaller 运行前调用。
func _on_before_ecs_install(p_deps: Dictionary) -> void:
	pass

## EcsInstaller 运行后调用。可以在此注册 Mod 的 ECS 系统/组件。
func _on_after_ecs_install(p_deps: Dictionary) -> void:
	pass

## ServiceInstaller 运行前调用。
func _on_before_service_install(p_deps: Dictionary) -> void:
	pass

## ServiceInstaller 运行后调用。可以在此注册 Mod 的高级服务（UI/Audio/Input）。
func _on_after_service_install(p_deps: Dictionary) -> void:
	pass

## 所有 Installer + verify 完成后调用。Game 层初始化入口。
func _on_post_boot(context: GameServices) -> OperationResult:
	return OperationResult.ok()

## 应用完全就绪后调用（AppFlow 已切换到 MAIN_MENU）。Mod 初始化入口。
func _on_app_ready(p_context: GameServices) -> void:
	pass

# ============================================================
# 启动流程
# ============================================================


func _ready() -> void: _run_boot_sequence()


func _run_boot_sequence() -> void:
	state = BootState.LOADING

	_on_before_any_install()

	# 创建 AppConfig。Game 层可覆写 _create_app_config() 来注入自定义配置。
	var config := _create_app_config()

	# 创建 Registry 提前（各 Installer 通过 deps 传递引用用于 add_required）
	var registry := ServiceRegistry.new()

	# Phase 1: Core
	_on_before_core_install()
	var core_result := CoreInstaller.new().install({"_bootstrap": self, "_app_config": config, "_registry": registry})
	if core_result.is_fail(): return
	_on_after_core_install(core_result.data)

	# Phase 2: Engine
	_on_before_engine_install(core_result.data)
	var engine_result := EngineInstaller.new().install({"_bootstrap": self, "_core_deps": core_result.data, "_registry": registry})
	if engine_result.is_fail(): return
	_on_after_engine_install(engine_result.data)

	# Phase 2.5: ECS
	_on_before_ecs_install(engine_result.data)
	var ecs_result := EcsInstaller.new().install({"_bootstrap": self, "_engine_deps": engine_result.data, "_registry": registry})
	if ecs_result.is_fail(): return
	_on_after_ecs_install(ecs_result.data)

	# Phase 3: Services
	_on_before_service_install(engine_result.data)
	var svc_result := ServiceInstallerImpl.new().install({"_bootstrap": self, "_engine_deps": engine_result.data, "_ecs_deps": ecs_result.data, "_registry": registry})
	if svc_result.is_fail(): return
	_on_after_service_install(svc_result.data)
	var deps: Dictionary = svc_result.data
	deps.merge(ecs_result.data)

	# Registry — 注册所有服务
	var reg_result := registry.register_all(_build_registry_entries(deps))
	if reg_result.is_fail(): _fail_boot("Registry", reg_result); return

	# 校验 — 此时 Mod 已通过 Hook 完成注册
	var verify_result := registry.verify_pending()
	if verify_result.is_fail(): _fail_boot("ServiceRegistry.verify", verify_result); return

	ServiceRegistry.instance = registry
	var log: LogService = deps.log
	log.info("Bootstrap", "服务注册中心已创建，当前注册 %d 个服务" % registry.count())

	# GameServices
	var context := _build_game_services(
		deps.config, deps.log, deps.scene_host, deps.save_service,
		deps.input_service, deps.ui_service, deps.audio_service, deps.config_svc,
		deps.resource_svc, deps.event_bus, deps.loc_service, deps.debug_service,
		deps.app_flow, deps.scheduler, deps.runtime_svc, deps.threading_svc,
		deps.ecs_world, deps.ecs_scheduler, core_result.data.file_system
	)

	_print_banner(deps.config, log)
	_print_config_summary(deps.config, log)

	var post_result := _on_post_boot(context)
	if post_result.is_fail(): _fail_boot("GameBootstrap", post_result); return

	var app_flow: AppFlow = deps.app_flow
	var fr := app_flow.transition_to(AppFlow.STATE_MAIN_MENU)
	if fr.is_fail(): _fail_boot("AppFlow.transition", fr); return

	state = BootState.READY
	log.info("Bootstrap", "启动完成")

	# Mod 加载 / 应用就绪
	_on_app_ready(context)


func is_ready() -> bool: return state == BootState.READY
func is_failed() -> bool: return state == BootState.FAILED


## 创建 AppConfig。Game 层可覆写此方法注入自定义配置。
## 默认行为：从 config/app_config.json 加载（向后兼容）。
func _create_app_config() -> AppConfig:
	var r := AppConfigLoader.new().load("res://")
	if r.is_fail():
		printerr("FATAL: 配置加载失败: " + r.error.message)
	return r.data if r.is_ok() else AppConfig.new()


# ============================================================
# 公开 Installer 调用的 helpers
# ============================================================

func _fail_boot(p_source: String, p_result: OperationResult) -> void:
	state = BootState.FAILED
	push_error("FATAL [%s]: %s" % [p_source, p_result.error.message])
	_cleanup_on_fail()

func _init_or_fail(p_module: ModuleLifecycle) -> bool:
	var r := p_module.init_module()
	if r.is_fail(): _fail_boot(p_module.module_name, r); return false
	return true

func _cfg_or_fail(p_name: String, p_result: OperationResult, p_module: ModuleLifecycle = null) -> bool:
	if p_result.is_fail():
		if p_module != null: p_module.fail_configuration(p_result)
		_fail_boot(p_name, p_result); return false
	if p_module != null: p_module.finalize_configuration()
	return true

func _track_module(p_module: ModuleLifecycle) -> void:
	if not _boot_modules.has(p_module): _boot_modules.append(p_module)

func _track_node(p_node: Node) -> void:
	if not _boot_nodes.has(p_node): _boot_nodes.append(p_node)


func _cleanup_on_fail() -> void:
	for i in range(_boot_modules.size() - 1, -1, -1):
		var m := _boot_modules[i]
		if m != null and m.is_ready():
			m.dispose_module()
	for child in _boot_nodes:
		if RuntimeUtilities.is_node_valid(child):
			child.queue_free()
	_boot_modules.clear()
	_boot_nodes.clear()


# ============================================================
# 内部
# ============================================================

func _build_registry_entries(p_deps: Dictionary) -> Array:
	return [
		[ServiceRegistry.KEY_RUNTIME,       p_deps.runtime_svc],
		[ServiceRegistry.KEY_PATH_RESOLVER,  p_deps.path_resolver],
		[ServiceRegistry.KEY_FILE_SYSTEM,    p_deps.file_system],
		[ServiceRegistry.KEY_EVENT_BUS,      p_deps.event_bus],
		[ServiceRegistry.KEY_LOCALIZATION,   p_deps.loc_service],
		[ServiceRegistry.KEY_DEBUG,          p_deps.debug_service],
		[ServiceRegistry.KEY_FLOW,           p_deps.app_flow],
		[ServiceRegistry.KEY_SAVE,           p_deps.save_service],
		[ServiceRegistry.KEY_CONFIG_SERVICE, p_deps.config_svc],
		[ServiceRegistry.KEY_RESOURCE,       p_deps.resource_svc],
		[ServiceRegistry.KEY_ASSET_LOADING,  p_deps.asset_loading],
		[ServiceRegistry.KEY_THREADING,      p_deps.threading_svc],
		[ServiceRegistry.KEY_SCENE_FACTORY,  p_deps.scene_factory],
		[ServiceRegistry.KEY_UI,             p_deps.ui_service],
		[ServiceRegistry.KEY_SCENE_HOST,     p_deps.scene_host],
		[ServiceRegistry.KEY_SCHEDULER,      p_deps.scheduler],
		[ServiceRegistry.KEY_INPUT,          p_deps.input_service],
		[ServiceRegistry.KEY_INPUT_ADAPTER,  p_deps.input_adapter],
		[ServiceRegistry.KEY_AUDIO,          p_deps.audio_service],
		[ServiceRegistry.KEY_AUDIO_RUNTIME,  p_deps.audio_runtime],
		[ServiceRegistry.KEY_CONFIG,         p_deps.config],
		[ServiceRegistry.KEY_LOG,            p_deps.log],
		[ServiceRegistry.KEY_ECS_WORLD,      p_deps.ecs_world],
		[ServiceRegistry.KEY_ECS_SCHEDULER,  p_deps.ecs_scheduler],
	]

func _build_game_services(
	p_config, p_log, p_scene_host, p_save_service, p_input, p_ui, p_audio,
	p_config_service, p_resource, p_event_bus, p_loc, p_debug, p_app_flow, p_scheduler, p_runtime, p_threading,
	p_ecs_world, p_ecs_scheduler, p_file_system
) -> GameServices:
	var s := GameServices.new()
	s.config = p_config; s.log = p_log; s.scene_host = p_scene_host
	s.save_service = p_save_service; s.input = p_input; s.ui = p_ui
	s.audio = p_audio; s.config_service = p_config_service; s.resource = p_resource
	s.event_bus = p_event_bus; s.loc = p_loc; s.debug = p_debug; s.app_flow = p_app_flow
	s.scheduler = p_scheduler; s.runtime = p_runtime; s.threading = p_threading
	s.ecs_world = p_ecs_world; s.ecs_scheduler = p_ecs_scheduler
	s.file_system = p_file_system
	return s

func _print_banner(p_config: AppConfig, p_log: LogService) -> void:
	var C := "[color=#00e5ff]"
	var T := "[color=#ffd740]"
	var W := "[color=#ffffff]"
	var X := "[/color]"
	p_log.info("Bootstrap", C + "╔══════════════════════════════════════════╗" + X)
	p_log.info("Bootstrap", C + "║" + X + "  " + T + p_config.app.name + X + "  " + C + "║" + X)
	p_log.info("Bootstrap", C + "║" + X + "  " + W + "v" + p_config.app.version + X + "  " + C + "║" + X)
	p_log.info("Bootstrap", C + "║" + X + "  " + W + "Godot 4.6  |  GDScript" + X + "                " + C + "║" + X)
	p_log.info("Bootstrap", C + "╚══════════════════════════════════════════╝" + X)

func _print_config_summary(p_config: AppConfig, p_log: LogService) -> void:
	var rows := [
		["Environment", p_config.app.environment], ["RuntimeMode", p_config.runtime.mode],
		["SaveProvider", p_config.save.provider], ["LogLevel", p_config.logging.level],
		["MockApi", _bool_label(p_config.network.use_mock_api)],
		["Prediction", _bool_label(p_config.runtime.enable_prediction)],
		["DebugPanel", _bool_label(p_config.debug.enable_debug_panel)],
	]
	var lw := 18; var vw := 24
	p_log.info("Bootstrap", "┌%s┬%s┐" % [_rpt("─", lw+2), _rpt("─", vw+2)])
	p_log.info("Bootstrap", "│ %-*s │ %-*s │" % [lw, "  运行配置", vw, ""])
	for row in rows: p_log.info("Bootstrap", "│  %-*s│  %-*s│" % [lw, row[0], vw, row[1]])
	p_log.info("Bootstrap", "└%s┴%s┘" % [_rpt("─", lw+2), _rpt("─", vw+2)])

func _bool_label(p_val: bool) -> String: return "Enabled" if p_val else "Disabled"
func _rpt(p_char: String, p_count: int) -> String:
	var s := ""
	for i in p_count: s += p_char
	return s
