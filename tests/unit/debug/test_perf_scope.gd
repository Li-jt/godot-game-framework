# tests/unit/debug/test_perf_scope.gd
## GF_PerfScope 单元测试（性能路线图 §4）。
## 作用域计时：析构时自动入统计。
extends GutTest

var _stats: GF_PerfStats
var _samples_before_release: int = -1


func before_each() -> void:
	_stats = GF_PerfStats.new()


func after_each() -> void:
	_stats = null


func test_scope_records_on_release() -> void:
	# 释放路径说明：函数作用域结束是稳定释放路径——scope = null 的
	# refcount 释放在 Godot 4.7 下时机不可靠（偶发延迟导致 flaky），
	# free() 对 RefCounted 被引擎禁止（Attempted to free a RefCounted）。
	_samples_before_release = -1
	_run_scoped()
	assert_eq(_stats.sample_count(), 1)
	assert_eq(_samples_before_release, 0, "释放前不记录")
	assert_true(_stats.last_ms() >= 0.0)


func test_scope_records_on_function_return() -> void:
	_run_scoped()
	assert_eq(_stats.sample_count(), 1)


func test_scope_uses_stats_current_frame() -> void:
	_stats.current_frame = 42
	_run_scoped()
	assert_eq(_stats.peak_frame(), 42)


func _run_scoped() -> void:
	var scope := GF_PerfScope.new(_stats)
	_samples_before_release = _stats.sample_count()
	# 函数返回时 scope 析构，耗时自动入统计
