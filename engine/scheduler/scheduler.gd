## Scheduler
## 统一 Tick 驱动器。按 TickGroup 分组执行，同组内按 priority 排序。
class_name Scheduler
extends Node

enum TickGroup {
	FRAME = 0,         # 渲染相关（最高频）
	SIMULATION = 10,   # 物理 / AI / 需求刷新
	UI = 50,           # UI 更新
	SAVE = 80,         # 自动保存
	DEBUG = 100,       # 调试面板
}

## 用于注销回调，不需要知道原始名称
class TickHandle:
	var entry_name: String = ""
	var _scheduler_ref: WeakRef = null

	func unregister() -> void:
		var sched: Scheduler = _scheduler_ref.get_ref() if _scheduler_ref != null else null
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

var _entries: Array[TickEntry] = []
var _dirty: bool = false


# ============================================================
# 注册 / 注销
# ============================================================

## 注册逐帧回调。p_group 决定执行阶段，p_priority 越小越早执行。
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


## 注册固定间隔回调。
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


func _process(p_delta: float) -> void:
	if paused:
		return

	if _dirty:
		_sort()
		_dirty = false

	var dt := p_delta * time_scale

	for entry in _entries:
		if _paused_groups.has(entry.group):
			continue

		if entry.interval > 0.0:
			entry.accumulator += dt
			if entry.accumulator >= entry.interval:
				entry.accumulator -= entry.interval
				entry.callback.call(entry.interval)
		else:
			entry.callback.call(dt)


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
