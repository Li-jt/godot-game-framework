# tests/unit/engine/test_scheduler_perf.gd
## GF_Scheduler 性能计时单元测试（性能路线图 §4）。
## perf_monitoring 开关、TickGroup 耗时统计、暂停组跳过。
extends GutTest

var _scheduler: GF_Scheduler


func before_each() -> void:
	_scheduler = add_child_autoqfree(GF_Scheduler.new())


func after_each() -> void:
	# autoqfree 节点由 GUT 在测试后自动释放
	_scheduler = null


func test_monitoring_off_no_group_times() -> void:
	_scheduler.register(GF_Scheduler.TickGroup.FRAME, "dummy", func(_d: float): pass)
	_scheduler._process(0.016)
	assert_eq(_scheduler.tick_group_times.size(), 0)


func test_monitoring_on_records_group_times() -> void:
	_scheduler.perf_monitoring = true
	_scheduler.register(GF_Scheduler.TickGroup.FRAME, "dummy", func(_d: float): pass)
	_scheduler._process(0.016)
	assert_true(_scheduler.tick_group_times.has("FRAME"))
	assert_true(_scheduler.tick_group_times.has("SIMULATION"))
	assert_true(_scheduler.tick_group_times.has("UI"))
	assert_true(_scheduler.tick_group_times.has("SAVE"))
	assert_true(_scheduler.tick_group_times.has("DEBUG"))
	assert_true(_scheduler.tick_group_times["FRAME"] >= 0.0)


func test_physics_process_records_physics_group() -> void:
	_scheduler.perf_monitoring = true
	_scheduler._physics_process(0.016)
	assert_true(_scheduler.tick_group_times.has("PHYSICS"))


func test_paused_group_not_recorded() -> void:
	_scheduler.perf_monitoring = true
	_scheduler.pause_group(GF_Scheduler.TickGroup.FRAME)
	_scheduler._process(0.016)
	assert_false(_scheduler.tick_group_times.has("FRAME"))


func test_group_entries_still_tick_with_monitoring() -> void:
	# 开启计时后回调仍按组正常执行
	_scheduler.perf_monitoring = true
	var frame_calls := 0
	var sim_calls := 0
	_scheduler.register(GF_Scheduler.TickGroup.FRAME, "frame_entry", func(_d: float):
		frame_calls += 1
	)
	_scheduler.register(GF_Scheduler.TickGroup.SIMULATION, "sim_entry", func(_d: float):
		sim_calls += 1
	)
	_scheduler._process(0.016)
	assert_eq(frame_calls, 1)
	assert_eq(sim_calls, 1)
