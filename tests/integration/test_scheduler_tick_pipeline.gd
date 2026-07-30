# tests/integration/test_scheduler_tick_pipeline.gd
## 需要 Node 树，用 add_child_autoqfree
## 注意：GDScript 闭包对 bool/int 值类型按值捕获，使用 Dictionary 容器
extends GutTest

var _scheduler: GF_Scheduler


func before_each() -> void:
	_scheduler = GF_Scheduler.new()
	add_child_autoqfree(_scheduler)


func after_each() -> void:
	_scheduler = null


func test_register_adds_callback() -> void:
	var state := {"called": false}
	_scheduler.register(GF_Scheduler.TickGroup.FRAME, "test", func(_dt: float): state["called"] = true)
	_scheduler._process(0.016)
	assert_true(state["called"])


func test_interval_callback_fires_at_fixed_rate() -> void:
	var state := {"count": 0}
	_scheduler.register_interval(GF_Scheduler.TickGroup.FRAME, "test_interval", func(_dt: float): state["count"] += 1, 0.5)
	_scheduler._process(0.4)
	assert_eq(state["count"], 0)
	_scheduler._process(0.1)
	assert_eq(state["count"], 1)
	_scheduler._process(0.6)
	assert_eq(state["count"], 2)


func test_pause_stops_all() -> void:
	var state := {"called": false}
	_scheduler.register(GF_Scheduler.TickGroup.FRAME, "test", func(_dt: float): state["called"] = true)
	_scheduler.pause()
	_scheduler._process(0.016)
	assert_false(state["called"])
	_scheduler.resume()
	_scheduler._process(0.016)
	assert_true(state["called"])


func test_unregister_removes_callback() -> void:
	var state := {"called": false}
	_scheduler.register(GF_Scheduler.TickGroup.FRAME, "test", func(_dt: float): state["called"] = true)
	_scheduler.unregister("test")
	_scheduler._process(0.016)
	assert_false(state["called"])
