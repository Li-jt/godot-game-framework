## GF_AppBootstrap（Application 层启动基类）
## 使用 Installer 模式装配 Framework 服务。
## 提供 10 个可重写的生命周期 Hook，允许 Game 层和 Mod 在各安装阶段之间注入逻辑。
class_name GF_AppBootstrap
extends Node

enum BootState { COLD, LOADING, READY, FAILED }
var state: BootState = BootState.COLD
var _boot_modules: Array[GF_ModuleLifecycle] = []
var _boot_nodes: Array[Node] = []

# ============================================================
# 生命周期 Hook 方法（按执行顺序，子类可覆写）
# ============================================================

## 在任何 Installer 运行之前调用。
func _on_before_any_install() -> void:
	pass

## GF_CoreInstaller 运行前调用。
func _on_before_core_install() -> void:
	pass

## GF_CoreInstaller 运行后调用。可以在此注册 Mod 的基础服务。
func _on_after_core_install(p_deps: Dictionary) -> void:
	pass

## GF_EngineInstaller 运行前调用。
func _on_before_engine_install(p_deps: Dictionary) -> void:
	pass

## GF_EngineInstaller 运行后调用。可以在此注册 Mod 的引擎级依赖。
func _on_after_engine_install(p_deps: Dictionary) -> void:
	pass

## GF_EcsInstaller 运行前调用。
func _on_before_ecs_install(p_deps: Dictionary) -> void:
	pass

## GF_EcsInstaller 运行后调用。可以在此注册 Mod 的 ECS 系统/组件。
func _on_after_ecs_install(p_deps: Dictionary) -> void:
	pass

## GF_ServiceInstaller 运行前调用。
func _on_before_service_install(p_deps: Dictionary) -> void:
	pass

## GF_ServiceInstaller 运行后调用。可以在此注册 Mod 的高级服务（UI/Audio/Input）。
func _on_after_service_install(p_deps: Dictionary) -> void:
	pass

## 所有 Installer + verify 完成后调用。Game 层初始化入口。
func _on_post_boot(context: GF_GameServices) -> GF_OperationResult:
	return GF_OperationResult.ok()

## 应用完全就绪后调用（GF_AppFlow 已切换到 MAIN_MENU）。Mod 初始化入口。
func _on_app_ready(p_context: GF_GameServices) -> void:
	pass

# ============================================================
# 启动流程
# ============================================================


func _ready() -> void: _run_boot_sequence()


func _run_boot_sequence() -> void:
	state = BootState.LOADING

	_on_before_any_install()

	# 创建 GF_AppConfig。Game 层可覆写 _create_app_config() 来注入自定义配置。
	var config := _create_app_config()

	# 创建 Registry 提前（各 Installer 通过 deps 传递引用用于 add_required）
	var registry := GF_ServiceRegistry.new()

	# Phase 1: Core
	_on_before_core_install()
	var core_result := GF_CoreInstaller.new().install({"_bootstrap": self, "_app_config": config, "_registry": registry})
	if core_result.is_fail(): return
	_on_after_core_install(core_result.data)

	# Phase 2: Engine
	_on_before_engine_install(core_result.data)
	var engine_result := GF_EngineInstaller.new().install({"_bootstrap": self, "_core_deps": core_result.data, "_registry": registry})
	if engine_result.is_fail(): return
	_on_after_engine_install(engine_result.data)

	# Phase 2.5: ECS
	_on_before_ecs_install(engine_result.data)
	var ecs_result := GF_EcsInstaller.new().install({"_bootstrap": self, "_engine_deps": engine_result.data, "_registry": registry})
	if ecs_result.is_fail(): return
	_on_after_ecs_install(ecs_result.data)

	# Phase 3: Services
	_on_before_service_install(engine_result.data)
	var svc_result := GF_ServiceInstallerImpl.new().install({"_bootstrap": self, "_engine_deps": engine_result.data, "_ecs_deps": ecs_result.data, "_registry": registry})
	if svc_result.is_fail(): return
	_on_after_service_install(svc_result.data)
	var deps: Dictionary = svc_result.data
	deps.merge(ecs_result.data)

	# Registry — 注册所有服务
	var reg_result := registry.register_all(_build_registry_entries(deps))
	if reg_result.is_fail(): _fail_boot("Registry", reg_result); return

	# 校验 — 此时 Mod 已通过 Hook 完成注册
	var verify_result := registry.verify_pending()
	if verify_result.is_fail(): _fail_boot("GF_ServiceRegistry.verify", verify_result); return

	var log: GF_LogService = deps.log
	log.info("Bootstrap", "服务注册中心已创建，当前注册 %d 个服务" % registry.count())

	# GF_GameServices — 从 deps 字典按需取用，避免位置参数过多
	var context := _build_game_services(deps)

	_print_banner(deps.config, log)
	_print_config_summary(deps.config, log)

	var post_result := _on_post_boot(context)
	if post_result.is_fail(): _fail_boot("GameBootstrap", post_result); return

	var app_flow: GF_AppFlow = deps.app_flow
	var fr := app_flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)
	if fr.is_fail(): _fail_boot("GF_AppFlow.transition", fr); return

	state = BootState.READY
	log.info("Bootstrap", "启动完成")

	# Mod 加载 / 应用就绪
	_on_app_ready(context)


func is_ready() -> bool: return state == BootState.READY
func is_failed() -> bool: return state == BootState.FAILED


## 创建 GF_AppConfig。Game 层可覆写此方法注入自定义配置。
## 默认行为：从 config/app_config.json 加载（向后兼容）。
func _create_app_config() -> GF_AppConfig:
	var r := GF_AppConfigLoader.new().load("res://")
	if r.is_fail():
		printerr("FATAL: 配置加载失败: " + r.error.message)
	return r.data if r.is_ok() else GF_AppConfig.new()


# ============================================================
# 公开 Installer 调用的 helpers
# ============================================================

func _fail_boot(p_source: String, p_result: GF_OperationResult) -> void:
	state = BootState.FAILED
	push_error("FATAL [%s]: %s" % [p_source, p_result.error.message])
	_cleanup_on_fail()

func _init_or_fail(p_module: GF_ModuleLifecycle) -> bool:
	var r := p_module.init_module()
	if r.is_fail(): _fail_boot(p_module.module_name, r); return false
	return true

func _cfg_or_fail(p_name: String, p_result: GF_OperationResult, p_module: GF_ModuleLifecycle = null) -> bool:
	if p_result.is_fail():
		if p_module != null: p_module.fail_configuration(p_result)
		_fail_boot(p_name, p_result); return false
	if p_module != null: p_module.finalize_configuration()
	return true

func _track_module(p_module: GF_ModuleLifecycle) -> void:
	if not _boot_modules.has(p_module): _boot_modules.append(p_module)

func _track_node(p_node: Node) -> void:
	if not _boot_nodes.has(p_node): _boot_nodes.append(p_node)


func _cleanup_on_fail() -> void:
	for i in range(_boot_modules.size() - 1, -1, -1):
		var m := _boot_modules[i]
		if m != null and m.is_ready():
			m.dispose_module()
	for child in _boot_nodes:
		if GF_RuntimeUtilities.is_node_valid(child):
			child.queue_free()
	_boot_modules.clear()
	_boot_nodes.clear()


# ============================================================
# 内部
# ============================================================

func _build_registry_entries(p_deps: Dictionary) -> Array:
	return [
		[GF_ServiceRegistry.KEY_RUNTIME,       p_deps.runtime_svc],
		[GF_ServiceRegistry.KEY_PATH_RESOLVER,  p_deps.path_resolver],
		[GF_ServiceRegistry.KEY_FILE_SYSTEM,    p_deps.file_system],
		[GF_ServiceRegistry.KEY_EVENT_BUS,      p_deps.event_bus],
		[GF_ServiceRegistry.KEY_LOCALIZATION,   p_deps.loc_service],
		[GF_ServiceRegistry.KEY_DEBUG,          p_deps.debug_service],
		[GF_ServiceRegistry.KEY_FLOW,           p_deps.app_flow],
		[GF_ServiceRegistry.KEY_SAVE,           p_deps.save_service],
		[GF_ServiceRegistry.KEY_CONFIG_SERVICE, p_deps.config_svc],
		[GF_ServiceRegistry.KEY_RESOURCE,       p_deps.resource_svc],
		[GF_ServiceRegistry.KEY_ASSET_LOADING,  p_deps.asset_loading],
		[GF_ServiceRegistry.KEY_THREADING,      p_deps.threading_svc],
		[GF_ServiceRegistry.KEY_SCENE_FACTORY,  p_deps.scene_factory],
		[GF_ServiceRegistry.KEY_UI,             p_deps.ui_service],
		[GF_ServiceRegistry.KEY_SCENE_HOST,     p_deps.scene_host],
		[GF_ServiceRegistry.KEY_SCHEDULER,      p_deps.scheduler],
		[GF_ServiceRegistry.KEY_INPUT,          p_deps.input_service],
		[GF_ServiceRegistry.KEY_INPUT_ADAPTER,  p_deps.input_adapter],
		[GF_ServiceRegistry.KEY_AUDIO,          p_deps.audio_service],
		[GF_ServiceRegistry.KEY_AUDIO_RUNTIME,  p_deps.audio_runtime],
		[GF_ServiceRegistry.KEY_CONFIG,         p_deps.config],
		[GF_ServiceRegistry.KEY_LOG,            p_deps.log],
		[GF_ServiceRegistry.KEY_ECS_WORLD,      p_deps.ecs_world],
		[GF_ServiceRegistry.KEY_ECS_SCHEDULER,  p_deps.ecs_scheduler],
	]

func _build_game_services(p_deps: Dictionary) -> GF_GameServices:
	var s := GF_GameServices.new()
	s.config = p_deps.config
	s.log = p_deps.log
	s.scene_host = p_deps.scene_host
	s.save_service = p_deps.save_service
	s.input = p_deps.input_service
	s.ui = p_deps.ui_service
	s.audio = p_deps.audio_service
	s.config_service = p_deps.config_svc
	s.resource = p_deps.resource_svc
	s.event_bus = p_deps.event_bus
	s.loc = p_deps.loc_service
	s.debug = p_deps.debug_service
	s.app_flow = p_deps.app_flow
	s.scheduler = p_deps.scheduler
	s.runtime = p_deps.runtime_svc
	s.threading = p_deps.threading_svc
	s.ecs_world = p_deps.ecs_world
	s.ecs_scheduler = p_deps.ecs_scheduler
	s.file_system = p_deps.file_system
	return s

func _print_banner(p_config: GF_AppConfig, p_log: GF_LogService) -> void:
	var C := "[color=#00e5ff]"
	var T := "[color=#ffd740]"
	var W := "[color=#ffffff]"
	var X := "[/color]"
	var ver := Engine.get_version_info()
	var ver_str := "%d.%d" % [ver.major, ver.minor]
	p_log.info("Bootstrap", C + "╔══════════════════════════════════════════╗" + X)
	p_log.info("Bootstrap", C + "║" + X + "  " + T + p_config.app.name + X + "  " + C + "║" + X)
	p_log.info("Bootstrap", C + "║" + X + "  " + W + "v" + p_config.app.version + X + "  " + C + "║" + X)
	p_log.info("Bootstrap", C + "║" + X + "  " + W + "Godot %s  |  GDScript" % ver_str + X + "                " + C + "║" + X)
	p_log.info("Bootstrap", C + "╚══════════════════════════════════════════╝" + X)

func _print_config_summary(p_config: GF_AppConfig, p_log: GF_LogService) -> void:
	var rows := [
		["Environment", p_config.app.environment], ["GF_RuntimeMode", p_config.runtime.mode],
		["GF_SaveProvider", p_config.save.provider], ["GF_LogLevel", p_config.logging.level],
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
