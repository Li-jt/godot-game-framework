# modules/debug/perf_scope.gd
## GF_PerfScope — 作用域计时器。
## 构造时开始计时，实例销毁（refcount 归零）时把耗时写入 GF_PerfStats。
## [b]必须绑定局部变量使用[/b]——临时对象会在语句结束时立即析构，计时为 0：
## [codeblock]
## var scope := GF_PerfScope.new(debug.perf_stats("GrowthSystem"))
## # ... 被测代码 ...
## # 函数返回时 scope 析构，耗时自动入统计
## [/codeblock]
class_name GF_PerfScope
extends RefCounted

var _stats: GF_PerfStats = null
var _start_usec: int = 0


func _init(p_stats: GF_PerfStats) -> void:
	_stats = p_stats
	_start_usec = Time.get_ticks_usec()


func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_PREDELETE and _stats != null:
		var elapsed_ms := float(Time.get_ticks_usec() - _start_usec) / 1000.0
		_stats.record(elapsed_ms)
		_stats = null
