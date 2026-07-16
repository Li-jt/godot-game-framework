## ServiceRegistry
## 服务注册中心（Application 层基础设施）。
## 仅供 AppBootstrap 装配阶段和 Framework 内部使用。
## Game 层禁止直接访问，应通过注入的 context（GameServices）获取所需服务。
##
## 支持：
##   - 优先级覆盖：高优先级可覆盖低优先级同名服务
##   - 必需 key 声明：各 Installer 自声明自己产出的必需服务
##   - Mod 卸载：按 owner 批量注销
class_name ServiceRegistry
extends RefCounted

# 标准服务 Key 常量
const KEY_AUDIO_RUNTIME: String = "AudioRuntime"
const KEY_INPUT_ADAPTER: String = "InputAdapter"
const KEY_SCHEDULER: String = "Scheduler"
const KEY_SCENE_HOST: String = "SceneHost"
const KEY_SCENE_FACTORY: String = "SceneFactory"
const KEY_ASSET_LOADING: String = "AssetLoading"
const KEY_THREADING: String = "Threading"
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
const KEY_ECS_WORLD: String = "EcsWorld"
const KEY_ECS_SCHEDULER: String = "EcsScheduler"
const KEY_ECS_DEBUG: String = "EcsDebug"
const KEY_ECS_SAVE_ADAPTER: String = "EcsSaveAdapter"

# 全局单例引用（由 AppBootstrap 在启动时赋值）
static var instance: ServiceRegistry = null

## Framework 内部获取实例（ISaveable 自注册等场景使用）
static func get_instance() -> ServiceRegistry:
	return instance

var _services: Dictionary = {}          ## {String: Object}
var _owners: Dictionary = {}            ## {String: String}  key → owner_name
var _priorities: Dictionary = {}        ## {String: int}     key → priority
var _pending_required: Array[String] = []  ## 待校验的必需 key 列表


## 注册一个服务（默认 priority=100）。
func register(p_key: String, p_service: Object) -> OperationResult:
	return register_with_priority(p_key, p_service, "system", 100)


## 注册所有条目。
func register_all(p_entries: Array) -> OperationResult:
	for entry in p_entries:
		var pair: Array = entry as Array
		var key: String = pair[0] as String
		var svc = pair[1]
		var result := register(key, svc)
		if result.is_fail():
			return result
	return OperationResult.ok()


## 带优先级和服务所有者标识的注册方法。
## p_priority: 数值越小优先级越高。同名 key 覆盖时，只有更高优先级的可以覆盖。
## p_owner: 注册者标识（如 "core_installer" 或 "mod:fishing"）。
func register_with_priority(p_key: String, p_service: Object, p_owner: String = "system", p_priority: int = 100) -> OperationResult:
	if p_key.is_empty():
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "注册失败: key 不能为空", "ServiceRegistry")
	if p_service == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "注册失败: service 不能为 null (key=%s)" % p_key, "ServiceRegistry")

	if _services.has(p_key):
		var existing_priority: int = _priorities.get(p_key, 100)
		var existing_owner: String = _owners.get(p_key, "system")
		if p_priority >= existing_priority:
			return OperationResult.fail(
				OperationResult.ERR_CONFLICT, "ServiceRegistry",
				"服务 '%s' 已被 '%s' (priority=%d) 注册, 无法被 '%s' (priority=%d) 覆盖" % [p_key, existing_owner, existing_priority, p_owner, p_priority]
			)
		push_warning("[ServiceRegistry] 服务 '%s' 被 '%s' 覆盖 (原有: '%s')" % [p_key, p_owner, existing_owner])

	if p_service is ModuleLifecycle:
		var ml := p_service as ModuleLifecycle
		if not ml.is_ready():
			return OperationResult.fail(OperationResult.ERR_PRECONDITION, "注册失败: 模块未 ready (key=%s, state=%d)" % [p_key, ml.state], "ServiceRegistry")

	_services[p_key] = p_service
	_owners[p_key] = p_owner
	_priorities[p_key] = p_priority
	return OperationResult.ok()


## 注销服务。Mod 卸载时使用。p_owner 非空时会校验所有权。
func unregister(p_key: String, p_owner: String = "") -> OperationResult:
	if not _services.has(p_key):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "ServiceRegistry", "服务 '%s' 不存在" % p_key)
	if not p_owner.is_empty() and _owners.get(p_key, "") != p_owner:
		return OperationResult.fail(OperationResult.ERR_PERMISSION_DENIED, "ServiceRegistry", "'%s' 无权卸载 '%s' 的服务" % [p_owner, p_key])
	_services.erase(p_key)
	_owners.erase(p_key)
	_priorities.erase(p_key)
	return OperationResult.ok()


## 按 owner 批量注销所有服务。Mod 卸载时使用。
func unregister_by_owner(p_owner: String) -> int:
	var removed := 0
	var keys_to_remove: Array[String] = []
	for key in _owners:
		if _owners[key] == p_owner:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_services.erase(key)
		_owners.erase(key)
		_priorities.erase(key)
		removed += 1
	return removed


## 添加一个必需 key 到待校验列表。各 Installer 负责调用。
func add_required(p_key: String) -> void:
	if not _pending_required.has(p_key):
		_pending_required.append(p_key)


## 校验所有通过 add_required 声明的必需 key 是否已注册且就绪。
func verify_pending() -> OperationResult:
	var missing: Array[String] = []
	for key in _pending_required:
		if not _services.has(key):
			missing.append(key)
			continue
		var svc = _services[key]
		if svc is ModuleLifecycle:
			var ml := svc as ModuleLifecycle
			if not ml.is_ready():
				missing.append(key + " (not ready)")
		elif svc.has_method("is_runtime_ready"):
			if not svc.is_runtime_ready():
				missing.append(key + " (runtime not ready)")
	if not missing.is_empty():
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "ServiceRegistry", "缺失必需服务: %s" % ", ".join(missing))
	return OperationResult.ok()


## 向后兼容：从外部数组校验必需 key。
func verify_required(p_keys: Array[String]) -> OperationResult:
	# 将外部声明的 key 合并到 pending 列表，然后统一校验
	for key in p_keys:
		if not _pending_required.has(key):
			_pending_required.append(key)
	return verify_pending()


func get_service(p_key: String) -> Variant:
	return _services.get(p_key, null)


func has(p_key: String) -> bool:
	return _services.has(p_key)


func count() -> int:
	return _services.size()


## 获取服务的注册者。
func owner_of(p_key: String) -> String:
	return _owners.get(p_key, "")


# 类型化便捷访问器
func get_config() -> AppConfig: return _services.get(KEY_CONFIG, null) as AppConfig
func get_audio_runtime() -> AudioRuntime: return _services.get(KEY_AUDIO_RUNTIME, null) as AudioRuntime
func get_input_adapter() -> InputAdapter: return _services.get(KEY_INPUT_ADAPTER, null) as InputAdapter
func get_scheduler() -> Scheduler: return _services.get(KEY_SCHEDULER, null) as Scheduler
func get_scene_host() -> SceneHost: return _services.get(KEY_SCENE_HOST, null) as SceneHost
func get_scene_factory() -> SceneFactory: return _services.get(KEY_SCENE_FACTORY, null) as SceneFactory
func get_asset_loading() -> AssetLoadingService: return _services.get(KEY_ASSET_LOADING, null) as AssetLoadingService
func get_threading(): return _services.get(KEY_THREADING, null)
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
func get_ecs_world() -> EcsWorld: return _services.get(KEY_ECS_WORLD, null) as EcsWorld
func get_ecs_scheduler() -> EcsScheduler: return _services.get(KEY_ECS_SCHEDULER, null) as EcsScheduler
