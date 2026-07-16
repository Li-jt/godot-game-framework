## ResourceService
## 项目级统一资源读取服务。带缓存、资源分组和释放策略。
##
## 使用方式：
##   [codeblock]
##   var res := context.resource
##   var r := res.load_texture("textures/icon.png", ResourceService.ResourceGroup.UI_COMMON)
##   res.release_group(ResourceService.ResourceGroup.LEVEL_01)
##   [/codeblock]
class_name ResourceService
extends ModuleLifecycle

## 资源分组——StringName 常量。Framework 提供默认值，Mod 使用自己的标识。
const GROUP_UI_COMMON: StringName = &"ui_common"
const GROUP_GAMEPLAY: StringName = &"gameplay"
const GROUP_LEVEL_01: StringName = &"level_01"
const GROUP_LEVEL_02: StringName = &"level_02"
const GROUP_AUDIO: StringName = &"audio"

enum ReleasePolicy {
	LRU_ONLY,         # 仅 LRU 回收（默认）
	ON_SCENE_EXIT,    # 场景退出时释放
}

class CacheEntry:
	var resource: Resource
	var group: StringName


var _asset_loading: AssetLoadingService = null
var _log: LogService = null
var _cache: Dictionary = {}            # String path -> CacheEntry
var _cache_order: Array[String] = []   # LRU 顺序
const MAX_UNCACHED: int = 200

var _release_policy: ReleasePolicy = ReleasePolicy.LRU_ONLY


func _on_init() -> OperationResult:
	return OperationResult.ok()


func configure(p_asset_loading: AssetLoadingService, p_log: LogService) -> OperationResult:
	if p_asset_loading == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: asset_loading 不能为 null", module_name)
	if p_log == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: log 不能为 null", module_name)
	_asset_loading = p_asset_loading
	_log = p_log
	return OperationResult.ok()


# ============================================================
# 加载
# ============================================================

func load_scene(p_path: String, p_group: StringName = GROUP_GAMEPLAY) -> OperationResult:
	return _cached_load(p_path, p_group, func(p): return _asset_loading.load_scene(p))


func load_texture(p_path: String, p_group: StringName = GROUP_GAMEPLAY) -> OperationResult:
	return _cached_load(p_path, p_group, func(p): return _asset_loading.load_texture(p))


func load_audio(p_path: String, p_group: StringName = GROUP_AUDIO) -> OperationResult:
	return _cached_load(p_path, p_group, func(p): return _asset_loading.load_audio(p))


func load_resource(p_path: String, p_group: StringName = GROUP_GAMEPLAY) -> OperationResult:
	return _cached_load(p_path, p_group, func(p): return _asset_loading.load_resource(p))


# ============================================================
# 分组释放
# ============================================================

## 释放指定资源组。场景切换时调用。
## 保留 UI_COMMON / GAMEPLAY / AUDIO 组资源。
func release_group(p_group: StringName) -> void:
	var to_remove: Array[String] = []
	for path in _cache.keys():
		var entry: CacheEntry = _cache[path]
		if entry.group == p_group:
			to_remove.append(path)
	for path in to_remove:
		_cache.erase(path)
		_cache_order.erase(path)
	_log.info("Resource", "释放资源组: %d 个" % to_remove.size())


# ============================================================
# 缓存管理
# ============================================================

func set_release_policy(p_policy: ReleasePolicy) -> void:
	_release_policy = p_policy


func clear_cache() -> void:
	_cache.clear()
	_cache_order.clear()


func evict(p_path: String) -> void:
	_cache.erase(p_path)
	_cache_order.erase(p_path)


func cache_size() -> int:
	return _cache.size()


# ============================================================
# 内部
# ============================================================

func _cached_load(p_path: String, p_group: StringName, p_loader: Callable) -> OperationResult:
	if _cache.has(p_path):
		var entry: CacheEntry = _cache[p_path]
		_touch_order(p_path)
		_log.debug("Resource", "缓存命中: %s" % p_path)
		return OperationResult.ok(entry.resource)

	_lru_evict_if_needed()

	var result = p_loader.call(p_path)
	if result.is_ok():
		var entry := CacheEntry.new()
		entry.resource = result.data
		entry.group = p_group
		_cache[p_path] = entry
		_cache_order.append(p_path)
	return result


func _lru_evict_if_needed() -> void:
	while _cache.size() >= MAX_UNCACHED:
		var path := _cache_order[0] if _cache_order.size() > 0 else ""
		if path.is_empty(): break
		_cache_order.pop_front()
		_cache.erase(path)


func _touch_order(p_path: String) -> void:
	_cache_order.erase(p_path)
	_cache_order.append(p_path)
