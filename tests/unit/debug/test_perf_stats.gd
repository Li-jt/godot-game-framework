# tests/unit/debug/test_perf_stats.gd
## GF_PerfStats 单元测试（性能路线图 §4）。
## 环形缓冲、avg/max/尖峰帧号、to_dict、reset。
extends GutTest

var _stats: GF_PerfStats


func before_each() -> void:
	_stats = GF_PerfStats.new()


func after_each() -> void:
	_stats = null


func test_empty_stats_defaults() -> void:
	assert_eq(_stats.sample_count(), 0)
	assert_eq(_stats.avg_ms(), 0.0)
	assert_eq(_stats.max_ms(), 0.0)
	assert_eq(_stats.peak_frame(), -1)
	assert_eq(_stats.last_ms(), 0.0)


func test_record_tracks_sample_and_avg() -> void:
	_stats.record(2.0)
	_stats.record(4.0)
	assert_eq(_stats.sample_count(), 2)
	assert_eq(_stats.avg_ms(), 3.0)
	assert_eq(_stats.last_ms(), 4.0)


func test_max_and_peak_frame() -> void:
	_stats.current_frame = 10
	_stats.record(1.0)
	_stats.current_frame = 12
	_stats.record(5.0)
	_stats.current_frame = 13
	_stats.record(3.0)
	assert_eq(_stats.max_ms(), 5.0)
	assert_eq(_stats.peak_frame(), 12)


func test_ring_overflow_keeps_max() -> void:
	_stats.current_frame = 1
	_stats.record(100.0)
	for i in range(GF_PerfStats.DEFAULT_RING_SIZE + 10):
		_stats.current_frame = i + 2
		_stats.record(1.0)
	# 样本被环形缓冲截断，但历史 max 保留
	assert_eq(_stats.sample_count(), GF_PerfStats.DEFAULT_RING_SIZE)
	assert_eq(_stats.max_ms(), 100.0)
	assert_eq(_stats.peak_frame(), 1)


func test_to_dict_snapshot() -> void:
	_stats.current_frame = 7
	_stats.record(3.0)
	var snap := _stats.to_dict()
	assert_eq(snap.avg_ms, 3.0)
	assert_eq(snap.max_ms, 3.0)
	assert_eq(snap.peak_frame, 7)
	assert_eq(snap.samples.size(), 1)


func test_reset_clears_all() -> void:
	_stats.record(3.0)
	_stats.reset()
	assert_eq(_stats.sample_count(), 0)
	assert_eq(_stats.max_ms(), 0.0)
	assert_eq(_stats.peak_frame(), -1)
