## EcsSaveVersionMigrator — ECS 存档版本迁移链。
## 按版本号顺序执行迁移步骤，将旧版存档数据转换到最新格式。
class_name EcsSaveVersionMigrator
extends RefCounted

## 注册的迁移步骤：Array[{from_version, to_version, migrate_fn}]
var _migrations: Array = []


## 注册一个迁移步骤。
func register_migration(p_from: int, p_to: int, p_fn: Callable) -> void:
	_migrations.append({
		"from": p_from,
		"to": p_to,
		"fn": p_fn,
	})


## 从数据版本迁移到目标版本。
func migrate(p_data: Dictionary, p_from_version: int, p_to_version: int) -> OperationResult:
	if p_from_version >= p_to_version:
		return OperationResult.ok(p_data)

	var current_data := p_data.duplicate(true)
	var current_version := p_from_version

	while current_version < p_to_version:
		var next := _find_migration(current_version)
		if next.is_empty():
			push_warning("[EcsSaveVersionMigrator] 版本 %d 无迁移步骤" % current_version)
			break
		var fn: Callable = next["fn"]
		var to_version: int = next["to"]
		var result = fn.call(current_data)
		if result is OperationResult:
			var r: OperationResult = result
			if r.is_fail():
				return r
			current_data = r.data
		else:
			current_data = result
		current_version = to_version

	return OperationResult.ok(current_data)


func _find_migration(p_from: int) -> Dictionary:
	for m in _migrations:
		if m.from == p_from:
			return m
	return {}
