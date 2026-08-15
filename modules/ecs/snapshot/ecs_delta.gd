# modules/ecs/snapshot/ecs_delta.gd
## GF_EcsDelta — ECS 增量变更集。
## 由 GF_EcsDeltaBuilder 从变更日志构建，供 GF_EcsSnapshotApplier.apply_delta()
## 应用。语义：
## - upserts：组件级新增/覆盖（entity → {type_name: component}）
## - removed_components：组件移除（[{entity, type_name}]）
## - removed_entities：实体销毁
## 应用顺序约定（applier 保证）：先移除、后 upsert——同一实体同帧
## remove→set 序列按序还原，despawn 后 upsert 可复活实体。
class_name GF_EcsDelta
extends RefCounted

## {entity: {type_name: component_data}}
var upserts: Dictionary = {}
## 待销毁实体 ID
var removed_entities: PackedInt64Array = PackedInt64Array()
## 待移除组件: [{entity, type_name}]
var removed_components: Array[Dictionary] = []


## 是否有任何变更。
func is_empty() -> bool:
	return upserts.is_empty() and removed_entities.is_empty() and removed_components.is_empty()


## 序列化（存档 DELTA 模式用）。entity key 经 JSON 后会转为字符串，
## from_dict 时转回 int。
func to_dict() -> Dictionary:
	return {
		"upserts": upserts,
		"removed_entities": Array(removed_entities),
		"removed_components": removed_components,
	}


## 从序列化数据恢复。
func from_dict(p_data: Dictionary) -> void:
	upserts = {}
	for key in p_data.get("upserts", {}).keys():
		upserts[int(key)] = p_data["upserts"][key]
	removed_entities = PackedInt64Array()
	for entity in p_data.get("removed_entities", []):
		removed_entities.append(int(entity))
	removed_components = []
	for rc in p_data.get("removed_components", []):
		removed_components.append({
			"entity": int(rc.get("entity", 0)),
			"type_name": rc.get("type_name", ""),
		})
