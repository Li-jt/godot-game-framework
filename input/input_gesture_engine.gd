## InputGestureEngine — 手势引擎（v4.0）。
## 处理单击/双击手势，不负责拖拽（拖拽由 HELD 模式处理）。
class_name InputGestureEngine
extends RefCounted

class ClickTrack:
	var first_time: int = 0
	var first_pos: Vector2 = Vector2.ZERO
	var first_target: int = 0
	var action_def: InputActionDef = null
	var pointer_id: int = 0

var _tracks: Dictionary = {}  # key → ClickTrack


## 处理一个点击候选。返回可能触发的动作列表 [{action_id, value}]。
func on_click_candidate(p_def: InputActionDef, p_signal: InputRawSignal, p_target: int = 0) -> Array[Dictionary]:
	var profile: InputGestureProfile = p_def.gesture_profile
	if profile == null or not profile.enable_click_gesture:
		return []

	var key := _make_key(p_def.action_id, p_signal.code, 0)
	var track: ClickTrack = _tracks.get(key, null)
	var now := p_signal.timestamp_msec

	if track == null:
		# 第一次点击：记录，不立即触发
		track = ClickTrack.new()
		track.first_time = now
		track.first_pos = p_signal.pointer_pos
		track.first_target = p_target
		track.action_def = p_def
		track.pointer_id = 0
		_tracks[key] = track
		return []

	# 第二次点击：窗口内？
	if now - track.first_time <= profile.double_click_window_ms:
		# 目标校验
		if profile.require_same_target and track.first_target != p_target:
			# 不同目标，视为新的第一次点击
			track.first_time = now
			track.first_target = p_target
			track.first_pos = p_signal.pointer_pos
			return []

		# 双击！
		_tracks.erase(key)
		return [{"action_id": profile.double_action_id, "value": 1.0}]

	# 窗口外：触发上一次的单击，记录新点击
	_tracks.erase(key)
	var result: Array[Dictionary] = [{"action_id": profile.single_action_id, "value": 1.0}]
	track = ClickTrack.new()
	track.first_time = now
	track.first_pos = p_signal.pointer_pos
	track.first_target = p_target
	track.action_def = p_def
	_tracks[key] = track
	return result


## 指针移动时检查是否超出拖拽阈值，超出则取消等待。
func on_pointer_motion(p_pointer_id: int, p_pos: Vector2) -> void:
	var to_erase: Array[String] = []
	for key in _tracks.keys():
		var track: ClickTrack = _tracks[key]
		if track.pointer_id == p_pointer_id:
			var profile: InputGestureProfile = track.action_def.gesture_profile
			if profile != null and track.first_pos.distance_to(p_pos) > profile.drag_cancel_px:
				to_erase.append(key)
	for key in to_erase:
		_tracks.erase(key)


## 每帧检查超时。返回超时后应触发的单击动作列表。
func tick_timeout(p_now_msec: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var to_erase: Array[String] = []
	for key in _tracks.keys():
		var track: ClickTrack = _tracks[key]
		var profile: InputGestureProfile = track.action_def.gesture_profile
		if profile == null: continue
		if p_now_msec - track.first_time > profile.double_click_window_ms:
			to_erase.append(key)
			result.append({"action_id": profile.single_action_id, "value": 1.0})
	for key in to_erase:
		_tracks.erase(key)
	return result


func reset_all() -> void:
	_tracks.clear()


func _make_key(p_action_id: String, p_code: int, p_pointer_id: int) -> String:
	return "%s|%d|%d" % [p_action_id, p_code, p_pointer_id]
