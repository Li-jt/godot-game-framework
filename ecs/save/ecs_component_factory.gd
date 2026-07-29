## GF_EcsComponentFactory — ECS 组件工厂注册表。
## Game 层注册组件类型的构造回调，存档恢复时自动按类型重建组件实例。
## 不注册的组件类型降级为直接使用原始 Dictionary 数据（向后兼容）。
class_name GF_EcsComponentFactory
extends RefCounted

# StringName type_name → Callable (func(p_data: Dictionary) -> Variant)
var _factories: Dictionary = {}


## 注册组件工厂回调。
## [param p_type_name] 组件类型名（如 &"Health"、&"Position"）
## [param p_factory] 工厂回调，签名为 func(p_data: Dictionary) -> Variant
func register(p_type_name: StringName, p_factory: Callable) -> void:
	_factories[p_type_name] = p_factory


## 注销指定类型的工厂回调。
func unregister(p_type_name: StringName) -> void:
	_factories.erase(p_type_name)


## 从序列化数据创建组件实例。
## 如果有注册的工厂回调则调用它；否则返回原始数据（向后兼容）。
func create(p_type_name: StringName, p_data: Dictionary):
	if _factories.has(p_type_name):
		return _factories[p_type_name].call(p_data)
	return p_data


## 检查是否注册了指定类型的工厂。
func has_factory(p_type_name: StringName) -> bool:
	return _factories.has(p_type_name)


## 返回所有已注册的组件类型名。
func registered_types() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _factories.keys():
		result.append(key)
	return result


## 清空全部工厂注册。
func clear() -> void:
	_factories.clear()
