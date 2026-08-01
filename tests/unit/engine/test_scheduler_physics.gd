# tests/unit/engine/test_scheduler_physics.gd
## GF_Scheduler PHYSICS TickGroup 单元测试。
extends GutTest

var _scheduler: GF_Scheduler
var _ticks: int = 0


func before_each() -> void:
	_scheduler = GF_Scheduler.new()
	add_child(_scheduler)
	_ticks = 0


func after_each() -> void:
	_scheduler.queue_free()
	_scheduler = null


func _count(_d: float) -> void:
	_ticks += 1


# ============================================================
# PHYSICS 组隔离
# ============================================================

func test_process_skips_physics_group() -> void:
	_scheduler.register(GF_Scheduler.TickGroup.PHYSICS, "phys", _count)
	_scheduler._process(1.0 / 60.0)
	assert_eq(_ticks, 0, "_process 不应驱动 PHYSICS 组")


func test_process_drives_frame_group() -> void:
	_scheduler.register(GF_Scheduler.TickGroup.FRAME, "frame", _count)
	_scheduler._process(1.0 / 60.0)
	assert_eq(_ticks, 1, "_process 应驱动 FRAME 组")


func test_process_drives_simulation_group() -> void:
	_scheduler.register(GF_Scheduler.TickGroup.SIMULATION, "sim", _count)
	_scheduler._process(1.0 / 60.0)
	assert_eq(_ticks, 1, "_process 应驱动 SIMULATION 组")


func test_physics_group_isolated_in_process() -> void:
	_scheduler.register(GF_Scheduler.TickGroup.PHYSICS, "phys", _count)
	_scheduler.register(GF_Scheduler.TickGroup.FRAME, "frame", _count)
	_scheduler._process(1.0 / 60.0)
	assert_eq(_ticks, 1, "_process 只应驱动 FRAME，PHYSICS 被跳过")


# ============================================================
# 兼容性
# ============================================================

func test_physics_group_respects_pause_group() -> void:
	_scheduler.register(GF_Scheduler.TickGroup.PHYSICS, "phys", _count)
	_scheduler.pause_group(GF_Scheduler.TickGroup.PHYSICS)
	_scheduler._process(1.0 / 60.0)
	assert_eq(_ticks, 0)


func test_physics_unregister_works() -> void:
	var h: GF_Scheduler.TickHandle = _scheduler.register(GF_Scheduler.TickGroup.PHYSICS, "phys", _count)
	h.unregister()
	assert_false(_scheduler.has("phys"))
