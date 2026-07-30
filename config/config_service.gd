## GF_ConfigService
## 游戏内容定义仓库。管理 ItemDef、BuildingDef 等游戏配置数据。
##
## Framework 只负责存储和查询机制（按类型+ID 索引），
## 不关心具体 Def 的字段结构。Game 层定义 Def 类型并注册到此服务。
##
## 使用方式：
##   [codeblock]
##   # Game 层注册
##   config.register_defs("items", loaded_item_dict)
##   config.load_json("buildings", "res://content/defs/buildings.json")
##
##   # 查询
##   var item = config.get_def("items", "wood")
##   var all_buildings = config.get_all("buildings")
##
##   # 开发期热重载
##   config.load_json("buildings", "res://content/defs/buildings.json", true)
##   # 每帧或定时调用：
##   var reloaded := config.check_hot_reload()
##   if not reloaded.is_empty():
##       # 重新校验或刷新 UI
##   [/codeblock]
class_name GF_ConfigService
extends GF_ModuleLifecycle

var _file_system: GF_FileSystemService = null
var _log: GF_LogService = null
var _defs: Dictionary = {}        # String type_key -> Dictionary (id -> Variant)
var _validators: Dictionary = {}  # String type_key -> Array[GF_DefValidator]

# 热重载跟踪：String path -> {type_key: String, last_modified: int}
var _hot_watch: Dictionary = {}


func _on_init() -> GF_OperationResult:
	return GF_OperationResult.ok()


func configure(p_file_system: GF_FileSystemService, p_log: GF_LogService) -> GF_OperationResult:
	if p_file_system == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: file_system 不能为 null", module_name)
	if p_log == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: log 不能为 null", module_name)
	_file_system = p_file_system
	_log = p_log
	return GF_OperationResult.ok()


# ============================================================
# 注册
# ============================================================

## 注册一个类型的全部定义。p_type_key 如 "items"、"buildings"。
## p_defs 为 Dictionary[id -> 定义数据]。
func register_defs(p_type_key: String, p_defs: Dictionary) -> void:
	if not _defs.has(p_type_key):
		_defs[p_type_key] = {}
	var target: Dictionary = _defs[p_type_key]
	for id in p_defs.keys():
		target[id] = p_defs[id]


## 注册单个定义
func register_def(p_type_key: String, p_id: String, p_def) -> void:
	if not _defs.has(p_type_key):
		_defs[p_type_key] = {}
	_defs[p_type_key][p_id] = p_def


# ============================================================
# JSON 加载
# ============================================================

## 从 JSON 文件加载定义。JSON 应为顶级 Dictionary，key 为 def id。
## [param p_hot_reload] 为 true 时自动对此文件启用热重载跟踪。
func load_json(p_type_key: String, p_path: String, p_hot_reload: bool = false) -> GF_OperationResult:
	var result := _file_system.read_json(p_path)
	if result.is_fail():
		_log.error("GF_ConfigService", "加载失败: %s → %s" % [p_type_key, p_path])
		return result

	var data := result.data as Dictionary
	register_defs(p_type_key, data)
	_log.info("GF_ConfigService", "已加载: %s (%d 条)" % [p_type_key, data.size()])

	if p_hot_reload:
		_enable_hot_reload(p_type_key, p_path)

	return GF_OperationResult.ok()


# ============================================================
# 查询
# ============================================================

## 按 ID 获取单条定义，不存在返回 null
func get_def(p_type_key: String, p_id: String) -> Variant:
	var type_defs: Dictionary = _defs.get(p_type_key, {})
	return type_defs.get(p_id, null)


## 获取某类型的所有定义
func get_all(p_type_key: String) -> Dictionary:
	return _defs.get(p_type_key, {})


## 某类型是否存在指定 ID
func has_def(p_type_key: String, p_id: String) -> bool:
	var type_defs: Dictionary = _defs.get(p_type_key, {})
	return type_defs.has(p_id)


## 某类型是否已注册
func has_type(p_type_key: String) -> bool:
	return _defs.has(p_type_key)


## 获取所有已注册的类型 key
func get_types() -> Array:
	return _defs.keys()


# ============================================================
# 校验
# ============================================================

## 注册校验器。Game 层在加载 Def 后调用。
func register_validator(p_validator: GF_DefValidator) -> void:
	if not _validators.has(p_validator.type_key):
		_validators[p_validator.type_key] = []
	_validators[p_validator.type_key].append(p_validator)


## 校验所有已注册类型的定义。返回第一个失败或 ok。
## 校验错误列表在 error.context["errors"] 中。
func validate_all() -> GF_OperationResult:
	var all_errors: Array[String] = []

	for type_key in _defs.keys():
		var defs: Dictionary = _defs[type_key]
		if _validators.has(type_key):
			for validator in _validators[type_key]:
				var errors = validator.validate(defs)
				for err in errors:
					all_errors.append("[%s] %s" % [type_key, err])

	if all_errors.is_empty():
		return GF_OperationResult.ok()

	var result := GF_OperationResult.fail(
		GF_OperationResult.ERR_VALIDATION,
		"Def 校验失败，共 %d 个错误" % all_errors.size(),
		module_name
	)
	result.error.context["errors"] = all_errors
	return result


## 校验指定类型的定义。热重载后自动调用。
func validate_type(p_type_key: String) -> GF_OperationResult:
	if not _validators.has(p_type_key):
		return GF_OperationResult.ok()

	var defs: Dictionary = _defs.get(p_type_key, {})
	var errors: Array[String] = []
	for validator in _validators[p_type_key]:
		var type_errors = validator.validate(defs)
		for err in type_errors:
			errors.append("[%s] %s" % [p_type_key, err])

	if errors.is_empty():
		return GF_OperationResult.ok()

	var result := GF_OperationResult.fail(
		GF_OperationResult.ERR_VALIDATION,
		"热重载校验失败 [%s]，共 %d 个错误" % [p_type_key, errors.size()],
		module_name
	)
	result.error.context["errors"] = errors
	return result


# ============================================================
# 查询
# ============================================================

## 获取某类型的定义数量
func count(p_type_key: String) -> int:
	var type_defs: Dictionary = _defs.get(p_type_key, {})
	return type_defs.size()


# ============================================================
# 热重载
# ============================================================

## 对已加载的 JSON 文件启用热重载跟踪。
## 之后需在游戏主循环中周期性调用 check_hot_reload() 检测文件变化。
func enable_hot_reload(p_type_key: String, p_path: String) -> void:
	_enable_hot_reload(p_type_key, p_path)


## 检测所有热重载文件是否变化。如果有更新，自动重新加载并校验。
## 返回被重新加载的 type_key 列表。调用方据此决定是否需要刷新 UI 或重建系统。
## [br]
## 典型调用方式：在 Scheduler 或 _process 中每 1-2 秒调用一次。
func check_hot_reload() -> Array[String]:
	var reloaded: Array[String] = []

	for path in _hot_watch.keys():
		if not _file_system.file_exists(path):
			_log.warning("GF_ConfigService", "热重载文件不存在: %s，跳过" % path)
			continue

		var mtime := _file_system.get_modified_time(path)
		var info: Dictionary = _hot_watch[path]
		if mtime <= info.last_modified:
			continue

		# 更新时间戳（先更新再加载，防止加载失败后反复重试同一文件）
		info.last_modified = mtime

		var result := load_json(info.type_key, path)
		if result.is_fail():
			_log.error("GF_ConfigService", "热重载失败: %s ← %s" % [info.type_key, path])
			continue

		# 重载后自动校验
		var validation := validate_type(info.type_key)
		if validation.is_fail():
			var validation_errors: Array = validation.error.context.get("errors", [])
			for err in validation_errors:
				_log.warning("GF_ConfigService", "热重载校验警告: %s" % err)

		reloaded.append(info.type_key)
		_log.info("GF_ConfigService", "热重载完成: %s ← %s (%d 条)" % [info.type_key, path, count(info.type_key)])

	return reloaded


## 停止对指定路径的热重载跟踪。
func disable_hot_reload(p_path: String) -> void:
	if _hot_watch.has(p_path):
		_hot_watch.erase(p_path)
		_log.info("GF_ConfigService", "已停止热重载: %s" % p_path)


## 停止所有热重载跟踪。
func disable_all_hot_reloads() -> void:
	_hot_watch.clear()
	_log.info("GF_ConfigService", "已停止全部热重载")


## 查询某个路径是否启用了热重载。
func is_hot_reload_enabled(p_path: String) -> bool:
	return _hot_watch.has(p_path)


## 获取所有热重载跟踪的路径。
func get_hot_reload_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in _hot_watch.keys():
		paths.append(path)
	return paths


# ============================================================
# 内部
# ============================================================

func _enable_hot_reload(p_type_key: String, p_path: String) -> void:
	if _hot_watch.has(p_path):
		return
	var mtime := 0
	if _file_system.file_exists(p_path):
		mtime = _file_system.get_modified_time(p_path)
	_hot_watch[p_path] = {"type_key": p_type_key, "last_modified": mtime}
	_log.info("GF_ConfigService", "已启用热重载: %s ← %s" % [p_type_key, p_path])
