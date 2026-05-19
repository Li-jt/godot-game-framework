## ConfigService
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
##   [/codeblock]
class_name ConfigService
extends ModuleLifecycle

var _file_system: FileSystemService = null
var _log: LogService = null
var _defs: Dictionary = {}        # String type_key -> Dictionary (id -> Variant)
var _validators: Dictionary = {}  # String type_key -> Array[DefValidator]


func _on_init() -> OperationResult:
	return OperationResult.ok()


func configure(p_file_system: FileSystemService, p_log: LogService) -> OperationResult:
	if p_file_system == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: file_system 不能为 null", module_name)
	if p_log == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: log 不能为 null", module_name)
	_file_system = p_file_system
	_log = p_log
	return OperationResult.ok()


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
func load_json(p_type_key: String, p_path: String) -> OperationResult:
	var result := _file_system.read_json(p_path)
	if result.is_fail():
		_log.error("ConfigService", "加载失败: %s → %s" % [p_type_key, p_path])
		return result

	var data := result.data as Dictionary
	register_defs(p_type_key, data)
	_log.info("ConfigService", "已加载: %s (%d 条)" % [p_type_key, data.size()])
	return OperationResult.ok()


# ============================================================
# 查询
# ============================================================

## 按 ID 获取单条定义，不存在返回 null
func get_def(p_type_key: String, p_id: String):
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


## 注册校验器。Game 层在加载 Def 后调用。
func register_validator(p_validator: DefValidator) -> void:
	if not _validators.has(p_validator.type_key):
		_validators[p_validator.type_key] = []
	_validators[p_validator.type_key].append(p_validator)


## 校验所有已注册类型的定义。返回第一个失败或 ok。
## 校验错误列表在 error.context["errors"] 中。
func validate_all() -> OperationResult:
	var all_errors: Array[String] = []

	for type_key in _defs.keys():
		var defs: Dictionary = _defs[type_key]
		if _validators.has(type_key):
			for validator in _validators[type_key]:
				var errors = validator.validate(defs)
				for err in errors:
					all_errors.append("[%s] %s" % [type_key, err])

	if all_errors.is_empty():
		return OperationResult.ok()

	var result := OperationResult.fail(
		OperationResult.ERR_VALIDATION,
		"Def 校验失败，共 %d 个错误" % all_errors.size(),
		module_name
	)
	result.error.context["errors"] = all_errors
	return result


## 获取某类型的定义数量
func count(p_type_key: String) -> int:
	var type_defs: Dictionary = _defs.get(p_type_key, {})
	return type_defs.size()
