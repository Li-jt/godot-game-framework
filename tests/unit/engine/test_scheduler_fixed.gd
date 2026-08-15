# tests/unit/engine/test_scheduler_fixed.gd
## GF_Scheduler SIMULATION_FIXED 固定步长组测试（性能路线图 §2）。
## 恒定 delta、accumulator、追帧上限、tick 计数、暂停、帧率无关性。
extends GutTest

var _scheduler: GF_Scheduler


func before_each() -> void:
	_scheduler = add_child_autoqfree(GF_Scheduler.new())


func after_each() -> void:
	_scheduler = null


func _register_fixed(p_counter: Array[int]) -> void:
	_scheduler.register(GF_Scheduler.TickGroup.SIMULATION_FIXED, "fixed_dummy",
		func(_d: float): p_counter[0] += 1)


# ============================================================
# 固定步长语义
# ============================================================

func test_fixed_group_receives_constant_delta() -> void:
	var deltas: Array[float] = []
	_scheduler.register(GF_Scheduler.TickGroup.SIMULATION_FIXED, "fixed_dummy",
		func(d: float): deltas.append(d))
	_scheduler._process(0.04)
	assert_eq(deltas.size(), 1)
	assert_almost_eq(deltas[0], 1.0 / 30.0, 0.0001, "delta 恒为 fixed_step_seconds")


func test_no_tick_below_one_step() -> void:
	var counter: Array[int] = [0]
	_register_fixed(counter)
	_scheduler._process(0.01)  # 1/100 < 1/30：accumulator 不足一步
	assert_eq(counter[0], 0)


func test_multiple_steps_per_frame() -> void:
	var counter: Array[int] = [0]
	_register_fixed(counter)
	_scheduler._process(0.07)  # 2.1 步 → 2 ticks
	assert_eq(counter[0], 2)


func test_tick_index_monotonic() -> void:
	var counter: Array[int] = [0]
	_register_fixed(counter)
	_scheduler._process(0.04)
	_scheduler._process(0.04)
	assert_eq(_scheduler.fixed_tick_index, 2)


# ============================================================
# 追帧上限（防螺旋死亡）
# ============================================================

func test_max_steps_cap() -> void:
	var counter: Array[int] = [0]
	_register_fixed(counter)
	_scheduler._process(1.0)  # 30 步但上限 3
	assert_eq(counter[0], 3)
	assert_eq(_scheduler.fixed_tick_index, 3)


func test_dropped_accumulator_after_cap() -> void:
	var counter: Array[int] = [0]
	_register_fixed(counter)
	_scheduler._process(1.0)  # 3 步，剩余 0.9 秒被丢弃
	assert_eq(counter[0], 3)
	_scheduler._process(0.01)
	assert_eq(counter[0], 3, "追帧上限后多余累计被丢弃，不持续追帧")


# ============================================================
# 暂停与计时
# ============================================================

func test_paused_fixed_group_not_ticked() -> void:
	var counter: Array[int] = [0]
	_register_fixed(counter)
	_scheduler.pause_group(GF_Scheduler.TickGroup.SIMULATION_FIXED)
	_scheduler._process(0.1)
	assert_eq(counter[0], 0, "暂停时固定组不 tick 也不累计")
	_scheduler.resume_group(GF_Scheduler.TickGroup.SIMULATION_FIXED)
	_scheduler._process(0.1)
	assert_true(counter[0] > 0)


func test_perf_monitoring_records_fixed_group() -> void:
	_scheduler.perf_monitoring = true
	var counter: Array[int] = [0]
	_register_fixed(counter)
	_scheduler._process(0.04)
	assert_true(_scheduler.tick_group_times.has("SIMULATION_FIXED"))


# ============================================================
# 帧率无关性（决定论验收）
# ============================================================

func test_framerate_independent_tick_count() -> void:
	# 用二进制精确值（1/8 步长、8/16fps 帧序列）避免浮点累计误差：
	# 0.5 秒模拟时间在两种帧率下都精确等于 4 步
	# 数组包装：GDScript lambda 值捕获，int 需经引用语义容器回传
	var calls_8fps: Array[int] = [0]
	var sched_a: GF_Scheduler = add_child_autoqfree(GF_Scheduler.new())
	sched_a.fixed_step_seconds = 0.125
	sched_a.register(GF_Scheduler.TickGroup.SIMULATION_FIXED, "dummy",
		func(_d: float): calls_8fps[0] += 1)
	for i in 4:  # 8fps × 4 帧 × 0.125s = 0.5s
		sched_a._process(0.125)

	var calls_16fps: Array[int] = [0]
	var sched_b: GF_Scheduler = add_child_autoqfree(GF_Scheduler.new())
	sched_b.fixed_step_seconds = 0.125
	sched_b.register(GF_Scheduler.TickGroup.SIMULATION_FIXED, "dummy",
		func(_d: float): calls_16fps[0] += 1)
	for i in 8:  # 16fps × 8 帧 × 0.0625s = 0.5s
		sched_b._process(0.0625)

	assert_eq(calls_8fps[0], 4)
	assert_eq(calls_8fps[0], calls_16fps[0], "不同渲染帧率下固定组 tick 次数一致")


# ============================================================
# GF_EcsScheduler 固定组集成
# ============================================================

func test_ecs_scheduler_has_fixed_group() -> void:
	var ecs := GF_EcsScheduler.new()
	var group := ecs.get_group(GF_EcsScheduler.GROUP_SIMULATION_FIXED)
	assert_not_null(group)
	assert_true(group.fixed_tick, "预设固定组应标记 fixed_tick")


func test_ecs_tick_and_tick_fixed_are_separated() -> void:
	var world := GF_EcsWorld.new()
	var ecs := GF_EcsScheduler.new(world)
	var sys: GF_EcsSystem = load("res://tests/helpers/dynamic_ecs_system.gd").new()
	var tick_count: Array[int] = [0]
	sys._tick_fn = func(_w, _e, _d: float): tick_count[0] += 1
	ecs.register_system(sys, GF_EcsScheduler.GROUP_SIMULATION_FIXED)
	ecs.start()

	ecs.tick(0.016)  # 普通 tick 不驱动固定组
	assert_eq(tick_count[0], 0, "tick() 不应驱动固定组系统")
	ecs.tick_fixed(1.0 / 30.0)
	assert_eq(tick_count[0], 1, "tick_fixed() 驱动固定组系统")

	ecs.stop()
	world.reset()
