## EcsComponentTypeRegistry — 组件类型注册中心。
## 管理 StringName -> type_id 的映射，并记录每种类型的版本号、注册者，
## 为 Save/Debug/Inspector 提供结构化信息，支持 Mod 冲突检测和卸载。
class_name EcsComponentTypeRegistry
extends RefCounted

var _type_to_id: Dictionary = {}
var _id_to_type: Dictionary = {}
var _versions: Dictionary = {}         ## {int: int} type_id → version
var _owners: Dictionary = {}           ## {int: String} type_id → owner_name
var _next_id: int = 1


## 注册组件类型。重复注册同一类型会返回已有 type_id 而不报错。
func register_type(p_type: StringName, p_version: int = 1) -> OperationResult:
	return pre_register(p_type, p_version, "")


## 显式预注册一个组件类型。
## p_owner: 注册者标识（如 "game" 或 "mod:fishing"），用于冲突检测和卸载。
## 如果 type 已注册：
##   - 同 owner → 幂等返回
##   - 不同 owner → 报错并返回已有 ID（冲突检测）
func pre_register(p_type: StringName, p_version: int = 1, p_owner: String = "") -> OperationResult:
	if _type_to_id.has(p_type):
		var tid: int = _type_to_id[p_type]
		var existing_owner: String = _owners.get(tid, "")
		if not existing_owner.is_empty() and existing_owner != p_owner and not p_owner.is_empty():
			push_error("[EcsComponentTypeRegistry] 组件类型冲突: '%s' 已被 '%s' 注册, '%s' 尝试重复注册" % [p_type, existing_owner, p_owner])
		return OperationResult.ok(tid)

	var tid: int = _next_id
	_next_id += 1
	_type_to_id[p_type] = tid
	_id_to_type[tid] = p_type
	_versions[tid] = p_version
	_owners[tid] = p_owner
	return OperationResult.created(tid)


## 根据类型名获取 type_id，未注册时返回 0。
func type_id_of(p_type: StringName) -> int:
	return _type_to_id.get(p_type, 0)


## 根据 type_id 获取类型名，未注册时返回空 StringName。
func type_name_of(p_id: int) -> StringName:
	return _id_to_type.get(p_id, &"")


## 获取指定类型的版本号。
func type_version(p_id: int) -> int:
	return _versions.get(p_id, 0)


## 获取组件的注册者。
func type_owner(p_type_or_id: Variant) -> String:
	var tid: int
	if p_type_or_id is StringName:
		tid = _type_to_id.get(p_type_or_id, 0)
	else:
		tid = p_type_or_id as int
	return _owners.get(tid, "")


## 检查组件类型是否已注册。
func is_registered(p_type: StringName) -> bool:
	return _type_to_id.has(p_type)


## 返回所有已注册类型名的数组。
func all_types() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _type_to_id.keys():
		result.append(key)
	return result


## 返回当前注册类型数量。
func count() -> int:
	return _type_to_id.size()


## 注销指定 owner 的所有组件类型。Mod 卸载时使用。
func unregister_by_owner(p_owner: String) -> Array[StringName]:
	var removed: Array[StringName] = []
	var types_to_remove: Array[StringName] = []
	for type_name in _type_to_id:
		var tid: int = _type_to_id[type_name]
		if _owners.get(tid, "") == p_owner:
			types_to_remove.append(type_name)
	for type_name in types_to_remove:
		var tid: int = _type_to_id[type_name]
		_type_to_id.erase(type_name)
		_id_to_type.erase(tid)
		_versions.erase(tid)
		_owners.erase(tid)
		removed.append(type_name)
	return removed
