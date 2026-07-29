# tests/unit/input/test_input_recording.gd
## 输入录制/回放单元测试。
extends GutTest

var _service: GF_InputService


func before_each() -> void:
	_service = GF_InputService.new()
	_service._on_init()
	_service.register_action("jump")


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


func test_double_start_does_not_clear_data() -> void:
	_service.restart_recording()
	_service._resolver._record_frame_signals([GF_InputRawSignal.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE, true)])
	_service.start_recording()
	var data: Dictionary = _service.stop_recording()
	assert_eq(data.frames.size(), 1, "再次 start 不应清空已有录制")


func test_restart_recording_clears_data() -> void:
	_service.restart_recording()
	_service._resolver._record_frame_signals([GF_InputRawSignal.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE, true)])
	_service.restart_recording()
	var data: Dictionary = _service.stop_recording()
	assert_eq(data.frames.size(), 0, "restart 应清空已有录制")


func test_stop_recording_clears_flag() -> void:
	_service.start_recording()
	_service.stop_recording()
	assert_false(_service.is_recording())


func test_stop_recording_returns_dict() -> void:
	_service.restart_recording()
	var data: Dictionary = _service.stop_recording()
	assert_not_null(data)
	assert_true(data.has("frames"))


func test_snapshot_does_not_stop_recording() -> void:
	_service.restart_recording()
	_service.snapshot_recording()
	assert_true(_service.is_recording(), "snapshot 不应停止录制")


# ============================================================
# 录制/回放往返
# ============================================================

func test_record_and_replay_roundtrip() -> void:
	_service.register_action_def(
		GF_InputActionDef.new("jump").bind_key(KEY_SPACE, 1.0, GF_InputBinding.Mode.IMPULSE)
	)
	_service.restart_recording()
	_service._resolver._record_frame_signals([
		GF_InputRawSignal.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE, true)
	])
	var data: Dictionary = _service.stop_recording()
	assert_eq(data.frames.size(), 1)

	_service.replay(data)
	_service._resolver.begin_frame()
	_service._resolver.end_frame(0.016)
	assert_true(_service.is_just_pressed("jump"), "回放应重现录制的按键")
	_service.stop_replay()


func test_save_and_load_recording() -> void:
	_service.restart_recording()
	_service._resolver._record_frame_signals([GF_InputRawSignal.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE, true)])

	var path: String = "user://test_recording.json"
	var ok: bool = _service.save_recording(path)
	assert_true(ok, "save_recording 应成功")

	var loaded: bool = _service.load_and_replay(path)
	assert_true(loaded, "load_and_replay 应成功")
	_service.stop_replay()


func test_save_empty_recording_returns_false() -> void:
	_service.start_recording()
	var ok: bool = _service.save_recording("user://empty.json")
	assert_false(ok, "空录制不应保存")


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
	_service.restart_recording()
	var data: Dictionary = _service.stop_recording()
	_service.replay(data)
	_service._resolver.begin_frame()
	_service._resolver.end_frame(0.016)
	pass


func test_is_replaying_during_replay() -> void:
	_service.restart_recording()
	var data: Dictionary = _service.stop_recording()
	_service.replay(data)
	assert_true(_service.is_replaying())
	_service.stop_replay()
	assert_false(_service.is_replaying())
