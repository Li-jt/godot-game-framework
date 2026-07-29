# tests/unit/save/test_save_service.gd
extends GutTest

var _service: GF_SaveService
var _provider: GF_FakeSaveProvider
var _log: GF_FakeLogService
var _path_resolver: GF_PathResolver


func before_each() -> void:
	_provider = GF_FakeSaveProvider.new()
	_log = GF_FakeLogService.new()
	_log.module_name = "FakeLog"
	_log.init_module()
	_path_resolver = GF_PathResolver.new()
	_service = GF_SaveService.new()
	_service.module_name = "SaveService"
	_service.init_module()
	_service.configure(_provider, _path_resolver, _log)


func after_each() -> void:
	_service = null; _provider = null; _log = null; _path_resolver = null


func test_register_saveable() -> void:
	var saveable = _make_saveable("world.player", {"hp": 100})
	_service.register_saveable(saveable)
	_service.unregister_saveable("world.player")


func test_register_empty_key_skipped() -> void:
	var saveable = _make_saveable("", {})
	_service.register_saveable(saveable)
	assert_true(_log.has_message_containing("跳过"))


func test_unregister_by_prefix_batch() -> void:
	_service.register_saveable(_make_saveable("world.hero", {}))
	_service.register_saveable(_make_saveable("world.map", {}))
	_service.register_saveable(_make_saveable("profile.settings", {}))
	var removed := _service.unregister_by_prefix("world.")
	assert_eq(removed, 2)


func test_collect_from_registers_array() -> void:
	var list: Array = [_make_saveable("a", {}), _make_saveable("b", {})]
	var result := _service.collect_from(list)
	assert_true(result.is_ok())


func test_save_all_and_load_roundtrip() -> void:
	_service.register_saveable(_make_saveable("hero", {"hp": 80}))
	_service.register_saveable(_make_saveable("map", {"seed": 42}))
	var meta := GF_SaveMeta.new()
	meta.slot_id = 1
	var result := _service.save_all(1, meta)
	assert_true(result.is_ok())
	var load_result := _provider.load_full(1)
	assert_true(load_result.is_ok())
	var wrapper: Dictionary = load_result.data
	assert_eq(wrapper.data.hero.hp, 80)
	assert_eq(wrapper.data.map.seed, 42)


func test_save_sets_correct_version() -> void:
	_service.register_saveable(_make_saveable("hero", {"hp": 100}))
	var meta := GF_SaveMeta.new()
	_service.save_all(1, meta)
	var load_result := _provider.load_full(1)
	var wrapper: Dictionary = load_result.data
	assert_eq(wrapper.meta.save_version, GF_SaveVersion.CURRENT)


func test_load_slot_returns_data() -> void:
	_service.register_saveable(_make_saveable("hero", {"hp": 100}))
	var meta := GF_SaveMeta.new()
	_service.save_all(1, meta)
	var result := _service.load_slot(1)
	assert_true(result.is_ok())
	assert_eq(result.data.hero.hp, 100)


func test_load_slot_fails_if_version_too_high() -> void:
	var wrapper := {
		"meta": {"save_version": GF_SaveVersion.CURRENT + 99},
		"data": {"hero": {"hp": 100}},
	}
	_provider._store[1] = wrapper
	var result := _service.load_slot(1)
	assert_true(result.is_fail())


func test_load_and_restore_distributes_correctly() -> void:
	var hero = _make_saveable("hero", {"hp": 80})
	var map_sv = _make_saveable("map", {"seed": 42})
	_service.register_saveable(hero)
	_service.register_saveable(map_sv)
	var meta := GF_SaveMeta.new()
	_service.save_all(1, meta)

	var h_loaded := false
	var m_loaded := false
	_service.register_saveable(_make_saveable_cb("hero", {"hp": 0}, func(d): h_loaded = true))
	_service.register_saveable(_make_saveable_cb("map", {"seed": 0}, func(d): m_loaded = true))
	_service.load_and_restore(1)
	assert_true(h_loaded)
	assert_true(m_loaded)


func test_load_and_restore_orders_by_priority() -> void:
	var order: Array[String] = []
	_service.register_saveable(_make_saveable_cb("late", {}, func(_d): order.append("late"), 100))
	_service.register_saveable(_make_saveable_cb("early", {}, func(_d): order.append("early"), 1))
	_service.register_saveable(_make_saveable_cb("mid", {}, func(_d): order.append("mid"), 50))
	var meta := GF_SaveMeta.new()
	_service.save_all(1, meta)
	_service.load_and_restore(1)
	assert_eq(order[0], "early")
	assert_eq(order[1], "mid")
	assert_eq(order[2], "late")


func test_load_and_restore_skips_unregistered_keys() -> void:
	var wrapper := {
		"meta": {"save_version": GF_SaveVersion.CURRENT},
		"data": {"registered": {"x": 1}, "unregistered": {"y": 2}},
	}
	_provider._store[1] = wrapper
	_service.register_saveable(_make_saveable("registered", {}))
	var result := _service.load_and_restore(1)
	assert_true(result.is_ok())
	assert_true(_log.has_message_containing("未注册"))


# ============================================================
# 辅助
# ============================================================

func _make_saveable(p_key: String, p_data: Dictionary, p_priority: int = 100):
	return _make_saveable_cb(p_key, p_data, Callable(), p_priority)


func _make_saveable_cb(p_key: String, p_data: Dictionary, p_on_load, p_priority: int = 100):
	var s := GDScript.new()
	s.source_code = """
extends GF_ISaveable
var _key: String
var _data: Dictionary
var _priority: int
var _on_load
func _init(p_key: String, p_data: Dictionary, p_on_load, p_priority: int):
	_key = p_key; _data = p_data; _on_load = p_on_load; _priority = p_priority
func save_key() -> String: return _key
func on_save() -> Dictionary: return _data
func on_load(p_data: Dictionary) -> void: if _on_load and _on_load.is_valid(): _on_load.call(p_data)
func restore_priority() -> int: return _priority
"""
	s.reload()
	return s.new(p_key, p_data, p_on_load, p_priority)
