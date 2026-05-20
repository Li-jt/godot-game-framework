## ServiceRegistry
## 服务注册中心（Application 层基础设施）。
## 仅供 AppBootstrap 装配阶段和 Framework 内部使用。
## Game 层禁止直接访问，应通过注入的 context（GameServices）获取所需服务。
class_name ServiceRegistry
extends RefCounted

# 标准服务 Key 常量
const KEY_AUDIO_RUNTIME: String = "AudioRuntime"
const KEY_INPUT_ADAPTER: String = "InputAdapter"
const KEY_SCHEDULER: String = "Scheduler"
const KEY_SCENE_HOST: String = "SceneHost"
const KEY_SCENE_FACTORY: String = "SceneFactory"
const KEY_ASSET_LOADING: String = "AssetLoading"
const KEY_FILE_SYSTEM: String = "FileSystem"
const KEY_PATH_RESOLVER: String = "PathResolver"
const KEY_CONFIG: String = "Config"
const KEY_CONFIG_SERVICE: String = "ConfigService"
const KEY_LOG: String = "Log"
const KEY_EVENT_BUS: String = "EventBus"
const KEY_FLOW: String = "Flow"
const KEY_RESOURCE: String = "Resource"
const KEY_INPUT: String = "Input"
const KEY_UI: String = "UI"
const KEY_AUDIO: String = "Audio"
const KEY_SAVE: String = "Save"
const KEY_RUNTIME: String = "Runtime"
const KEY_LOCALIZATION: String = "Localization"
const KEY_DEBUG: String = "Debug"
const KEY_COMMAND: String = "Command"
const KEY_NETWORK: String = "Network"
const KEY_DATA_ACCESS: String = "DataAccess"

# 全局单例引用（由 AppBootstrap 在启动时赋值）
static var instance: ServiceRegistry = null

## Framework 内部获取实例（ISaveable 自注册等场景使用）
static func get_instance() -> ServiceRegistry:
	return instance

var _services: Dictionary = {}


func register(p_key: String, p_service: Object) -> OperationResult:
	if p_key.is_empty():
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "注册失败: key 不能为空", "ServiceRegistry")
	if p_service == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "注册失败: service 不能为 null (key=%s)" % p_key, "ServiceRegistry")
	if _services.has(p_key):
		return OperationResult.fail(OperationResult.ERR_CONFLICT, "注册失败: key 重复 (key=%s)" % p_key, "ServiceRegistry")
	if p_service is ModuleLifecycle:
		var ml := p_service as ModuleLifecycle
		if not ml.is_ready():
			return OperationResult.fail(OperationResult.ERR_PRECONDITION, "注册失败: 模块未 ready (key=%s, state=%d)" % [p_key, ml.state], "ServiceRegistry")

	_services[p_key] = p_service
	return OperationResult.ok()


func register_all(p_entries: Array) -> OperationResult:
	for entry in p_entries:
		var pair: Array = entry as Array
		var key: String = pair[0] as String
		var svc = pair[1]
		var result := register(key, svc)
		if result.is_fail():
			return result
	return OperationResult.ok()


func verify_required(p_keys: Array[String]) -> OperationResult:
	for key in p_keys:
		if not _services.has(key):
			return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "缺少必需服务: %s" % key, "ServiceRegistry")
		var svc = _services[key]
		if svc is ModuleLifecycle:
			var ml := svc as ModuleLifecycle
			if not ml.is_ready():
				return OperationResult.fail(OperationResult.ERR_PRECONDITION, "必需服务未 ready: %s" % key, "ServiceRegistry")
		if svc.has_method("is_runtime_ready"):
			if not svc.is_runtime_ready():
				return OperationResult.fail(OperationResult.ERR_PRECONDITION, "必需服务运行时未就绪: %s" % key, "ServiceRegistry")
	return OperationResult.ok()


func get_service(p_key: String) -> Variant:
	return _services.get(p_key, null)


func has(p_key: String) -> bool:
	return _services.has(p_key)


func count() -> int:
	return _services.size()


# 类型化便捷访问器
func get_config() -> AppConfig: return _services.get(KEY_CONFIG, null) as AppConfig
func get_audio_runtime() -> AudioRuntime: return _services.get(KEY_AUDIO_RUNTIME, null) as AudioRuntime
func get_input_adapter() -> InputAdapter: return _services.get(KEY_INPUT_ADAPTER, null) as InputAdapter
func get_scheduler() -> Scheduler: return _services.get(KEY_SCHEDULER, null) as Scheduler
func get_scene_host() -> SceneHost: return _services.get(KEY_SCENE_HOST, null) as SceneHost
func get_scene_factory() -> SceneFactory: return _services.get(KEY_SCENE_FACTORY, null) as SceneFactory
func get_asset_loading() -> AssetLoadingService: return _services.get(KEY_ASSET_LOADING, null) as AssetLoadingService
func get_file_system() -> FileSystemService: return _services.get(KEY_FILE_SYSTEM, null) as FileSystemService
func get_path_resolver() -> PathResolver: return _services.get(KEY_PATH_RESOLVER, null) as PathResolver
func get_audio_service() -> AudioService: return _services.get(KEY_AUDIO, null) as AudioService
func get_input_service() -> InputService: return _services.get(KEY_INPUT, null) as InputService
func get_config_service() -> ConfigService: return _services.get(KEY_CONFIG_SERVICE, null) as ConfigService
func get_runtime_service() -> RuntimeService: return _services.get(KEY_RUNTIME, null) as RuntimeService
func get_save_service() -> SaveService: return _services.get(KEY_SAVE, null) as SaveService
func get_ui_service() -> UIService: return _services.get(KEY_UI, null) as UIService
func get_resource() -> ResourceService: return _services.get(KEY_RESOURCE, null) as ResourceService
func get_app_flow() -> AppFlow: return _services.get(KEY_FLOW, null) as AppFlow
func get_event_bus() -> EventBus: return _services.get(KEY_EVENT_BUS, null) as EventBus
func get_log() -> LogService: return _services.get(KEY_LOG, null) as LogService
