## EcsSnapshotBuilder — 从 EcsWorld 构建可序列化快照。
## 遍历全部实体和组件，调用 EcsComponentBase.serialize() 序列化组件数据。
class_name EcsSnapshotBuilder
extends RefCounted


## 从指定世界构建快照。
func build(p_world: EcsWorld) -> EcsWorldSnapshot:
	var snapshot: EcsWorldSnapshot = EcsWorldSnapshot.new()
	snapshot.version = p_world.get_version()
	snapshot.timestamp = Time.get_unix_time_from_system()

	# 组件类型注册表快照
	var registry: EcsComponentTypeRegistry = p_world._get_registry()
	for type_name in registry.all_types():
		var tid: int = registry.type_id_of(type_name)
		snapshot.component_registry[type_name] = {
			"type_id": tid,
			"version": registry.type_version(tid),
		}

	# 实体组件数据
	var storage_index: EcsStorageIndex = p_world._get_storage_index()
	for entity in p_world.all_entities():
		var entity_data: Dictionary = {"entity": entity, "components": {}}
		for type_id in storage_index.all_type_ids():
			var storage: IEcsStorage = storage_index.get_storage(type_id)
			if storage == null or not storage.contains(entity):
				continue
			var type_name: StringName = registry.type_name_of(type_id)
			var component: Variant = storage.get_data(entity)
			if component != null and component.has_method("serialize"):
				entity_data["components"][type_name] = component.serialize()
			else:
				entity_data["components"][type_name] = _fallback_serialize(component)
		snapshot.entities.append(entity_data)

	return snapshot


## 非 EcsComponentBase 类型的降级序列化。
func _fallback_serialize(p_component) -> Variant:
	if p_component == null:
		return null
	if p_component is Dictionary:
		return p_component.duplicate(true)
	if p_component is Array:
		return p_component.duplicate(true)
	return str(p_component)
