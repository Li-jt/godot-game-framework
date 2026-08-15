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


## 将增量 delta 应用到世界（upsert + 删除语义）。
## 应用顺序：组件移除 → 实体销毁 → upsert——同实体同帧 remove→set 序列
## 按序还原，despawn 后 upsert 可复活实体。
## [param p_factory] 可选组件工厂，upsert 数据经工厂重建组件实例（同 apply）。
func apply_delta(p_world: GF_EcsWorld, p_delta: GF_EcsDelta, p_factory: Variant = null) -> GF_OperationResult:
	if p_world == null or p_delta == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "参数不能为空", "GF_EcsSnapshotApplier")

	var registry: GF_EcsComponentTypeRegistry = p_world._get_registry()
	var restored := 0

	# 1. 组件移除
	for rc in p_delta.removed_components:
		var p_type := registry.type_by_name(rc.get("type_name", ""))
		if p_type != null and p_world.has_entity(rc.get("entity", 0)):
			p_world.remove_component(rc.get("entity", 0), p_type)

	# 2. 实体销毁
	for entity in p_delta.removed_entities:
		if p_world.despawn(entity):
			restored += 1

	# 3. upsert（新增/覆盖）
	for entity in p_delta.upserts.keys():
		var e: int = entity
		if not p_world.has_entity(e):
			p_world._force_spawn(e)
		var components: Dictionary = p_delta.upserts[entity]
		for type_name in components.keys():
			var p_type := registry.type_by_name(type_name)
			if p_type == null:
				continue
			var component: Variant = _reconstruct(p_factory, type_name, components[type_name])
			p_world.set_component(e, p_type, component)
		restored += 1

	return GF_OperationResult.ok({
		"restored": restored,
		"removed_components": p_delta.removed_components.size(),
		"removed_entities": p_delta.removed_entities.size(),
	})
