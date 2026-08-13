## GF_LocalizationService
## 本地化服务。管理多语言文本加载、查询和 UI 绑定。
##
## 数据由调用方提供（不限制格式），框架只负责存储、查询、通知。
## 支持 bind() 声明式绑定：切换语言时自动更新对应 UI 属性。
##
## 使用方式：
##   [codeblock]
##   service.add_translations("zh_CN", {"menu.start": "开始", "menu.exit": "退出"})
##   service.add_translations("en",    {"menu.start": "Start", "menu.exit": "Exit"})
##
##   # 声明式绑定 —— 切换语言时 label.text 自动更新
##   service.bind(label, "text", "menu.start")
##   service.bind(label2, "text", "menu.exit", {"name": "JT"})
##
##   # 直接查询
##   var text := service.text("menu.start", {"name": "JT"})
##
##   # 切换语言 → 所有 bind 的节点自动刷新
##   service.set_locale("en")
##   [/codeblock]
class_name GF_LocalizationService
extends GF_ModuleLifecycle

## 语言切换时发射，传入新 locale 标识。自定义监听者连接此信号执行刷新逻辑。
signal locale_changed(p_locale: String)

var _current_locale: String = ""  # 空表示未设置，首次 set_locale() 后赋值
var _translations: Dictionary = {}  # {String locale: {String key: String text}}
var _bindings: Array[Dictionary] = []  # [{node: WeakRef, property: String, key: String, args: Dictionary}]
var _log: GF_LogService = null


func _on_init() -> GF_OperationResult:
	return GF_OperationResult.ok()


func dependencies() -> Array:
	return [GF_LogService, GF_FileSystemService]

func configure() -> GF_OperationResult:
	_log = _bootstrap.service(GF_LogService) as GF_LogService
	return GF_OperationResult.ok()


# ============================================================
# 数据注入
# ============================================================

## 注入某语言的翻译表。调用方自己决定数据来源（JSON/CSV/硬编码），框架只管存储。
## p_dict 格式：{key: text}，如 {"menu.start": "开始"}
func add_translations(p_locale: String, p_dict: Dictionary) -> void:
	if not _translations.has(p_locale):
		_translations[p_locale] = {}
	var table: Dictionary = _translations[p_locale]
	for key in p_dict:
		table[str(key)] = str(p_dict[key])
	_log.info("Localization", "已添加 %s (%d 条)" % [p_locale, p_dict.size()])


## 从 JSON 文件加载翻译表（便捷方法，内部转为 add_translations）。
func load_translation(p_locale: String, p_path: String) -> GF_OperationResult:
	var fs: GF_FileSystemService = _bootstrap.service(GF_FileSystemService) as GF_FileSystemService
	if fs == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_PRECONDITION, "GF_FileSystemService 未注册", module_name)
	var result := fs.read_json(p_path)
	if result.is_fail():
		_log.error("Localization", "加载失败: %s → %s" % [p_locale, p_path])
		return result
	add_translations(p_locale, result.data as Dictionary)
	return GF_OperationResult.ok()


# ============================================================
# 语言切换
# ============================================================

## 切换当前语言。自动刷新所有 bind() 的 UI 节点，发射 locale_changed 信号。
func set_locale(p_locale: String) -> void:
	_current_locale = p_locale
	_apply_all_bindings()
	locale_changed.emit(p_locale)
	_log.info("Localization", "切换语言: %s" % p_locale)


func get_locale() -> String:
	return _current_locale


# ============================================================
# 翻译查询
# ============================================================

## 获取当前语言下 key 对应的翻译文本。p_args 可选，替换 "{arg}" 占位符。
## key 不存在时返回 key 本身并输出 warning。
func text(p_key: String, p_args: Dictionary = {}) -> String:
	var table: Dictionary = _translations.get(_current_locale, {})
	if not table.has(p_key):
		_log.warning("Localization", "缺失翻译 key: %s (locale=%s)" % [p_key, _current_locale])
		return p_key

	var text: String = table[p_key]

	if not p_args.is_empty():
		for arg in p_args.keys():
			text = text.replace("{%s}" % arg, str(p_args[arg]))

	return text


## 按整数 ID 查询翻译。等价于 text(str(p_id), p_args)。
func text_id(p_id: int, p_args: Dictionary = {}) -> String:
	return text(str(p_id), p_args)


## 向后兼容别名。
func tr_key(p_key: String, p_args: Dictionary = {}) -> String:
	return text(p_key, p_args)


## 检查 key 是否存在于当前语言。
func has_key(p_key: String) -> bool:
	var table: Dictionary = _translations.get(_current_locale, {})
	return table.has(p_key)


## 检查整数 ID 是否存在于当前语言。
func has_id(p_id: int) -> bool:
	return has_key(str(p_id))


# ============================================================
# UI 绑定
# ============================================================

## 绑定节点属性到翻译 key。切换语言时自动调用 node.set(property, text)。
## p_key 接受 String 或 int（name_text_id 模式）。
## [param p_node] 目标节点
## [param p_property] 属性名（如 "text"、"tooltip_text"、"placeholder_text"）
## [param p_key] 翻译 key（String 如 "menu.start"，或 int 如 10）
## [param p_args] 可选的参数替换字典
func bind(p_node: Node, p_property: String, p_key: Variant, p_args: Dictionary = {}) -> void:
	_bindings.append({
		"node": weakref(p_node),
		"property": p_property,
		"key": p_key,
		"args": p_args,
	})
	# 立即应用当前语言的翻译
	_apply_binding(_bindings[-1])


## 解除绑定。p_property 为空时解除该节点所有绑定。
func unbind(p_node: Node, p_property: String = "") -> void:
	var alive: Array[Dictionary] = []
	for b in _bindings:
		var node = b["node"].get_ref()
		if node == p_node:
			if p_property.is_empty() or b["property"] == p_property:
				continue
		alive.append(b)
	_bindings = alive


# ============================================================
# 内部
# ============================================================

func _apply_all_bindings() -> void:
	_clean_dead_bindings()
	for b in _bindings:
		_apply_binding(b)


func _apply_binding(p_binding: Dictionary) -> void:
	var node = p_binding["node"].get_ref()
	if node == null or not is_instance_valid(node):
		return
	var key := str(p_binding["key"]) if p_binding["key"] is int else p_binding["key"] as String
	var value := text(key, p_binding["args"])
	node.set(p_binding["property"], value)


## 清理已释放节点的绑定（WeakRef 为 null）
func _clean_dead_bindings() -> void:
	var alive: Array[Dictionary] = []
	for b in _bindings:
		var node = b["node"].get_ref()
		if node != null and is_instance_valid(node):
			alive.append(b)
	_bindings = alive
