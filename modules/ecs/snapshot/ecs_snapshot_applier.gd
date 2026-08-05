## GF_EcsSnapshotApplier — 将快照恢复到 GF_EcsWorld。
## 先清空当前世界，再按快照数据重建全部实体和组件。
class_name GF_EcsSnapshotApplier
extends RefCounted


## 将快照应用到指定世界（覆盖式恢复）。
## [param p_factory] 可选组件工厂，用于从序列化数据重建组件实例。
##   为 null 时降级为直接使用原始数据（向后兼容）。
func apply(p_world: GF_EcsWorld, p_snapshot: GF_EcsWorldSnapshot, p_factory: Variant = null) -> GF_OperationResult:
	if p_world == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "世界不能为空", "GF_EcsSnapshotApplier")
	if p_snapshot == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "快照不能为空", "GF_EcsSnapshotApplier")

	p_world.reset()

	var registry: GF_EcsComponentTypeRegistry = p_world._get_registry()
	var registry_data: Dictionary = p_snapshot.component_registry

	# 恢复组件类型注册（JSON String key → GDScript 引用）
	for type_name in registry_data.keys():
		var p_type := registry.type_by_name(type_name)
		if p_type != null:
			var info: Dictionary = registry_data[type_name]
			registry.register_type(p_type, info.get("version", 1))

	# 恢复实体和组件
	for entity_data in p_snapshot.entities:
		var entity: int = entity_data.get("entity", 0)
		if not GF_EcsEntityId.is_valid(entity):
			continue
		p_world._force_spawn(entity)
		var components: Dictionary = entity_data.get("components", {})
		for type_name in components.keys():
			var comp_data = components[type_name]
			var component = _reconstruct(p_factory, type_name, comp_data)
			var p_type := registry.type_by_name(type_name)
			if p_type != null:
				p_world.set_component(entity, p_type, component)

	return GF_OperationResult.ok({"restored_entities": p_snapshot.entity_count()})


## 从序列化数据重建组件实例。有工厂则用工厂，否则返回原始数据。
func _reconstruct(p_factory, p_type_name: String, p_data) -> Variant:
	if p_factory != null and p_factory.has_factory(p_type_name):
		return p_factory.create(p_type_name, p_data)
	return p_data


## 将快照作为增量应用到世界（仅更新/新增，不删除未在快照中的实体）。
func apply_delta(p_world: GF_EcsWorld, p_snapshot: GF_EcsWorldSnapshot) -> GF_OperationResult:
	if p_world == null or p_snapshot == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "参数不能为空", "GF_EcsSnapshotApplier")

	var registry: GF_EcsComponentTypeRegistry = p_world._get_registry()

	for entity_data in p_snapshot.entities:
		var entity: int = entity_data.get("entity", 0)
		if not p_world.has_entity(entity):
			p_world._force_spawn(entity)
		var components: Dictionary = entity_data.get("components", {})
		for type_name in components.keys():
			var comp_data = components[type_name]
			var p_type := registry.type_by_name(type_name)
			if p_type != null:
				p_world.set_component(entity, p_type, comp_data)

	return GF_OperationResult.ok({"updated_entities": p_snapshot.entity_count()})
