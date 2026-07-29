# tests/integration/test_save_load_roundtrip.gd
## 集成测试：存档完整往返流程。
## GF_SaveService + GF_FakeSaveProvider + GF_ISaveable — 端到端存档恢复。
extends GutTest

var _service: GF_SaveService
var _provider: GF_FakeSaveProvider
var _log: GF_FakeLogService


class TestRoundtripSaveable extends GF_ISaveable:
	var _key: String
	var _data: Dictionary
	var _load_data: Dictionary = {}

	func _init(p_key: String, p_data: Dictionary) -> void:
		_key = p_key; _data = p_data

	func save_key() -> String: return _key
	func on_save() -> Dictionary: return _data
	func on_load(p_data: Dictionary) -> void: _load_data = p_data
	func restore_priority() -> int: return 100


func before_each() -> void:
	_provider = GF_FakeSaveProvider.new()
	_log = GF_FakeLogService.new()
	_log.module_name = "FakeLog"
	_log.init_module()
	var path_resolver := GF_PathResolver.new()

	_service = GF_SaveService.new()
	_service.module_name = "SaveService"
	_service.init_module()
	_service.configure(_provider, path_resolver, _log)


func after_each() -> void:
	_service = null; _provider = null; _log = null


func test_save_then_load_restores_correctly() -> void:
	var hero := TestRoundtripSaveable.new("hero", {"hp": 80, "mana": 50})
	var map := TestRoundtripSaveable.new("map", {"seed": 12345, "size": 64})
	_service.register_saveable(hero)
	_service.register_saveable(map)

	var meta := GF_SaveMeta.new()
	meta.slot_id = 1
	_service.save_all(1, meta)
	_service.load_and_restore(1)

	assert_eq(hero._load_data, {"hp": 80, "mana": 50})
	assert_eq(map._load_data, {"seed": 12345, "size": 64})


func test_multiple_slots_independent() -> void:
	var hero := TestRoundtripSaveable.new("hero", {"hp": 100})
	_service.register_saveable(hero)

	var meta1 := GF_SaveMeta.new(); meta1.slot_id = 1
	_service.save_all(1, meta1)

	hero._data = {"hp": 50}
	var meta2 := GF_SaveMeta.new(); meta2.slot_id = 2
	_service.save_all(2, meta2)

	_service.load_and_restore(1)
	assert_eq(hero._load_data.hp, 100)

	_service.load_and_restore(2)
	assert_eq(hero._load_data.hp, 50)


func test_delete_slot_then_load_fails() -> void:
	var hero := TestRoundtripSaveable.new("hero", {"hp": 100})
	_service.register_saveable(hero)
	var meta := GF_SaveMeta.new()
	_service.save_all(1, meta)
	_service.delete_slot(1)

	var result := _service.load_slot(1)
	assert_true(result.is_fail())
