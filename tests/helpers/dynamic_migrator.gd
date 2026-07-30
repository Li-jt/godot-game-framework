# tests/helpers/dynamic_migrator.gd
## 动态 SaveVersionMigrator 测试替身。通过 _fn 注入迁移行为。
extends GF_SaveVersionMigrator

var _fn: Callable


func migrate(p_data: Dictionary) -> GF_OperationResult:
	var result = _fn.call(p_data)
	return GF_OperationResult.ok(result)
