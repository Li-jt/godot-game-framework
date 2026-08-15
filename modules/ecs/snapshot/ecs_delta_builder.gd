# modules/ecs/snapshot/ecs_delta_builder.gd
## GF_EcsDeltaBuilder — 从世界变更日志构建增量 delta（性能路线图 §3.1）。
## 只遍历本帧变更（O(变更量)），替代全量快照 diff（O(全量)）。
##
## 构建后变更日志的清空时机由调用方决定（框架不定义消费时序）：
## - 存档 delta 模式：build 后立即 world.change_log.clear()；
## - 多消费者模式：先各自消费，最后由最后一个消费者 clear。
class_name GF_EcsDeltaBuilder
extends RefCounted


## 从变更日志构建 delta。不修改世界、不清空日志。
func build(p_world: GF_EcsWorld) -> GF_EcsDelta:
	var delta := GF_EcsDelta.new()
	var registry: GF_EcsComponentTypeRegistry = p_world._get_registry()
	var log: GF_EcsChangeLog = p_world.change_log

	for entity in log.removed_entities:
		delta.removed_entities.append(entity)

	for change in log.component_changes:
		var type_name: String = registry.type_name_of(change.get("type_id", 0))
		if type_name.is_empty():
			continue
		if change.get("kind", -1) == GF_EcsChangeLog.ChangeKind.COMPONENT_REMOVED:
			delta.removed_components.append({
				"entity": change.get("entity", 0),
				"type_name": type_name,
			})
		else:
			# ADDED / CHANGED 都归入 upsert（覆盖语义）
			var entity: int = change.get("entity", 0)
			var entity_data: Dictionary = delta.upserts.get(entity, {})
			entity_data[type_name] = change.get("component")
			delta.upserts[entity] = entity_data

	return delta
