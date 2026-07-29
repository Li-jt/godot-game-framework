# tests/unit/input/test_input_recording.gd
## 输入录制/回放单元测试。
extends GutTest

var _service: GF_InputService


func before_each() -> void:
	_service = GF_InputService.new()
	_service._on_init()
	_service.register_action("jump")
	_service.register_action("move_right")


func after_each() -> void:
	_service._on_dispose()
	_service = null


# ============================================================
# 录制状态
# ============================================================

func test_not_recording_by_default() -> void:
	assert_false(_service.is_recording())


func test_start_recording_sets_flag() -> void:
	_service.start_recording()
	assert_true(_service.is_recording())


func test_stop_recording_clears_flag() -> void:
	_service.start_recording()
	_service.stop_recording()
	assert_false(_service.is_recording())


func test_stop_recording_returns_dict() -> void:
	_service.start_recording()
	var data := _service.stop_recording()
	assert_not_null(data)
	assert_true(data.has("frames"))


# ============================================================
# 录制/回放往返
# ============================================================

func test_record_and_replay_preserves_action_value() -> void:
	# 用键盘事件注入一个叫 "jump" 的按下
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true

	_service.register_action_def(
		GF_InputActionDef.new("jump").bind_key(KEY_SPACE, 1.0, GF_InputBinding.Mode.IMPULSE)
	)

	# 开始录制
	_service.start_recording()

	# feed 事件
	var router := _service.get_or_create_router()
	add_child(router)
	router._input(event)

	# 手动调用一帧结算
	_service._resolver.begin_frame()
	_service._resolver.end_frame(0.016)

	# 记录按下的值
	assert_true(_service.is_just_pressed("jump"), "录制期间应正常响应输入")

	# 停止录制
	var data := _service.stop_recording()
	assert_false(data.frames.is_empty(), "录制不应为空")

	_service._resolver.begin_frame()
	_service._resolver.end_frame(0.016)

	# 回放
	_service.replay(data)
	_service._resolver.begin_frame()
	_service._resolver.end_frame(0.016)

	assert_true(_service.is_just_pressed("jump"), "回放应重现同样的按键")

	_service.stop_replay()
	router.queue_free()


func test_save_and_load_recording() -> void:
	_service.start_recording()
	var data := _service.stop_recording()

	var path := "user://test_recording.json"
	_service.save_recording(path)

	assert_true(FileAccess.file_exists(path), "文件应存在")

	var ok := _service.load_and_replay(path)
	assert_true(ok, "load_and_replay 应成功")

	_service.stop_replay()


func test_load_nonexistent_file_returns_false() -> void:
	var ok := _service.load_and_replay("user://nonexistent_file.json")
	assert_false(ok)


# ============================================================
# 边界条件
# ============================================================

func test_stop_replay_on_idle_does_not_crash() -> void:
	_service.stop_replay()
	pass  # 不崩溃就是通过


func test_empty_recording_replay_does_not_crash() -> void:
	_service.start_recording()
	var data := _service.stop_recording()
	_service.replay(data)
	_service._resolver.begin_frame()
	_service._resolver.end_frame(0.016)
	pass  # 不崩溃就是通过


func test_is_replaying_returns_true_during_replay() -> void:
	_service.start_recording()
	var data := _service.stop_recording()
	_service.replay(data)

	assert_true(_service.is_replaying())

	_service.stop_replay()
	assert_false(_service.is_replaying())


func test_double_start_recording_clears_previous() -> void:
	_service.start_recording()
	var data1 := _service.stop_recording()

	_service.start_recording()
	var data2 := _service.stop_recording()

	assert_eq(data1.frames.size(), 0)
	assert_eq(data2.frames.size(), 0)
