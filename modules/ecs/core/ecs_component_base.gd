## GF_EcsComponentBase — 组件序列化基类。
## 所有 Game 层组件继承此类，统一 serialize/deserialize 契约，
## 为 Save/Snapshot 和 GF_EcsComponentFactory 自动发现提供结构化入口。
class_name GF_EcsComponentBase
extends RefCounted

## 组件 schema 版本号，数据变更时递增
var schema_version: int = 1


## 从 Dictionary 创建组件实例。子类应覆写以支持工厂自动注册。
## 默认实现：new() + deserialize()，子类可覆写为自定义构造逻辑。
static func from_dict(p_data: Dictionary) -> GF_EcsComponentBase:
	var instance: GF_EcsComponentBase = GF_EcsComponentBase.new()
	instance.deserialize(p_data)
	return instance


## 将组件数据序列化为 Dictionary。子类必须覆写。
func serialize() -> Dictionary:
	push_error("GF_EcsComponentBase.serialize: 子类必须覆写")
	return {}


## 从 Dictionary 反序列化填充组件。子类必须覆写。
func deserialize(p_data: Dictionary) -> void:
	push_error("GF_EcsComponentBase.deserialize: 子类必须覆写")
