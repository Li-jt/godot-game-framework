# tests/integration/test_scheduler_tick_pipeline.gd
## 需要 Node 树，用 add_child_autoqfree 替代 autoq
extends GutTest

var _scheduler: Scheduler


func before_each() -> void:
	_scheduler = Scheduler.new()
	add_child_autoqfree(_scheduler)


func after_each() -> void:
	_scheduler = null


func test_register_adds_callback() -> void:
	var called := false
	_scheduler.register(Scheduler.TickGroup.FRAME, "test", func(_dt: float): called = true)
	_scheduler._process(0.016)
	assert_true(called)


func test_interval_callback_fires_at_fixed_rate() -> void:
	var call_count := 0
	_scheduler.register_interval(Scheduler.TickGroup.FRAME, "test_interval", func(_dt: float): call_count += 1, 0.5)
	_scheduler._process(0.4)
	assert_eq(call_count, 0)
	_scheduler._process(0.1)
	assert_eq(call_count, 1)
	_scheduler._process(0.6)
	assert_eq(call_count, 2)


func test_pause_stops_all() -> void:
	var called := false
	_scheduler.register(Scheduler.TickGroup.FRAME, "test", func(_dt: float): called = true)
	_scheduler.pause()
	_scheduler._process(0.016)
	assert_false(called)
	_scheduler.resume()
	_scheduler._process(0.016)
	assert_true(called)


func test_unregister_removes_callback() -> void:
	var called := false
	_scheduler.register(Scheduler.TickGroup.FRAME, "test", func(_dt: float): called = true)
	_scheduler.unregister("test")
	_scheduler._process(0.016)
	assert_false(called)
