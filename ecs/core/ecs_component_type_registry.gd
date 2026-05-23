## EcsComponentTypeRegistry — 组件类型注册中心。
## 管理 StringName -> type_id 的映射，并记录每种类型的版本号，
## 为 Save/Debug/Inspector 提供结构化信息。
class_name EcsComponentTypeRegistry
extends RefCounted

var _type_to_id: Dictionary = {}
var _id_to_type: Dictionary = {}
var _versions: Dictionary = {}
var _next_id: int = 1


## 注册组件类型。重复注册同一类型会返回已有 type_id 而不报错。
func register_type(p_type: StringName, p_version: int = 1) -> OperationResult:
	if _type_to_id.has(p_type):
		return OperationResult.ok(_type_to_id[p_type])
	var tid := _next_id
	_next_id += 1
	_type_to_id[p_type] = tid
	_id_to_type[tid] = p_type
	_versions[tid] = p_version
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


## 返回所有已注册类型名的数组。
func all_types() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _type_to_id.keys():
		result.append(key)
	return result


## 返回当前注册类型数量。
func count() -> int:
	return _type_to_id.size()
