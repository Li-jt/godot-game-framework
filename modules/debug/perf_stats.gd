# modules/debug/perf_stats.gd
## GF_PerfStats — 单子系统耗时统计（环形缓冲）。
## 记录最近 N 个样本，维护 avg/max 与尖峰帧号。
## 由 GF_DebugService.perf_stats() 创建，GF_PerfScope 写入。
class_name GF_PerfStats
extends RefCounted

## 环形缓冲容量（最近 N 个样本）
const DEFAULT_RING_SIZE := 60

var _samples: Array[float] = []
var _ring_size: int = DEFAULT_RING_SIZE
var _max_ms: float = 0.0
var _peak_frame: int = -1
## 当前帧号。由 GF_DebugService.tick_stats() 每帧同步，
## GF_PerfScope 析构时按此帧号归属样本。
var current_frame: int = 0


## 记录一次耗时样本（毫秒）。
func record(p_ms: float) -> void:
	_samples.append(p_ms)
	while _samples.size() > _ring_size:
		_samples.pop_front()
	if p_ms > _max_ms:
		_max_ms = p_ms
		_peak_frame = current_frame


## 样本数量（最多为环形缓冲容量）。
func sample_count() -> int:
	return _samples.size()


## 最近 N 个样本的平均耗时（毫秒）。无样本时返回 0。
func avg_ms() -> float:
	if _samples.is_empty():
		return 0.0
	var total := 0.0
	for ms in _samples:
		total += ms
	return total / _samples.size()


## 历史最大耗时（毫秒，含已溢出缓冲的样本）。
func max_ms() -> float:
	return _max_ms


## 最大耗时发生的帧号。无样本时返回 -1。
func peak_frame() -> int:
	return _peak_frame


## 最近一次样本耗时（毫秒）。
func last_ms() -> float:
	return _samples[-1] if not _samples.is_empty() else 0.0


## 导出统计快照，供面板渲染 / 日志输出。
func to_dict() -> Dictionary:
	return {
		"avg_ms": avg_ms(),
		"max_ms": _max_ms,
		"peak_frame": _peak_frame,
		"last_ms": last_ms(),
		"samples": _samples.duplicate(),
	}


## 清空全部样本与极值。
func reset() -> void:
	_samples.clear()
	_max_ms = 0.0
	_peak_frame = -1
