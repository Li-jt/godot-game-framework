## EcsWorldSnapshot — ECS 世界可序列化快照。
## 包含全部实体、组件数据、世界版本和组件类型注册信息，
## 供 Save / Rollback / Network 使用。
class_name EcsWorldSnapshot
extends RefCounted

## 世界版本号
var version: int = 0
## 快照创建时间戳
var timestamp: int = 0
## 组件类型注册表快照：{StringName -> {type_id, version}}
var component_registry: Dictionary = {}
## 实体数据列表：Array[{entity, components: {StringName -> data_dict}}]
var entities: Array = []


## 将快照序列化为可存储的 Dictionary。
func to_dict() -> Dictionary:
	return {
		"version": version,
		"timestamp": timestamp,
		"component_registry": component_registry.duplicate(true),
		"entities": entities.duplicate(true),
	}


## 从 Dictionary 反序列化快照。
func from_dict(p_data: Dictionary) -> void:
	version = p_data.get("version", 0)
	timestamp = p_data.get("timestamp", 0)
	component_registry = p_data.get("component_registry", {}).duplicate(true)
	entities = p_data.get("entities", []).duplicate(true)


## 快照中的实体数量。
func entity_count() -> int:
	return entities.size()
