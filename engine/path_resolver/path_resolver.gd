## GF_PathResolver
## 统一路径解析服务。所有模块的路径必须通过此服务获取，禁止自行拼路径。
##
## 路径约定：
##   res://  用于随游戏发布的只读资源（config、content）
##   user:// 用于运行时可写的用户数据（saves、logs、cache）
##
## 使用方式：
##   [codeblock]
##   var pr := GF_PathResolver.new()
##   pr.configure_from_app_config(app_config)
##   var save_path := pr.get_save_root()  # user://saves/
##   var log_path := pr.get_log_root()    # user://logs/
##   [/codeblock]
class_name GF_PathResolver
extends RefCounted

# ============================================================
# 路径属性（configure 后可用）
# ============================================================

var config_root: String = ""     # res://config/
var resource_root: String = ""   # res://content/
var save_root: String = ""       # user://saves/
var log_root: String = ""        # user://logs/
var cache_root: String = ""      # user://cache/
var _app_config: GF_AppConfig = null  ## 保留 GF_AppConfig 引用用于路径覆盖解析


## 从 GF_AppConfig 配置所有路径
func configure_from_app_config(p_config: GF_AppConfig) -> GF_OperationResult:
	if p_config == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: config 不能为 null", "GF_PathResolver")
	_app_config = p_config
	return configure(
		p_config.resource.base_path,
		p_config.save.local_save_root,
		p_config.save.local_cache_root,
		p_config.logging.log_root
	)


## 显式配置各路径，拒绝空路径
func configure(p_resource_base: String, p_save_root: String, p_cache_root: String, p_log_root: String) -> GF_OperationResult:
	if p_resource_base.is_empty():
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: resource_base 不能为空", "GF_PathResolver")
	if p_save_root.is_empty():
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: save_root 不能为空", "GF_PathResolver")
	if p_log_root.is_empty():
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: log_root 不能为空", "GF_PathResolver")

	config_root = _to_res("config")
	resource_root = _to_res(p_resource_base)
	save_root = _to_user(p_save_root)
	log_root = _to_user(p_log_root)
	cache_root = _to_user(p_cache_root)
	return GF_OperationResult.ok()


# ============================================================
# 路径获取
# ============================================================

func get_config_root() -> String:
	return config_root


func get_resource_root() -> String:
	return resource_root


func get_save_root() -> String:
	return save_root


func get_log_root() -> String:
	return log_root


func get_cache_root() -> String:
	return cache_root


# ============================================================
# 路径覆盖解析（支持 GF_AppConfig.path_overrides 配置覆盖）
# ============================================================

## 解析 GF_SceneHost 场景路径。优先取配置覆盖值，否则返回默认路径。
func resolve_scene_host_path(p_default: String = "res://addons/godot-game-framework/engine/scene_host/scene_host.tscn") -> String:
	if _app_config != null:
		var override := _app_config.path_overrides.scene_host
		if not override.is_empty():
			return override
	return p_default

## 解析世界场景路径。
func resolve_world_scene(p_default: String = "res://content/scenes/world/world_root.tscn") -> String:
	if _app_config != null:
		var override := _app_config.path_overrides.world_scene
		if not override.is_empty():
			return override
	return p_default

## 解析本地化文件根目录。
func resolve_localization_root(p_default: String = "res://content/localization") -> String:
	if _app_config != null:
		var override := _app_config.path_overrides.localization_root
		if not override.is_empty():
			return override
	return p_default

## 解析输入重绑文件路径。
func resolve_input_bindings_path(p_default: String = "user://input_bindings_v1.tres") -> String:
	if _app_config != null:
		var override := _app_config.path_overrides.input_bindings_path
		if not override.is_empty():
			return override
	return p_default


# ============================================================
# 工具方法
# ============================================================

## 确保目录存在，返回是否成功（或已存在）
func ensure_dir(p_path: String) -> bool:
	if DirAccess.dir_exists_absolute(p_path):
		return true
	var err := DirAccess.make_dir_recursive_absolute(p_path)
	return err == OK


## 在 res:// 下拼接路径并确保以 / 结尾
func res_path(p_relative: String) -> String:
	return _to_res(p_relative)


## 在 user:// 下拼接路径并确保以 / 结尾
func user_path(p_relative: String) -> String:
	return _to_user(p_relative)


## 路径标准化：去开头的 `./`、去 `/./`、合并 `//`、统一斜杠。
## 注意：保护 res:// 和 user:// 前缀不被误修改。
static func normalize(p_path: String) -> String:
	var s := p_path.replace("\\", "/")
	var prefix := ""
	if s.begins_with("res://"):
		prefix = "res://"
		s = s.substr(6)
	elif s.begins_with("user://"):
		prefix = "user://"
		s = s.substr(7)
	# 去掉开头的 ./
	if s.begins_with("./"):
		s = s.substr(2)
	while s.find("//") >= 0:
		s = s.replace("//", "/")
	while s.find("/./") >= 0:
		s = s.replace("/./", "/")
	s = s.strip_edges()
	return prefix + s


## 校验路径未越出指定根目录。包含 `../` 的路径会被拒绝。
## 自动确保 p_root 以 / 结尾以便 begins_with 比较。
static func ensure_under_root(p_path: String, p_root: String) -> GF_OperationResult:
	var normalized := normalize(p_path)
	# 确保 root 以 / 结尾，避免 "res://data" 无法匹配 "res://data/file.json"
	var root := p_root
	if not root.ends_with("/"):
		root += "/"
	if normalized.find("../") >= 0:
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_FORBIDDEN,
			"路径包含越界引用 ../: %s" % p_path,
			"GF_PathResolver"
		)
	if not normalized.begins_with(root):
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_FORBIDDEN,
			"路径不在允许的根目录下: %s (root: %s)" % [p_path, p_root],
			"GF_PathResolver"
		)
	return GF_OperationResult.ok()


# ============================================================
# 内部
# ============================================================

func _to_res(p_relative: String) -> String:
	var cleaned := _strip_dot_slash(p_relative)
	return "res://%s/" % cleaned if not cleaned.ends_with("/") else "res://%s" % cleaned


func _to_user(p_relative: String) -> String:
	var cleaned := _strip_dot_slash(p_relative)
	return "user://%s/" % cleaned if not cleaned.ends_with("/") else "user://%s" % cleaned


func _strip_dot_slash(p_path: String) -> String:
	var s := p_path.strip_edges()
	if s.begins_with("./"):
		s = s.substr(2)
	while s.ends_with("/"):
		s = s.rstrip("/")
	return s
