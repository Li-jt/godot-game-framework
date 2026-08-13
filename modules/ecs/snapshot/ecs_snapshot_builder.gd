## GF_EcsSnapshotBuilder — 从 GF_EcsWorld 构建可序列化快照。
## 遍历全部实体和组件，调用 GF_EcsComponentBase.serialize() 序列化组件数据。
class_name GF_EcsSnapshotBuilder
extends RefCounted


## 从指定世界构建快照。
func build(p_world: GF_EcsWorld) -> GF_EcsWorldSnapshot:
	var snapshot: GF_EcsWorldSnapshot = GF_EcsWorldSnapshot.new()
	snapshot.version = p_world.get_version()
	snapshot.timestamp = Time.get_unix_time_from_system()

	# 组件类型注册表快照
	var registry: GF_EcsComponentTypeRegistry = p_world._get_registry()
	for p_type in registry.all_types():
		var tid: int = registry.type_id_of(p_type)
		var type_name: String = registry.type_name_of(tid)
		snapshot.component_registry[type_name] = {
			"type_id": tid,
			"version": registry.type_version(tid),
		}

	# 实体组件数据
	var storage_index: GF_EcsStorageIndex = p_world._get_storage_index()
	for entity in p_world.all_entities():
		var entity_data: Dictionary = {"entity": entity, "components": {}}
		for type_id in storage_index.all_type_ids():
			var storage: GF_IEcsStorage = storage_index.get_storage(type_id)
			if storage == null or not storage.contains(entity):
				continue
			var type_name: String = registry.type_name_of(type_id)
			var component: Variant = storage.get_data(entity)
			entity_data["components"][type_name] = _serialize_component(component)
		snapshot.entities.append(entity_data)

	return snapshot


## 序列化单个组件。支持 Object（有 serialize 方法）和 Dictionary/Array 等基础类型。
func _serialize_component(p_component) -> Variant:
	if p_component == null:
		return null
	if p_component is Object and p_component.has_method("serialize"):
		return p_component.serialize()
	return _fallback_serialize(p_component)


## 非 GF_EcsComponentBase 类型的降级序列化。
func _fallback_serialize(p_component) -> Variant:
	if p_component == null:
		return null
	if p_component is Dictionary:
		return p_component.duplicate(true)
	if p_component is Array:
		return p_component.duplicate(true)
	return str(p_component)


## 检查组件是否支持 serialize() 方法。
func _can_serialize(p_component) -> bool:
	return p_component != null and p_component is Object and p_component.has_method("serialize")
