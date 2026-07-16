## EcsSaveVersionMigrator — ECS 存档版本迁移链。
## 按版本号顺序执行迁移步骤，将旧版存档数据转换到最新格式。
## 支持 Mod 注册/卸载迁移步骤。
class_name EcsSaveVersionMigrator
extends RefCounted

## 迁移步骤
class MigrationStep:
	var from_version: int = 0
	var to_version: int = 0
	var fn: Callable
	var owner: String = ""

## 注册的迁移步骤
var _migrations: Array[MigrationStep] = []


## 注册一个迁移步骤。
func register_migration(p_from: int, p_to: int, p_fn: Callable, p_owner: String = "") -> void:
	var step := MigrationStep.new()
	step.from_version = p_from
	step.to_version = p_to
	step.fn = p_fn
	step.owner = p_owner
	_migrations.append(step)


## 注销指定 owner 的所有迁移步骤。Mod 卸载时使用。
func unregister_by_owner(p_owner: String) -> int:
	var before := _migrations.size()
	var filtered: Array[MigrationStep] = []
	for step in _migrations:
		if step.owner != p_owner:
			filtered.append(step)
	_migrations = filtered
	return before - _migrations.size()


## 从数据版本迁移到目标版本。
func migrate(p_data: Dictionary, p_from_version: int, p_to_version: int) -> OperationResult:
	if p_from_version >= p_to_version:
		return OperationResult.ok(p_data)

	var current_data := p_data.duplicate(true)
	var current_version := p_from_version

	while current_version < p_to_version:
		var next: MigrationStep = _find_migration(current_version)
		if next == null:
			push_warning("[EcsSaveVersionMigrator] 版本 %d 无迁移步骤" % current_version)
			break
		var result = next.fn.call(current_data)
		if result is OperationResult:
			var r: OperationResult = result
			if r.is_fail():
				return r
			current_data = r.data
		else:
			current_data = result
		current_version = next.to_version

	return OperationResult.ok(current_data)


func _find_migration(p_from: int) -> MigrationStep:
	for m in _migrations:
		if m.from_version == p_from:
			return m
	return null
