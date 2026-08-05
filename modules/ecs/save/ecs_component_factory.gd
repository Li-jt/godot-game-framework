## GF_EcsComponentFactory — ECS 组件工厂注册表。
## Game 层注册组件类的脚本引用，存档恢复时自动按类型重建组件实例。
## 未注册的组件类型降级为直接使用原始 Dictionary 数据（向后兼容）。
class_name GF_EcsComponentFactory
extends RefCounted

# Variant key → Callable (func(p_data: Dictionary) -> Variant)
# key 可以是 GDScript 类引用（如 Position）或 String 类型名（如 "Position"）
var _factories: Dictionary = {}


## 手动注册组件工厂回调（灵活模式）。
## [param p_key] 组件类型标识：GDScript 类引用或 String 类型名
## [param p_factory] 工厂回调，签名为 func(p_data: Dictionary) -> Variant
func register(p_key: Variant, p_factory: Callable) -> void:
	_factories[p_key] = p_factory


## 从 GDScript 脚本引用自动注册组件工厂（推荐方式）。
## [param p_script] 通过 load() 获取的脚本引用
## [return] 是否注册成功
func register_script(p_script: GDScript) -> bool:
	var temp = p_script.new()
	if not temp is GF_EcsComponentBase:
		push_warning("GF_EcsComponentFactory: %s 未继承 GF_EcsComponentBase，跳过" % p_script.resource_path)
		return false
	var type_name: String = p_script.get_global_name()
	if type_name.is_empty():
		push_warning("GF_EcsComponentFactory: %s 缺少 class_name 声明，跳过" % p_script.resource_path)
		return false
	_factories[p_script] = func(data: Dictionary):
		var instance = p_script.new()
		instance.deserialize(data)
		return instance
	_factories[type_name] = _factories[p_script]  # 同时注册 String 键，供反序列化查找
	return true


## 批量注册：从脚本引用数组中自动发现并注册所有组件。
## [return] 成功注册的数量
func discover_from(p_scripts: Array) -> int:
	var count := 0
	for script in p_scripts:
		if register_script(script):
			count += 1
	return count


## 注销指定类型的工厂回调。
func unregister(p_key: Variant) -> void:
	_factories.erase(p_key)


## 从序列化数据创建组件实例。
## 如果有注册的工厂回调则调用它；否则返回原始数据（向后兼容）。
func create(p_key: Variant, p_data: Dictionary):
	if _factories.has(p_key):
		return _factories[p_key].call(p_data)
	return p_data


## 检查是否注册了指定类型的工厂。
func has_factory(p_key: Variant) -> bool:
	return _factories.has(p_key)


## 返回所有已注册的组件类型标识。
func registered_types() -> Array:
	var result: Array = []
	for key in _factories.keys():
		result.append(key)
	return result


## 清空全部工厂注册。
func clear() -> void:
	_factories.clear()
