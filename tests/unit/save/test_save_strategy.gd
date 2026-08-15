# tests/unit/save/test_save_strategy.gd
## GF_SaveStrategy 三策略单元测试（性能路线图 §3.2）。
## Full 透传 / Delta 增量与压缩 / SeedPatch 重放编排 / SaveService 集成。
extends GutTest

var _full: GF_FullSaveStrategy
var _delta: GF_DeltaSaveStrategy
var _seed: GF_SeedPatchSaveStrategy

var _service: GF_SaveService
var _provider: GF_FakeSaveProvider
var _log: GF_FakeLogService
var _path_resolver: GF_PathResolver


func before_each() -> void:
	_full = GF_FullSaveStrategy.new()
	_delta = GF_DeltaSaveStrategy.new()
	_seed = GF_SeedPatchSaveStrategy.new()

	_provider = GF_FakeSaveProvider.new()
	_log = GF_FakeLogService.new()
	_log.module_name = "FakeLog"
	_log.init_module()
	_path_resolver = GF_PathResolver.new()
	_service = GF_SaveService.new()
	_service.module_name = "SaveService"
	_service.init_module()
	# 绕过 bootstrap 直接注入（configure 依赖 bootstrap 服务解析，测试无 bootstrap）
	_service._provider = _provider
	_service._path_resolver = _path_resolver
	_service._log = _log
	_service.strategy = GF_FullSaveStrategy.new()


func after_each() -> void:
	_full = null
	_delta = null
	_seed = null
	_service = null
	_provider = null
	_log = null
	_path_resolver = null


# ============================================================
# FULL：透传与默认
# ============================================================

func test_full_mode_name_and_passthrough() -> void:
	assert_eq(_full.get_mode_name(), "full")
	var data := {"a": 1}
	assert_eq(_full.build_payload(data), data)
	assert_eq(_full.restore_payload(data), data)


func test_save_service_defaults_to_full() -> void:
	assert_not_null(_service.strategy)
	assert_eq(_service.strategy.get_mode_name(), "full")


# ============================================================
# DELTA：增量、压缩、还原
# ============================================================

func test_delta_first_build_writes_base() -> void:
	var payload := _delta.build_payload({"hero": {"hp": 80}})
	assert_eq(payload.base, {"hero": {"hp": 80}})
	assert_eq(payload.deltas.size(), 0)


func test_delta_second_build_only_changed_modules() -> void:
	_delta.build_payload({"hero": {"hp": 80}, "map": {"seed": 1}})
	var payload := _delta.build_payload({"hero": {"hp": 90}, "map": {"seed": 1}})
	assert_eq(payload.deltas.size(), 1)
	assert_true(payload.deltas[0].has("hero"))
	assert_false(payload.deltas[0].has("map"), "未变模块不进 delta")


func test_delta_module_removal_as_null() -> void:
	_delta.build_payload({"hero": {"hp": 80}, "map": {"seed": 1}})
	var payload := _delta.build_payload({"hero": {"hp": 80}})
	assert_eq(payload.deltas[0].map, null)


func test_delta_restore_replays_deltas_in_order() -> void:
	_delta.build_payload({"hero": {"hp": 80}, "map": {"seed": 1}})
	_delta.build_payload({"hero": {"hp": 90}, "map": {"seed": 1}})
	var payload := _delta.build_payload({"hero": {"hp": 100}})
	var restored := _delta.restore_payload(payload)
	assert_eq(restored.hero, {"hp": 100})
	assert_false(restored.has("map"), "模块删除经 delta 还原")


func test_delta_compact_rewrites_base() -> void:
	_delta.max_deltas_before_compact = 3
	_delta.build_payload({"hero": {"hp": 1}})
	_delta.build_payload({"hero": {"hp": 2}})
	_delta.build_payload({"hero": {"hp": 3}})
	var payload := _delta.build_payload({"hero": {"hp": 4}})
	assert_eq(payload.deltas.size(), 0, "达到阈值后压缩清空 delta")
	assert_eq(payload.base, {"hero": {"hp": 4}}, "压缩后基底为最新全量")


func test_delta_reset_state() -> void:
	_delta.build_payload({"hero": {"hp": 1}})
	_delta.reset_state()
	var payload := _delta.build_payload({"hero": {"hp": 2}})
	assert_eq(payload.deltas.size(), 0)
	assert_eq(payload.base, {"hero": {"hp": 2}})


# ============================================================
# SEED_PATCH：种子、改动记录、重放编排
# ============================================================

func test_seed_patch_mode_and_payload() -> void:
	assert_eq(_seed.get_mode_name(), "seed_patch")
	_seed.set_seed(777)
	_seed.set_patch_records([{"cmd": "build"}])
	var payload := _seed.build_payload({"profile": {"gold": 5}})
	assert_eq(payload.seed, 777)
	assert_eq(payload.patch_records.size(), 1)
	assert_eq(payload.base_data, {"profile": {"gold": 5}})


func test_seed_patch_restore_restores_state() -> void:
	var restored := _seed.restore_payload({
		"seed": 42,
		"patch_records": [{"cmd": "x"}],
		"base_data": {"profile": {}},
	})
	assert_eq(_seed.seed, 42)
	assert_eq(_seed.patch_records.size(), 1)
	assert_eq(restored, {"profile": {}})


func test_seed_patch_replay_order() -> void:
	var order: Array[String] = []
	_seed.reset_world_hook = func(): order.append("reset")
	_seed.generator_hook = func(p_seed: int): order.append("gen:%d" % p_seed)
	_seed.patch_applier_hook = func(records: Array): order.append("patch:%d" % records.size())
	_seed.set_seed(9)
	_seed.set_patch_records([1, 2])
	_seed.replay()
	assert_eq(order, ["reset", "gen:9", "patch:2"])


# ============================================================
# SaveService 集成：mode 头、往返、旧存档兼容
# ============================================================

func test_save_all_writes_save_mode() -> void:
	_service.register_saveable(_make_saveable("hero", {"hp": 80}))
	var meta := GF_SaveMeta.new()
	meta.slot_id = 1
	var result := _service.save_all(1, meta)
	assert_true(result.is_ok())
	var wrapper: Dictionary = _provider.load_full(1).data
	assert_eq(wrapper.meta.save_mode, "full", "默认策略写入 full 模式头")


func test_delta_strategy_save_load_roundtrip() -> void:
	_service.set_strategy(_delta)
	var hero = _make_saveable("hero", {"hp": 80})
	var map = _make_saveable("map", {"seed": 1})
	_service.register_saveable(hero)
	_service.register_saveable(map)

	# 第一次存档：基底
	var meta := GF_SaveMeta.new()
	meta.slot_id = 1
	_service.save_all(1, meta)
	# 修改后第二次存档：增量
	hero.s_data = {"hp": 95}
	_service.save_all(1, meta)

	var result := _service.load_slot(1)
	assert_true(result.is_ok())
	assert_eq(result.data, {"hero": {"hp": 95}, "map": {"seed": 1}},
		"基底 + delta 合成当前全量")


func test_legacy_save_without_mode_loads_as_full() -> void:
	# 模拟旧版本存档：meta 无 save_mode 字段
	var legacy_wrapper := {
		"meta": {"save_version": 1, "slot_id": 1},
		"data": {"hero": {"hp": 10}},
	}
	_provider._store[1] = legacy_wrapper

	var result := _service.load_slot(1)
	assert_true(result.is_ok())
	assert_eq(result.data, {"hero": {"hp": 10}})


# ============================================================
# 辅助
# ============================================================

func _make_saveable(p_key: String, p_data: Dictionary, p_priority: int = 100):
	var saveable_script: GDScript = load("res://tests/helpers/dynamic_saveable.gd")
	var s = saveable_script.new()
	s.s_key = p_key
	s.s_data = p_data
	s.s_priority = p_priority
	return s
