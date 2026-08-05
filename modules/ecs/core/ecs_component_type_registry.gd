## GF_EcsComponentTypeRegistry — 组件类型注册中心。
## 管理 GDScript（class_name 引用如 Position）-> type_id 的映射，
## 并记录每种类型的版本号、注册者，为 Save/Debug/Inspector 提供结构化信息。
class_name GF_EcsComponentTypeRegistry
extends RefCounted

var _type_to_id: Dictionary = {}   # {GDScript: int}
var _id_to_type: Dictionary = {}   # {int: GDScript}
var _name_to_type: Dictionary = {} # {String: GDScript} — 反序列化用，"Position" → Position
var _versions: Dictionary = {}     # {int: int} type_id → version
var _owners: Dictionary = {}       # {int: String} type_id → owner_name
var _next_id: int = 1


## 注册组件类型。p_type 为 class_name 引用（如 Position）。
func register_type(p_type: GDScript, p_version: int = 1) -> GF_OperationResult:
	return pre_register(p_type, p_version, "")


## 显式预注册一个组件类型。
## p_owner: 注册者标识（如 "game" 或 "mod:fishing"），用于冲突检测和卸载。
func pre_register(p_type: GDScript, p_version: int = 1, p_owner: String = "") -> GF_OperationResult:
	if _type_to_id.has(p_type):
		var tid: int = _type_to_id[p_type]
		var existing_owner: String = _owners.get(tid, "")
		if not existing_owner.is_empty() and existing_owner != p_owner and not p_owner.is_empty():
			push_error("[GF_EcsComponentTypeRegistry] 组件类型冲突: '%s' 已被 '%s' 注册, '%s' 尝试重复注册" % [_type_name(p_type), existing_owner, p_owner])
		return GF_OperationResult.ok(tid)

	var tid: int = _next_id
	_next_id += 1
	_type_to_id[p_type] = tid
	_id_to_type[tid] = p_type
	_versions[tid] = p_version
	_owners[tid] = p_owner
	if p_type is GDScript:
		_name_to_type[p_type.get_global_name()] = p_type
	return GF_OperationResult.created(tid)


## 根据类型获取 type_id，未注册时返回 0。
func type_id_of(p_type: GDScript) -> int:
	return _type_to_id.get(p_type, 0)


## 根据 type_id 获取类型引用。
func type_of(p_id: int) -> GDScript:
	return _id_to_type.get(p_id, null)


## 根据 type_id 获取可读的类型名（如 "Position"），供序列化使用。
func type_name_of(p_id: int) -> String:
	var t: Variant = _id_to_type.get(p_id, null)
	return _type_name(t)


## 根据可读类型名（如 "Position"）获取类型引用，供反序列化使用。
func type_by_name(p_name: String) -> GDScript:
	return _name_to_type.get(p_name, null)


## 获取指定类型的版本号。
func type_version(p_id: int) -> int:
	return _versions.get(p_id, 0)


## 获取组件的注册者。
func type_owner(p_type_or_id: Variant) -> String:
	var tid: int
	if p_type_or_id is int:
		tid = p_type_or_id
	elif _type_to_id.has(p_type_or_id):
		tid = _type_to_id[p_type_or_id]
	else:
		return ""
	return _owners.get(tid, "")


## 检查组件类型是否已注册。
func is_registered(p_type: GDScript) -> bool:
	return _type_to_id.has(p_type)


## 返回所有已注册类型引用的数组。
func all_types() -> Array:
	var result: Array = []
	for key in _type_to_id.keys():
		result.append(key)
	return result


## 返回当前注册类型数量。
func count() -> int:
	return _type_to_id.size()


## 注销指定 owner 的所有组件类型。Mod 卸载时使用。
func unregister_by_owner(p_owner: String) -> Array:
	var removed: Array = []
	var types_to_remove: Array = []
	for p_type in _type_to_id:
		var tid: int = _type_to_id[p_type]
		if _owners.get(tid, "") == p_owner:
			types_to_remove.append(p_type)
	for p_type in types_to_remove:
		var tid: int = _type_to_id[p_type]
		_type_to_id.erase(p_type)
		_id_to_type.erase(tid)
		_versions.erase(tid)
		_owners.erase(tid)
		removed.append(p_type)
	return removed


func _type_name(p_type: Variant) -> String:
	if p_type == null:
		return ""
	if p_type is GDScript:
		return p_type.get_global_name()
	return str(p_type)
