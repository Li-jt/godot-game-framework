## EcsSaveAdapter — ECS 存档适配器。
## 将 EcsWorldSnapshot 桥接到 Framework SaveService，
## 支持组件级序列化/反序列化与存档版本管理。
class_name EcsSaveAdapter
extends RefCounted

var _snapshot_builder: EcsSnapshotBuilder = null
var _snapshot_applier: EcsSnapshotApplier = null
var _migrator: EcsSaveVersionMigrator = null
var _current_save_version: int = 1


func _init(p_current_save_version: int = 1) -> void:
	_snapshot_builder = EcsSnapshotBuilder.new()
	_snapshot_applier = EcsSnapshotApplier.new()
	_migrator = EcsSaveVersionMigrator.new()
	_current_save_version = p_current_save_version


## 从世界构建存档数据。
func save(p_world: EcsWorld) -> Dictionary:
	var snapshot := _snapshot_builder.build(p_world)
	return {
		"save_version": _current_save_version,
		"snapshot": snapshot.to_dict(),
	}


## 从存档数据恢复到世界。
func load(p_world: EcsWorld, p_save_data: Dictionary) -> OperationResult:
	var data_version: int = p_save_data.get("save_version", 0)

	# 版本迁移
	var migrated_data: Dictionary = p_save_data
	if data_version < _current_save_version:
		var migrate_result := _migrator.migrate(p_save_data, data_version, _current_save_version)
		if migrate_result.is_fail():
			return migrate_result
		migrated_data = migrate_result.data

	var snapshot_dict: Dictionary = migrated_data.get("snapshot", {})
	var snapshot := EcsWorldSnapshot.new()
	snapshot.from_dict(snapshot_dict)

	return _snapshot_applier.apply(p_world, snapshot)


## 设置当前存档版本号。
func set_save_version(p_version: int) -> void:
	_current_save_version = p_version


## 获取当前存档版本号。
func get_save_version() -> int:
	return _current_save_version
