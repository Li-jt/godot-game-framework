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
	var data: Dictionary = _service.stop_recording()
	assert_not_null(data)
	assert_true(data.has("frames"))


# ============================================================
# 录制/回放往返
# ============================================================

func test_record_captures_frame_data() -> void:
	_service.register_action_def(
		GF_InputActionDef.new("jump").bind_key(KEY_SPACE, 1.0, GF_InputBinding.Mode.IMPULSE)
	)
	_service.start_recording()

	# 录制 raw signal dict 以模拟一次按键
	_service._resolver._record_frame_signals([
		GF_InputRawSignal.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE, true)
	])

	var data: Dictionary = _service.stop_recording()
	assert_eq(data.frames.size(), 1, "应录制到 1 帧")


func test_replay_applies_recorded_signals() -> void:
	_service.register_action_def(
		GF_InputActionDef.new("jump").bind_key(KEY_SPACE, 1.0, GF_InputBinding.Mode.IMPULSE)
	)
	_service.start_recording()
	_service._resolver._record_frame_signals([
		GF_InputRawSignal.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE, true)
	])
	var data: Dictionary = _service.stop_recording()

	_service.replay(data)
	_service._resolver.begin_frame()
	_service._resolver.end_frame(0.016)

	assert_true(_service.is_just_pressed("jump"), "回放应重现录制的按键")


func test_save_and_load_recording() -> void:
	_service.start_recording()
	var data: Dictionary = _service.stop_recording()

	var path: String = "user://test_recording.json"
	_service.save_recording(path)

	assert_true(FileAccess.file_exists(path), "文件应存在")

	var ok: bool = _service.load_and_replay(path)
	assert_true(ok, "load_and_replay 应成功")
	_service.stop_replay()


func test_load_nonexistent_file_returns_false() -> void:
	var ok: bool = _service.load_and_replay("user://nonexistent_file.json")
	assert_false(ok)


# ============================================================
# 边界条件
# ============================================================

func test_stop_replay_on_idle_does_not_crash() -> void:
	_service.stop_replay()
	pass


func test_empty_recording_replay_does_not_crash() -> void:
	_service.start_recording()
	var data: Dictionary = _service.stop_recording()
	_service.replay(data)
	_service._resolver.begin_frame()
	_service._resolver.end_frame(0.016)
	pass


func test_is_replaying_during_replay() -> void:
	_service.start_recording()
	var data: Dictionary = _service.stop_recording()
	_service.replay(data)
	assert_true(_service.is_replaying())
	_service.stop_replay()
	assert_false(_service.is_replaying())


func test_double_start_recording_clears_previous() -> void:
	_service.start_recording()
	var data1: Dictionary = _service.stop_recording()
	_service.start_recording()
	var data2: Dictionary = _service.stop_recording()
	assert_eq(data1.frames.size(), 0)
	assert_eq(data2.frames.size(), 0)
