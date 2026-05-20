## EntityRegistry — 实体类型注册表（Framework 层）。
## 支持多态序列化：存档中每条实体数据带 "type" 字段，
## 读档时根据 type 查表创建正确的具体类型。
##
## 使用方式：
##   [codeblock]
##   # 注册
##   EntityRegistry.register("unit", func(d): return Unit.from_dict(d))
##   EntityRegistry.register("building", func(d): return Building.from_dict(d))
##
##   # 创建
##   var entity = EntityRegistry.create("unit", {"id": 1, "hunger": 80})
##   [/codeblock]
class_name EntityRegistry
extends RefCounted

static var _factories: Dictionary = {}  # String type → Callable


## 注册实体类型。p_type 对应存档中的 "type" 字段值。
## p_factory 接收 Dictionary 返回对应类型实例。
static func register(p_type: String, p_factory: Callable) -> void:
	_factories[p_type] = p_factory


## 从存档数据创建实体实例
static func create(p_type: String, p_data: Dictionary):
	var factory: Callable = _factories.get(p_type, null)
	if factory == null:
		push_warning("EntityRegistry: 未注册的类型 '%s'" % p_type)
		return null
	return factory.call(p_data)


## 类型是否已注册
static func has(p_type: String) -> bool:
	return _factories.has(p_type)
