## GF_Scheduler
## 统一 Tick 驱动器。按 TickGroup 分组执行，同组内按 priority 排序。
## PHYSICS 组由 _physics_process 驱动（固定步长），其余由 _process 驱动。
class_name GF_Scheduler
extends Node

enum TickGroup {
	PHYSICS = -10,     # 固定步长（_physics_process 驱动，默认 60Hz）
	FRAME = 0,         # 渲染相关（_process 驱动，可变帧率）
	SIMULATION = 10,   # 游戏逻辑（在 PHYSICS 或 FRAME 之后运行）
	UI = 50,           # UI 更新
	SAVE = 80,         # 自动保存
	DEBUG = 100,       # 调试面板
}

## 用于注销回调，不需要知道原始名称
class TickHandle:
	var entry_name: String = ""
	var _scheduler_ref: WeakRef = null

	func unregister() -> void:
		var sched: GF_Scheduler = _scheduler_ref.get_ref() if _scheduler_ref != null else null
		if sched != null:
			sched.unregister_by_handle(self)


class TickEntry:
	var name: String = ""
	var callback: Callable
	var group: TickGroup = TickGroup.FRAME
	var priority: int = 0
	var interval: float = 0.0
	var accumulator: float = 0.0


var time_scale: float = 1.0
var paused: bool = false
var _paused_groups: Array = []  # Array[TickGroup]

## 性能计时开关。true 时按 TickGroup 统计耗时到 tick_group_times。
## 由 GF_DebugService.attach_scheduler() 开启（opt-in，默认零开销）。
var perf_monitoring: bool = false

## 上一帧各 TickGroup 的耗时（毫秒）。perf_monitoring 开启时填充。
var tick_group_times: Dictionary = {}

var _entries: Array[TickEntry] = []
var _dirty: bool = false


# ============================================================
# 注册 / 注销
# ============================================================

## 注册逐帧回调。p_group 决定执行阶段，p_priority 越小越早执行。
## PHYSICS 组的回调接收固定 delta（如 1/60），其余接收可变 delta。
func register(p_group: TickGroup, p_name: String, p_callback: Callable, p_priority: int = 0) -> TickHandle:
	_remove(p_name)

	var entry := TickEntry.new()
	entry.name = p_name
	entry.callback = p_callback
	entry.group = p_group
	entry.priority = p_priority
	_entries.append(entry)
	_dirty = true

	return _make_handle(p_name)


## 注册固定间隔回调。interval 时间到达时触发，传递该间隔值。
## PHYSICS 组按物理步长累积，其余按帧 delta 累积。
func register_interval(p_group: TickGroup, p_name: String, p_callback: Callable, p_interval: float, p_priority: int = 0) -> TickHandle:
	_remove(p_name)

	var entry := TickEntry.new()
	entry.name = p_name
	entry.callback = p_callback
	entry.group = p_group
	entry.priority = p_priority
	entry.interval = p_interval
	entry.accumulator = 0.0
	_entries.append(entry)
	_dirty = true

	return _make_handle(p_name)


## 通过 TickHandle 注销
func unregister_by_handle(p_handle: TickHandle) -> void:
	if p_handle != null:
		_remove(p_handle.entry_name)


## 根据名称注销（向后兼容）
func unregister(p_name: String) -> void:
	_remove(p_name)


func has(p_name: String) -> bool:
	return _find(p_name) >= 0


# ============================================================
# 控制
# ============================================================

func pause() -> void:
	paused = true


func resume() -> void:
	paused = false


func is_paused() -> bool:
	return paused


func pause_group(p_group: TickGroup) -> void:
	if not _paused_groups.has(p_group):
		_paused_groups.append(p_group)


func resume_group(p_group: TickGroup) -> void:
	_paused_groups.erase(p_group)


func is_group_paused(p_group: TickGroup) -> bool:
	return _paused_groups.has(p_group)


func set_time_scale(p_scale: float) -> void:
	time_scale = maxf(0.0, p_scale)


# ============================================================
# 主 Tick
# ============================================================

func is_runtime_ready() -> bool:
	return true


## _process 驱动除 PHYSICS 以外的所有组。
func _process(p_delta: float) -> void:
	if paused:
		return

	if _dirty:
		_sort()
		_dirty = false

	var dt := p_delta * time_scale
	_tick_groups(dt, [
		TickGroup.FRAME,
		TickGroup.SIMULATION,
		TickGroup.UI,
		TickGroup.SAVE,
		TickGroup.DEBUG,
	])


## _physics_process 驱动 PHYSICS 组（固定步长）。
func _physics_process(p_delta: float) -> void:
	if paused:
		return

	if _dirty:
		_sort()
		_dirty = false

	var dt := p_delta * time_scale
	_tick_groups(dt, [TickGroup.PHYSICS])


## 逐组 tick。perf_monitoring 开启时统计每组耗时到 tick_group_times。
func _tick_groups(p_dt: float, p_groups: Array) -> void:
	for group in p_groups:
		if _paused_groups.has(group):
			continue
		if perf_monitoring:
			var start := Time.get_ticks_usec()
			_tick_entries(p_dt, func(e: TickEntry): return e.group == group)
			tick_group_times[TickGroup.find_key(group)] = \
				float(Time.get_ticks_usec() - start) / 1000.0
		else:
			_tick_entries(p_dt, func(e: TickEntry): return e.group == group)


func _tick_entries(p_dt: float, p_filter: Callable) -> void:
	var invalid_entries: Array[TickEntry] = []
	for entry in _entries:
		if _paused_groups.has(entry.group):
			continue
		if not p_filter.call(entry):
			continue
		if not entry.callback.is_valid():
			invalid_entries.append(entry)
			continue

		if entry.interval > 0.0:
			entry.accumulator += p_dt
			while entry.accumulator >= entry.interval:
				entry.accumulator -= entry.interval
				if not entry.callback.is_valid():
					invalid_entries.append(entry)
					break
				entry.callback.call(entry.interval)
		else:
			entry.callback.call(p_dt)

	for entry in invalid_entries:
		_entries.erase(entry)


# ============================================================
# 内部
# ============================================================

func _make_handle(p_name: String) -> TickHandle:
	var h := TickHandle.new()
	h.entry_name = p_name
	h._scheduler_ref = weakref(self)
	return h


func _remove(p_name: String) -> void:
	var idx := _find(p_name)
	if idx >= 0:
		_entries.remove_at(idx)


func _find(p_name: String) -> int:
	for i in _entries.size():
		if _entries[i].name == p_name:
			return i
	return -1


func _sort() -> void:
	_entries.sort_custom(func(a: TickEntry, b: TickEntry):
		if a.group != b.group:
			return int(a.group) < int(b.group)
		return a.priority < b.priority
	)
