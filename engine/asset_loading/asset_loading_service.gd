## AssetLoadingService
## 统一资源加载服务，封装 Godot 的 load() / ResourceLoader.load()。
## 所有模块的资源加载必须通过此服务，禁止直接使用 load()。
##
## 使用方式：
##   [codeblock]
##   var result := service.load_scene("scenes/main_menu.tscn")
##   if result.is_ok():
##       var scene: PackedScene = result.data
##   [/codeblock]
class_name AssetLoadingService
extends ModuleLifecycle

var _path_resolver: PathResolver = null
var _log: LogService = null


func configure(p_path_resolver: PathResolver, p_log: LogService) -> OperationResult:
	if p_path_resolver == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: path_resolver 不能为 null", module_name)
	if p_log == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: log 不能为 null", module_name)
	_path_resolver = p_path_resolver
	_log = p_log
	return OperationResult.ok()


# ============================================================
# 公开加载方法
# ============================================================

## 加载 PackedScene
func load_scene(p_path: String) -> OperationResult:
	return _load(p_path, "PackedScene")


## 加载 Texture2D（贴图、精灵）
func load_texture(p_path: String) -> OperationResult:
	return _load(p_path, "Texture2D")


## 加载 AudioStream（BGM、SFX）
func load_audio(p_path: String) -> OperationResult:
	return _load(p_path, "AudioStream")


## 加载任意 Resource（配置 Def、字体等）
func load_resource(p_path: String) -> OperationResult:
	return _load(p_path, "Resource")


# ============================================================
# 内部
# ============================================================

func _load(p_path: String, p_type_label: String) -> OperationResult:
	var full_path := _resolve(p_path)

	if not ResourceLoader.exists(full_path):
		_log.warning("AssetLoading", "资源不存在: %s" % full_path)
		return OperationResult.fail(
			OperationResult.ERR_NOT_FOUND,
			"%s 不存在: %s" % [p_type_label, full_path],
			module_name
		)

	var res := load(full_path)
	if res == null:
		_log.error("AssetLoading", "加载失败: %s" % full_path)
		return OperationResult.fail(
			OperationResult.ERR_IO,
			"%s 加载失败: %s" % [p_type_label, full_path],
			module_name
		)

	_log.debug("AssetLoading", "已加载 %s: %s" % [p_type_label, full_path])
	return OperationResult.ok(res)


## 路径解析：如果已经是 res:// 或 user:// 开头则直接用，否则拼到 resource_root 下
func _resolve(p_path: String) -> String:
	if p_path.begins_with("res://") or p_path.begins_with("user://"):
		return p_path
	if _path_resolver != null:
		return _path_resolver.get_resource_root().path_join(p_path)
	return "res://".path_join(p_path)
