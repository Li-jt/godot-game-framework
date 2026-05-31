## EcsSnapshotApplier — 将快照恢复到 EcsWorld。
## 先清空当前世界，再按快照数据重建全部实体和组件。
class_name EcsSnapshotApplier
extends RefCounted


## 将快照应用到指定世界（覆盖式恢复）。
func apply(p_world: EcsWorld, p_snapshot: EcsWorldSnapshot) -> OperationResult:
	if p_world == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "世界不能为空", "EcsSnapshotApplier")
	if p_snapshot == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "快照不能为空", "EcsSnapshotApplier")

	p_world.reset()

	# 恢复组件类型注册
	var registry: EcsComponentTypeRegistry = p_world._get_registry()
	var registry_data: Dictionary = p_snapshot.component_registry
	for type_name in registry_data.keys():
		var info: Dictionary = registry_data[type_name]
		registry.register_type(type_name, info.get("version", 1))

	# 恢复实体和组件
	for entity_data in p_snapshot.entities:
		var entity: int = entity_data.get("entity", 0)
		if not EcsEntityId.is_valid(entity):
			continue
		# 强制设置 ID（绕过自动分配）
		p_world._force_spawn(entity)
		var components: Dictionary = entity_data.get("components", {})
		for type_name in components.keys():
			var comp_data = components[type_name]
			p_world.set_component(entity, type_name, comp_data)

	return OperationResult.ok({"restored_entities": p_snapshot.entity_count()})


## 将快照作为增量应用到世界（仅更新/新增，不删除未在快照中的实体）。
func apply_delta(p_world: EcsWorld, p_snapshot: EcsWorldSnapshot) -> OperationResult:
	if p_world == null or p_snapshot == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "参数不能为空", "EcsSnapshotApplier")

	for entity_data in p_snapshot.entities:
		var entity: int = entity_data.get("entity", 0)
		if not p_world.has_entity(entity):
			p_world._force_spawn(entity)
		var components: Dictionary = entity_data.get("components", {})
		for type_name in components.keys():
			var comp_data = components[type_name]
			p_world.set_component(entity, type_name, comp_data)

	return OperationResult.ok({"updated_entities": p_snapshot.entity_count()})
