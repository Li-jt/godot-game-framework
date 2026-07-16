## DefIdRegistry — 游戏内容定义的 ID 注册表。
## 所有游戏 ID（Economy/Resource/Building/WorkJob 等）统一在此注册和查询。
## 支持 xlsx 导出的 JSON 批量加载 + Mod 运行时动态追加。
class_name DefIdRegistry
extends RefCounted

class CategoryInfo:
	var name: String = ""
	var id_start: int = 0
	var id_end: int = 0
	var id_counter: int = 0


var _categories: Dictionary = {}            ## {String: CategoryInfo}
var _id_to_key: Dictionary = {}             ## {int: StringName}
var _key_to_id: Dictionary = {}             ## {StringName: int}
var _category_keys: Dictionary = {}         ## {String: {StringName: int}}
var _id_owners: Dictionary = {}             ## {int: String}
var _display_names: Dictionary = {}         ## {int: String}


## 加载一个 *_ids.json 文件，批量注册所有 ID。
func load_ids_json(p_path: String, p_owner: String = "game") -> OperationResult:
	var file := FileAccess.open(p_path, FileAccess.READ)
	if file == null:
		return OperationResult.fail(OperationResult.ERR_FILE_NOT_FOUND, "DefIdRegistry", "文件不存在: %s" % p_path)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return OperationResult.fail(OperationResult.ERR_PARSE_ERROR, "DefIdRegistry", "JSON 解析失败: %s" % p_path)

	var data: Dictionary = json.data
	var category: String = data.get("category", "")
	var id_start: int = data.get("id_start", 0)
	var id_end: int = data.get("id_end", 0)
	register_category(category, id_start, id_end)

	for entry in data.get("entries", []):
		var id: int = entry["id"]
		var key: StringName = entry["key"]
		var display_name: String = entry.get("display_name", "")
		register_id(category, key, id, p_owner)
		if not display_name.is_empty():
			_display_names[id] = display_name

	return OperationResult.ok()


## 注册一个 category 段。
func register_category(p_name: String, p_id_start: int, p_id_end: int = 0) -> void:
	if _categories.has(p_name):
		return
	var info := CategoryInfo.new()
	info.name = p_name
	info.id_start = p_id_start
	info.id_end = p_id_end
	info.id_counter = p_id_start
	_categories[p_name] = info
	_category_keys[p_name] = {}


## 注册一个 ID。返回实际分配的 ID。
func register_id(p_category: String, p_key: StringName, p_preferred_id: int = 0, p_owner: String = "") -> int:
	_ensure_category(p_category)

	# 同 category + 同 key → 幂等
	if _category_keys[p_category].has(p_key):
		var existing_id: int = _category_keys[p_category][p_key]
		if p_preferred_id == 0 or p_preferred_id == existing_id:
			return existing_id
		push_error("[DefIdRegistry] key='%s' 已注册为 %d, 不能改为 %d" % [p_key, existing_id, p_preferred_id])
		return existing_id

	# 分配 ID
	var assigned_id: int
	if p_preferred_id > 0 and not _id_to_key.has(p_preferred_id):
		assigned_id = p_preferred_id
	elif p_preferred_id > 0:
		push_warning("[DefIdRegistry] ID %d 已被占用, '%s' 自动分配" % [p_preferred_id, p_owner])
		assigned_id = _allocate_next(p_category)
	else:
		assigned_id = _allocate_next(p_category)

	_id_to_key[assigned_id] = p_key
	_key_to_id[p_key] = assigned_id
	_category_keys[p_category][p_key] = assigned_id
	_id_owners[assigned_id] = p_owner
	return assigned_id


## 查询 API（高频调用，都是 O(1) 字典查找）
func get_id(p_category: String, p_key: StringName) -> int:
	return _category_keys.get(p_category, {}).get(p_key, 0)


func get_key(p_id: int) -> StringName:
	return _id_to_key.get(p_id, &"")


func get_display_name(p_id: int) -> String:
	return _display_names.get(p_id, "")


func owner_of(p_id: int) -> String:
	return _id_owners.get(p_id, "")


## 批量查询（返回副本，避免外部修改）
func to_id(p_category: String) -> Dictionary:
	return _category_keys.get(p_category, {}).duplicate()


func from_id(p_category: String) -> Dictionary:
	var result := {}
	for key in _category_keys.get(p_category, {}):
		result[_category_keys[p_category][key]] = key
	return result


## 注销指定 category 的所有 ID。
func unregister_category(p_category: String) -> void:
	var keys: Dictionary = _category_keys.get(p_category, {})
	for key in keys:
		var id: int = keys[key]
		_id_to_key.erase(id)
		_key_to_id.erase(key)
		_display_names.erase(id)
		_id_owners.erase(id)
	_category_keys.erase(p_category)
	_categories.erase(p_category)


## 注销指定 owner 的所有 ID。Mod 卸载时使用。
func unregister_by_owner(p_owner: String) -> int:
	var removed := 0
	var ids_to_remove: Array[int] = []
	for id in _id_owners:
		if _id_owners[id] == p_owner:
			ids_to_remove.append(id)
	for id in ids_to_remove:
		var key: StringName = _id_to_key.get(id, &"")
		_id_to_key.erase(id)
		_key_to_id.erase(key)
		_display_names.erase(id)
		_id_owners.erase(id)
		# 从 _category_keys 中也清理
		for cat_key in _category_keys:
			var cat_dict: Dictionary = _category_keys[cat_key]
			for k in cat_dict:
				if cat_dict[k] == id:
					cat_dict.erase(k)
					break
		removed += 1
	return removed


## 获取所有已注册 category 名称
func category_names() -> Array[String]:
	var names: Array[String] = []
	names.assign(_categories.keys())
	return names


## 内部
func _allocate_next(p_category: String) -> int:
	var info: CategoryInfo = _categories[p_category]
	while _id_to_key.has(info.id_counter):
		info.id_counter += 1
	var assigned := info.id_counter
	info.id_counter += 1
	return assigned


func _ensure_category(p_category: String) -> void:
	if not _categories.has(p_category):
		register_category(p_category, 500001, 599999)
