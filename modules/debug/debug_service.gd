## GF_DebugService
## 调试服务。管理调试面板注册、运行时统计、命令追踪。
## 仅在 config.debug.enable_debug_panel = true 时启用。
class_name GF_DebugService
extends GF_ModuleLifecycle

var enabled: bool = false
var _log: GF_LogService = null

# 面板注册: name -> factory（无参返回 Node）
var panels: Dictionary = {}

# 运行时统计
var fps: float = 0.0
var frame_time_ms: float = 0.0
var _frame_count: int = 0
var _elapsed: float = 0.0

# 命令追踪
var command_trace_enabled: bool = false
var _command_history: Array = []    # Array[Dictionary]
const MAX_COMMAND_HISTORY: int = 200

# 网络统计
var network_requests: int = 0
var network_errors: int = 0

# 子系统耗时统计: String -> GF_PerfStats
var _subsystem_stats: Dictionary = {}
# 单调帧号（tick_stats 递增，供 GF_PerfStats 归属样本帧）
var _current_frame: int = 0
# 可选线程统计源：() -> Dictionary，接线后每帧自动入子系统统计
# （如 ThreadingService.get_stats()，产出 "threading.submitted" 等条目）
var threading_stats_provider: Callable = Callable()
# Scheduler 引用（attach_scheduler 注入；未注入时 tick_stats 跳过调度器统计）
var _scheduler: GF_Scheduler = null


func _on_init() -> GF_OperationResult:
	return GF_OperationResult.ok()


## 配置调试服务。默认跟随 Godot 调试模式。

func dependencies() -> Array:
	return [GF_LogService]

func configure() -> GF_OperationResult:
	_log = _bootstrap.service(GF_LogService) as GF_LogService
	return GF_OperationResult.ok()


# ============================================================
# 面板管理
# ============================================================

func register_panel(p_name: String, p_factory: Callable) -> void:
	panels[p_name] = p_factory


func get_panel_names() -> Array[String]:
	var names: Array[String] = []
	names.assign(panels.keys())
	return names


# ============================================================
# 运行时统计
# ============================================================

## 由 GF_Scheduler TickGroup.DEBUG 每帧调用
func tick_stats(p_delta: float) -> void:
	if not enabled:
		return
	_current_frame += 1
	for stats in _subsystem_stats.values():
		stats.current_frame = _current_frame
	_frame_count += 1
	_elapsed += p_delta
	if _elapsed >= 1.0:
		fps = _frame_count / _elapsed
		frame_time_ms = (_elapsed / _frame_count) * 1000.0
		_frame_count = 0
		_elapsed = 0.0
	# 线程统计接线（无 provider 时零开销）
	if threading_stats_provider.is_valid():
		var ts: Dictionary = threading_stats_provider.call()
		for key in ts:
			perf_stats("threading.%s" % key).record(float(ts[key]))
	# Scheduler 各 TickGroup 耗时（attach_scheduler 后生效）
	if _scheduler != null:
		for group_name in _scheduler.tick_group_times.keys():
			perf_stats("scheduler.%s" % group_name).record(
				float(_scheduler.tick_group_times[group_name])
			)


# ============================================================
# 命令追踪
# ============================================================

func trace_command(p_id: String, p_type: String, p_state: String = "executed") -> void:
	if not command_trace_enabled:
		return
	_command_history.append({
		"id": p_id,
		"type": p_type,
		"state": p_state,
		"time": Time.get_datetime_string_from_system(false, true),
	})
	while _command_history.size() > MAX_COMMAND_HISTORY:
		_command_history.pop_front()


func get_command_history() -> Array:
	return _command_history


# ============================================================
# 网络统计
# ============================================================

func record_network_request(p_success: bool) -> void:
	network_requests += 1
	if not p_success:
		network_errors += 1


func reset_network_stats() -> void:
	network_requests = 0
	network_errors = 0


# ============================================================
# 子系统耗时统计（性能观测，见 docs 性能优化路线图 §4）
# ============================================================


## 获取或创建指定子系统的统计对象。
## 使用方系统在 tick 内创建 GF_PerfScope 时传入此对象：
## [codeblock]
## var scope := GF_PerfScope.new(debug.perf_stats("GrowthSystem"))
## [/codeblock]
func perf_stats(p_name: String) -> GF_PerfStats:
	if not _subsystem_stats.has(p_name):
		var stats := GF_PerfStats.new()
		_subsystem_stats[p_name] = stats
	return _subsystem_stats[p_name]


## 读取子系统统计快照。未注册的子系统返回空字典。
## 返回 {avg_ms, max_ms, peak_frame, last_ms, samples}。
func subsystem_stats(p_name: String) -> Dictionary:
	var stats: GF_PerfStats = _subsystem_stats.get(p_name, null)
	if stats == null:
		return {}
	return stats.to_dict()


## 返回全部已注册子系统名。
func get_subsystem_names() -> Array[String]:
	var names: Array[String] = []
	for key in _subsystem_stats.keys():
		names.append(key)
	return names


## 注入 GF_Scheduler 并开启其 perf_monitoring（opt-in）。
## 之后 tick_stats 每帧自动把各 TickGroup 耗时写入 "scheduler.<组名>" 统计。
func attach_scheduler(p_scheduler: GF_Scheduler) -> void:
	_scheduler = p_scheduler
	p_scheduler.perf_monitoring = true


## 便捷接线：把 GF_ThreadingService 的统计注册为固定子系统项
## （threading.submitted / queue_peak / avg_duration_ms 等，随 tick_stats
## 每帧自动刷新）——性能路线图 §6「一代收尾」。
func attach_threading_service(p_service: GF_ThreadingService) -> void:
	threading_stats_provider = func() -> Dictionary:
		return p_service.get_stats()
