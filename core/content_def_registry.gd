## ContentDefRegistry — 内容定义注册表（Framework 层）。
## 通用模块注册与查询机制，不含任何具体业务语义。
## 替代 GameDefService 单例，由 GameBootstrap 在启动时注册各内容模块。
##
## 使用方式：
##   1. GameBootstrap 中创建 ContentDefRegistry 实例
##   2. 调用 register_module("terrain", terrain_module) 注册模块
##   3. ECS 系统通过 module("terrain") 获取模块数据
##   4. 通过 ContentDefRegistry.instance() 静态桥接访问（过渡期，逐步迁移到 DI）
class_name ContentDefRegistry
extends RefCounted

## 全局单例引用（过渡期桥接，由 GameBootstrap 在启动时赋值）
static var instance: ContentDefRegistry = null

## 获取全局实例（过渡期桥接方法）
static func get_instance() -> ContentDefRegistry:
	return instance

## {StringName: Variant} 已注册的模块映射
var _modules: Dictionary = {}


## 注册一个内容模块。
## p_name: 模块名称（如 "terrain"、"season"、"resource"）
## p_module: 模块实例，通常是加载 JSON 数据后的数据持有对象
func register_module(p_name: StringName, p_module: Variant) -> void:
	if _modules.has(p_name):
		push_warning("[ContentDefRegistry] 模块 '%s' 被覆盖注册" % p_name)
	_modules[p_name] = p_module


## 获取已注册的模块。未注册时返回 null。
func module(p_name: StringName) -> Variant:
	return _modules.get(p_name, null)


## 检查模块是否已注册。
func has_module(p_name: StringName) -> bool:
	return _modules.has(p_name)


## 获取所有已注册的模块名称列表。
func module_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key in _modules.keys():
		names.append(key)
	return names


## 注销模块。Mod 卸载时使用。
func unregister_module(p_name: StringName) -> void:
	_modules.erase(p_name)


## 清空所有已注册的模块。
func clear() -> void:
	_modules.clear()
