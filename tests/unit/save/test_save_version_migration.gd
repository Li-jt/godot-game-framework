# tests/unit/save/test_save_version_migration.gd
extends GutTest

var _service: SaveService
var _log: FakeLogService


func before_each() -> void:
	_service = SaveService.new()
	_service.module_name = "SaveService"
	_service.init_module()
	_log = FakeLogService.new()
	_log.module_name = "FakeLog"
	_log.init_module()
	var provider := FakeSaveProvider.new()
	var path_resolver := PathResolver.new()
	_service.configure(provider, path_resolver, _log)


func after_each() -> void:
	_service = null; _log = null


func test_migration_chain_stepwise() -> void:
	_service.register_migrator(_make_migrator(1, 2, func(p_data: Dictionary) -> Dictionary:
		if p_data.has("hp"):
			p_data["health"] = p_data["hp"]
			p_data.erase("hp")
		return p_data
	))
	_service.register_migrator(_make_migrator(2, 3, func(p_data: Dictionary) -> Dictionary:
		p_data["format_version"] = 3
		return p_data
	))
	var wrapper := {"meta": {"save_version": 1}, "data": {"hp": 100}}
	var provider := _service._provider as FakeSaveProvider
	provider._store[1] = wrapper
	var result := _service.load_slot(1)
	assert_true(result.is_ok())


func test_migration_preserves_unrelated_fields() -> void:
	_service.register_migrator(_make_migrator(1, 2, func(p_data: Dictionary) -> Dictionary:
		p_data["new_field"] = "added"
		return p_data
	))
	var provider := _service._provider as FakeSaveProvider
	provider._store[1] = {"meta": {"save_version": 1}, "data": {"original_field": "keep_me"}}
	var result := _service.load_slot(1)
	assert_true(result.is_ok())
	assert_eq(result.data.original_field, "keep_me")
	assert_eq(result.data.new_field, "added")


func test_migration_version_too_high_rejected() -> void:
	var provider := _service._provider as FakeSaveProvider
	provider._store[1] = {"meta": {"save_version": SaveVersion.CURRENT + 10}, "data": {}}
	var result := _service.load_slot(1)
	assert_true(result.is_fail())


func test_missing_migrator_returns_fail() -> void:
	if SaveVersion.CURRENT > 1:
		var provider := _service._provider as FakeSaveProvider
		provider._store[1] = {"meta": {"save_version": 1}, "data": {}}
		var result := _service.load_slot(1)
		assert_true(result.is_fail())


# ============================================================
# 辅助
# ============================================================

func _make_migrator(p_from: int, p_to: int, p_fn: Callable) -> SaveVersionMigrator:
	var s := GDScript.new()
	s.source_code = """
extends SaveVersionMigrator
var _fn
func migrate(p_data: Dictionary) -> OperationResult:
	var result = _fn.call(p_data)
	return OperationResult.ok(result)
"""
	s.reload()
	var m = s.new()
	m._fn = p_fn
	m.from_version = p_from
	m.to_version = p_to
	return m
