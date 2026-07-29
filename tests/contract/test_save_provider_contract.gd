# tests/contract/test_save_provider_contract.gd
## 契约测试：SaveProvider 接口。
## 任何 SaveProvider 实现（Local/Fake 等）必须通过此套测试。
extends GutTest

var _provider: SaveProvider


func before_each() -> void:
	_provider = FakeSaveProvider.new()


func after_each() -> void:
	_provider = null


func test_save_and_load_full_roundtrip() -> void:
	var data := {"hero": {"hp": 100}}
	var meta := SaveMeta.new()
	meta.save_version = 1
	_provider.save(1, data, meta)

	var result := _provider.load_full(1)
	assert_true(result.is_ok())
	var wrapper: Dictionary = result.data
	assert_eq(wrapper.data, data)


func test_load_full_fails_for_missing_slot() -> void:
	var result := _provider.load_full(999)
	assert_true(result.is_fail())


func test_list_slots_returns_valid_indices() -> void:
	var meta := SaveMeta.new()
	_provider.save(1, {}, meta)
	_provider.save(3, {}, meta)

	var result := _provider.list_slots()
	assert_true(result.is_ok())
	var slots = result.data
	assert_eq(slots.size(), 2)


func test_delete_removes_slot() -> void:
	var meta := SaveMeta.new()
	_provider.save(1, {}, meta)
	_provider.delete(1)

	var result := _provider.load_full(1)
	assert_true(result.is_fail())


func test_save_overwrites_existing() -> void:
	var meta := SaveMeta.new()
	_provider.save(1, {"v": 1}, meta)
	_provider.save(1, {"v": 2}, meta)

	var result := _provider.load_full(1)
	var wrapper: Dictionary = result.data
	assert_eq(wrapper.data.v, 2)
