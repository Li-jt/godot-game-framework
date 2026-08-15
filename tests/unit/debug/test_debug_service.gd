# tests/unit/debug/test_debug_service.gd
## GF_DebugService 单元测试。
## 调试面板注册、命令追踪、网络统计。
extends GutTest

var _debug: GF_DebugService
var _log: GF_FakeLogService


func before_each() -> void:
	_log = GF_FakeLogService.new()
	_log.module_name = "FakeLog"
	_log.init_module()

	_debug = GF_DebugService.new()
	_debug.module_name = "DebugService"
	_debug.init_module()

	# 绕过 bootstrap 直接注入，避免内置 LogService 覆盖 fake
	_debug._log = _log
	_debug.enabled = true
	_debug.command_trace_enabled = true


func after_each() -> void:
	_debug = null
	_log = null


func test_enabled_true_after_configure() -> void:
	assert_true(_debug.enabled)


func test_register_panel_stores_factory() -> void:
	_debug.register_panel("test_panel", func(): return Node.new())
	assert_eq(_debug.panels.size(), 1)
	assert_true(_debug.panels.has("test_panel"))


func test_get_panel_names_returns_all() -> void:
	_debug.register_panel("panel_a", func(): return Node.new())
	_debug.register_panel("panel_b", func(): return Node.new())
	var names := _debug.get_panel_names()
	assert_eq(names.size(), 2)


func test_tick_stats_updates_fps_after_one_second() -> void:
	_debug.tick_stats(0.016)
	_debug.tick_stats(0.016)
	# 需要超过 1 秒才更新 fps
	var total: float = 0.0
	while total < 1.1:
		_debug.tick_stats(0.016)
		total += 0.016
	assert_true(_debug.fps >= 0.0)


func test_trace_command_stores_in_history() -> void:
	_debug.trace_command("cmd_1", "move", "executed")
	var history := _debug.get_command_history()
	assert_eq(history.size(), 1)
	assert_eq(history[0].id, "cmd_1")
	assert_eq(history[0].type, "move")


func test_trace_command_respects_max_history() -> void:
	for i in range(250):
		_debug.trace_command("cmd_%d" % i, "type", "executed")
	var history := _debug.get_command_history()
	assert_true(history.size() <= GF_DebugService.MAX_COMMAND_HISTORY)


func test_trace_command_disabled_when_flag_off() -> void:
	_debug.command_trace_enabled = false
	_debug.trace_command("cmd_1", "type", "executed")
	assert_eq(_debug.get_command_history().size(), 0)


func test_record_network_request_increments() -> void:
	_debug.record_network_request(true)
	assert_eq(_debug.network_requests, 1)
	assert_eq(_debug.network_errors, 0)

	_debug.record_network_request(false)
	assert_eq(_debug.network_requests, 2)
	assert_eq(_debug.network_errors, 1)


func test_reset_network_stats_clears() -> void:
	_debug.record_network_request(false)
	_debug.reset_network_stats()
	assert_eq(_debug.network_requests, 0)
	assert_eq(_debug.network_errors, 0)


# ============================================================
# 子系统耗时统计（性能路线图 §4）
# ============================================================

func test_perf_stats_creates_and_reuses() -> void:
	var stats := _debug.perf_stats("GrowthSystem")
	var stats2 := _debug.perf_stats("GrowthSystem")
	assert_eq(stats, stats2)
	assert_true(stats is GF_PerfStats)


func test_subsystem_stats_unknown_returns_empty() -> void:
	assert_eq(_debug.subsystem_stats("Nope"), {})


func test_subsystem_stats_reports_values() -> void:
	var stats := _debug.perf_stats("GrowthSystem")
	stats.record(2.0)
	stats.record(4.0)
	var snap := _debug.subsystem_stats("GrowthSystem")
	assert_eq(snap.avg_ms, 3.0)
	assert_eq(snap.max_ms, 4.0)


func test_get_subsystem_names_returns_all() -> void:
	_debug.perf_stats("A")
	_debug.perf_stats("B")
	var names := _debug.get_subsystem_names()
	assert_eq(names.size(), 2)
	assert_true(names.has("A"))
	assert_true(names.has("B"))


func test_tick_stats_syncs_current_frame() -> void:
	var stats := _debug.perf_stats("GrowthSystem")
	_debug.tick_stats(0.016)
	assert_eq(stats.current_frame, 1)
	_debug.tick_stats(0.016)
	assert_eq(stats.current_frame, 2)


func test_threading_stats_provider_feeds_subsystems() -> void:
	_debug.threading_stats_provider = func() -> Dictionary:
		return {"submitted": 10, "avg_duration_ms": 1.5}
	_debug.tick_stats(0.016)
	assert_true(_debug.get_subsystem_names().has("threading.submitted"))
	assert_eq(_debug.subsystem_stats("threading.submitted").last_ms, 10.0)
	assert_eq(_debug.subsystem_stats("threading.avg_duration_ms").last_ms, 1.5)


func test_attach_threading_service_feeds_stats() -> void:
	# §6 一代收尾：便捷接线真实 ThreadingService
	var threading := GF_ThreadingService.new()
	threading.module_name = "Threading"
	threading.init_module()
	_debug.attach_threading_service(threading)
	_debug.tick_stats(0.016)
	assert_true(_debug.get_subsystem_names().has("threading.submitted"),
		"接线后 ThreadingService 统计入子系统")
	assert_eq(_debug.subsystem_stats("threading.submitted").last_ms, 0.0)
