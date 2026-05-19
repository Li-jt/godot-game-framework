## LocalizationService
## 本地化服务。管理多语言文本的加载和查询。
class_name LocalizationService
extends ModuleLifecycle

var _current_locale: String = "zh"
var _translations: Dictionary = {}  # locale -> Dictionary(key -> text)
var _file_system: FileSystemService = null
var _log: LogService = null


func _on_init() -> OperationResult:
	return OperationResult.ok()


func configure(p_file_system: FileSystemService, p_log: LogService) -> OperationResult:
	if p_file_system == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "file_system 不能为 null", module_name)
	if p_log == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "log 不能为 null", module_name)
	_file_system = p_file_system
	_log = p_log
	return OperationResult.ok()


# ============================================================
# 语言切换
# ============================================================

## 切换当前语言，如 "zh"、"en"
func set_locale(p_locale: String) -> void:
	_current_locale = p_locale
	_log.info("Localization", "切换语言: %s" % p_locale)


func get_locale() -> String:
	return _current_locale


# ============================================================
# 翻译查询
# ============================================================

## 获取指定 key 的翻译文本。p_args 可选，用于参数替换。
## "{name}" 格式的占位符会被 p_args 中的值替换。
## key 不存在时返回 key 本身，并输出 warning。
func tr_key(p_key: String, p_args: Dictionary = {}) -> String:
	var table: Dictionary = _translations.get(_current_locale, {})
	if not table.has(p_key):
		_log.warning("Localization", "缺失翻译 key: %s (locale=%s)" % [p_key, _current_locale])
		return p_key

	var text: String = table[p_key]

	if not p_args.is_empty():
		for arg in p_args.keys():
			text = text.replace("{%s}" % arg, str(p_args[arg]))

	return text


## 检查 key 是否存在于当前语言
func has_key(p_key: String) -> bool:
	var table: Dictionary = _translations.get(_current_locale, {})
	return table.has(p_key)


# ============================================================
# 数据加载
# ============================================================

## 从 JSON 文件加载某语言的翻译表
func load_translation(p_locale: String, p_path: String) -> OperationResult:
	var result := _file_system.read_json(p_path)
	if result.is_fail():
		_log.error("Localization", "加载失败: %s → %s" % [p_locale, p_path])
		return result

	_translations[p_locale] = result.data as Dictionary
	_log.info("Localization", "已加载 %s (%d 条)" % [p_locale, (result.data as Dictionary).size()])
	return OperationResult.ok()
