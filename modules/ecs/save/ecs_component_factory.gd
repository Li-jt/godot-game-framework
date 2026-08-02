## GF_EcsComponentFactory — ECS 组件工厂注册表。
## Game 层注册组件类的脚本引用，存档恢复时自动按类型重建组件实例。
## 未注册的组件类型降级为直接使用原始 Dictionary 数据（向后兼容）。
class_name GF_EcsComponentFactory
extends RefCounted

# StringName type_name → Callable (func(p_data: Dictionary) -> Variant)
var _factories: Dictionary = {}


## 手动注册组件工厂回调（灵活模式）。
## [param p_type_name] 组件类型名（如 &"Health"）
## [param p_factory] 工厂回调，签名为 func(p_data: Dictionary) -> Variant
func register(p_type_name: StringName, p_factory: Callable) -> void:
	_factories[p_type_name] = p_factory


## 从 GDScript 脚本引用自动注册组件工厂（推荐方式）。
## 脚本类必须继承 GF_EcsComponentBase 并覆写 get_component_type() 和 deserialize()。
## [param p_script] 通过 load() 获取的脚本引用
## [return] 是否注册成功
func register_script(p_script: GDScript) -> bool:
	var temp = p_script.new()
	if not temp is GF_EcsComponentBase:
		push_warning("GF_EcsComponentFactory: %s 未继承 GF_EcsComponentBase，跳过" % p_script.resource_path)
		return false
	var type_name: StringName = temp.get_component_type()
	if type_name == &"":
		push_warning("GF_EcsComponentFactory: %s 未覆写 get_component_type()，跳过" % p_script.resource_path)
		return false
	_factories[type_name] = func(data: Dictionary):
		var instance = p_script.new()
		instance.deserialize(data)
		return instance
	return true


## 批量注册：从脚本引用数组中自动发现并注册所有组件。
## 每个脚本必须继承 GF_EcsComponentBase 并覆写 get_component_type() 和 deserialize()。
## [return] 成功注册的数量
func discover_from(p_scripts: Array) -> int:
	var count := 0
	for script in p_scripts:
		if register_script(script):
			count += 1
	return count


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
