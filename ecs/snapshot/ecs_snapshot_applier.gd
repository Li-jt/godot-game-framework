## GF_EcsSnapshotApplier — 将快照恢复到 GF_EcsWorld。
## 先清空当前世界，再按快照数据重建全部实体和组件。
class_name GF_EcsSnapshotApplier
extends RefCounted


## 将快照应用到指定世界（覆盖式恢复）。
## [param p_factory] 可选组件工厂，用于从序列化数据重建组件实例。
##   为 null 时降级为直接使用原始数据（向后兼容）。
func apply(p_world: GF_EcsWorld, p_snapshot: GF_EcsWorldSnapshot, p_factory: GF_EcsComponentFactory = null) -> GF_OperationResult:
	if p_world == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "世界不能为空", "GF_EcsSnapshotApplier")
	if p_snapshot == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "快照不能为空", "GF_EcsSnapshotApplier")

	p_world.reset()

	# 恢复组件类型注册
	var registry: GF_EcsComponentTypeRegistry = p_world._get_registry()
	var registry_data: Dictionary = p_snapshot.component_registry
	for type_name in registry_data.keys():
		var info: Dictionary = registry_data[type_name]
		registry.register_type(type_name, info.get("version", 1))

	# 恢复实体和组件
	for entity_data in p_snapshot.entities:
		var entity: int = entity_data.get("entity", 0)
		if not GF_EcsEntityId.is_valid(entity):
			continue
		# 强制设置 ID（绕过自动分配）
		p_world._force_spawn(entity)
		var components: Dictionary = entity_data.get("components", {})
		for type_name in components.keys():
			var comp_data = components[type_name]
			# 通过工厂重建组件实例（未注册则降级为原始数据）
			var component = _reconstruct(p_factory, type_name, comp_data)
			p_world.set_component(entity, type_name, component)

	return GF_OperationResult.ok({"restored_entities": p_snapshot.entity_count()})


## 从序列化数据重建组件实例。有工厂则用工厂，否则返回原始数据。
func _reconstruct(p_factory: GF_EcsComponentFactory, p_type_name: StringName, p_data) -> Variant:
	if p_factory != null and p_factory.has_factory(p_type_name):
		return p_factory.create(p_type_name, p_data)
	return p_data


## 将快照作为增量应用到世界（仅更新/新增，不删除未在快照中的实体）。
func apply_delta(p_world: GF_EcsWorld, p_snapshot: GF_EcsWorldSnapshot) -> GF_OperationResult:
	if p_world == null or p_snapshot == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "参数不能为空", "GF_EcsSnapshotApplier")

	for entity_data in p_snapshot.entities:
		var entity: int = entity_data.get("entity", 0)
		if not p_world.has_entity(entity):
			p_world._force_spawn(entity)
		var components: Dictionary = entity_data.get("components", {})
		for type_name in components.keys():
			var comp_data = components[type_name]
			p_world.set_component(entity, type_name, comp_data)

	return GF_OperationResult.ok({"updated_entities": p_snapshot.entity_count()})
