## GF_ActionResolver — 动作解析器（v4.0）。
## 核心：接收 RawSignal，匹配 binding，应用 policy，写入 ActionState，合成输出。
## 支持录制/回放：录制归一化后的信号，回放时注入替代真实事件。
class_name GF_ActionResolver
extends RefCounted

var _defs: Dictionary = {}
var _states: Dictionary = {}
var _normalizer: GF_DeviceNormalizer = null
var _gesture: GF_InputGestureEngine = null
var _policy: GF_InputPolicy = null
var _pending_impulses: Array[Dictionary] = []
var _now_msec_provider: Callable = Callable()

# 录制/回放
var _is_recording: bool = false
var _recorded_frames: Array[Dictionary] = []
var _is_replaying: bool = false
var _replay_frames: Array = []
var _replay_index: int = 0


func _init() -> void:
	_normalizer = GF_DeviceNormalizer.new()


## 注入策略层。
func set_policy(p_policy: GF_InputPolicy) -> void:
	_policy = p_policy


## 注入手势引擎。
func set_gesture(p_gesture: GF_InputGestureEngine) -> void:
	_gesture = p_gesture


## 设置时间戳源（默认用 Time.get_ticks_msec）。
func set_clock(p_provider: Callable) -> void:
	_now_msec_provider = p_provider


# ============================================================
# 注册
# ============================================================

func register_action_def(p_def: GF_InputActionDef) -> void:
	_defs[p_def.action_id] = p_def
	_states[p_def.action_id] = GF_InputActionState.new()

func unregister_action(p_action_id: String) -> void:
	_defs.erase(p_action_id); _states.erase(p_action_id)

func get_def(p_action_id: String) -> GF_InputActionDef:
	return _defs.get(p_action_id, null)

func get_state(p_action_id: String) -> GF_InputActionState:
	return _states.get(p_action_id, null)

func get_all_action_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _defs.keys(): ids.append(str(id))
	return ids


# ============================================================
# 每帧生命周期
# ============================================================

func begin_frame() -> void:
	for state in _states.values():
		state.begin_frame()
	_pending_impulses.clear()

	# 回放模式：注入录制的信号
	if _is_replaying and _replay_index < _replay_frames.size():
		var frame_data: Dictionary = _replay_frames[_replay_index] as Dictionary
		_replay_index += 1
		for sig_dict in frame_data.get("signals", []):
			var sig := GF_InputRawSignal.new(
				sig_dict["source"], sig_dict["code"], sig_dict.get("is_press", false),
				sig_dict.get("analog", 0.0), sig_dict.get("pointer_pos", Vector2.INF),
				sig_dict.get("device", -1))
			sig.timestamp_msec = _get_now()
			_process_raw_signal(sig, Vector2.INF)


func feed_event(p_event: InputEvent) -> void:
	if _is_replaying:
		return  # 回放模式下忽略真实事件

	var raw_sigs: Array[GF_InputRawSignal] = _normalizer.normalize(p_event)
	var pointer_pos: Vector2 = _normalizer.extract_pointer_position(p_event)
	var now: int = _get_now()

	if _is_recording:
		_record_frame_signals(raw_sigs)

	for sig in raw_sigs:
		sig.timestamp_msec = now
		_process_raw_signal(sig, pointer_pos)


func end_frame(p_delta: float) -> void:
	_poll_held_bindings()

	# 手势超时检查
	if _gesture != null:
		var gesture_outputs: Array[Dictionary] = _gesture.tick_timeout(_get_now())
		for go in gesture_outputs:
			_pending_impulses.append(go)

	# 注入待处理的脉冲（手势产生）
	for pi in _pending_impulses:
		var aid: String = pi.get("action_id", "")
		var val: float = pi.get("value", 0.0)
		var state: GF_InputActionState = _states.get(aid, null)
		if state != null:
			state.accumulate_impulse(val)

	# 所有 state finalize
	for action_id in _defs.keys():
		var def: GF_InputActionDef = _defs[action_id]
		var state: GF_InputActionState = _states[action_id]
		state.finalize(def, p_delta)

	_pending_impulses.clear()


# ============================================================
# 录制/回放
# ============================================================

## 开始录制。如果已在录制中则不做任何事（防止误触丢失数据）。
## 如需强制重录，使用 restart_recording()。
func start_recording() -> void:
	if _is_recording:
		return
	_is_recording = true
	_recorded_frames.clear()


## 强制重新开始录制（清除已有数据）。
func restart_recording() -> void:
	_is_recording = true
	_recorded_frames.clear()


## 停止录制，返回录制数据 Dictionary。
func stop_recording() -> Dictionary:
	_is_recording = false
	return {"frames": _recorded_frames.duplicate(true)}


## 获取当前录制数据的快照，不停止录制。
func snapshot_recording() -> Dictionary:
	return {"frames": _recorded_frames.duplicate(true)}


## 是否正在录制。
func is_recording() -> bool:
	return _is_recording


## 加载录制数据并开始回放。
func load_recording(p_data: Dictionary) -> void:
	_replay_frames = p_data.get("frames", [])
	_replay_index = 0
	_is_replaying = true


## 停止回放。
func stop_replay() -> void:
	_is_replaying = false
	_replay_frames.clear()
	_replay_index = 0


## 是否正在回放。
func is_replaying() -> bool:
	return _is_replaying


func _record_frame_signals(p_signals: Array[GF_InputRawSignal]) -> void:
	var signal_dicts: Array[Dictionary] = []
	for sig in p_signals:
		signal_dicts.append({
			"source": sig.source, "code": sig.code,
			"is_press": sig.is_press, "analog": sig.analog_value,
			"pointer_pos": sig.pointer_pos, "device": sig.device_id,
		})
	if not signal_dicts.is_empty():
		_recorded_frames.append({"signals": signal_dicts})


# ============================================================
# 查询
# ============================================================

func read_axis(p_action_id: String) -> float:
	var state: GF_InputActionState = _states.get(p_action_id, null) as GF_InputActionState
	return state.smoothed_value if state != null else 0.0

func is_pressed(p_action_id: String) -> bool:
	var state: GF_InputActionState = _states.get(p_action_id, null) as GF_InputActionState
	return state.pressed if state != null else false

func is_just_pressed(p_action_id: String) -> bool:
	var state: GF_InputActionState = _states.get(p_action_id, null) as GF_InputActionState
	return state.just_pressed if state != null else false

func is_just_released(p_action_id: String) -> bool:
	var state: GF_InputActionState = _states.get(p_action_id, null) as GF_InputActionState
	return state.just_released if state != null else false


# ============================================================
# 注入
# ============================================================

func enqueue_impulse(p_action_id: String, p_value: float) -> void:
	_pending_impulses.append({"action_id": p_action_id, "value": p_value})


# ============================================================
# 内部
# ============================================================

func _process_raw_signal(p_sig: GF_InputRawSignal, p_pointer_pos: Vector2) -> void:
	for action_id in _defs.keys():
		var def: GF_InputActionDef = _defs[action_id]
		var matched := false
		for binding in def.bindings:
			if binding.matches_signal(p_sig):
				matched = true
				break
		if not matched:
			continue

		# policy 检查
		if _policy != null and _policy.is_action_blocked_raw(action_id, p_sig.is_spatial(), p_pointer_pos):
			continue

		var state: GF_InputActionState = _states[action_id]
		if state == null:
			continue

		for binding in def.bindings:
			if not binding.matches_signal(p_sig):
				continue
			match binding.mode:
				GF_InputBinding.Mode.IMPULSE:
					if p_sig.is_press:
						state.accumulate_impulse(binding.scale)
				GF_InputBinding.Mode.HELD:
					pass
				GF_InputBinding.Mode.ANALOG:
					state.accumulate_analog(p_sig.analog_value * binding.scale)

		# 手势候选
		if _gesture != null and def.gesture_profile != null and def.gesture_profile.enable_click_gesture:
			if p_sig.is_press and p_sig.source == GF_InputBinding.Source.MOUSE_BUTTON:
				var gesture_results: Array[Dictionary] = _gesture.on_click_candidate(def, p_sig, 0)
				for gr in gesture_results:
					_pending_impulses.append(gr)


func _poll_held_bindings() -> void:
	if _is_replaying:
		return  # 回放不 poll

	var mouse_pos := DisplayServer.mouse_get_position()
	for action_id in _defs.keys():
		var def: GF_InputActionDef = _defs[action_id]
		var state: GF_InputActionState = _states[action_id]
		var held: float = 0.0
		for binding in def.bindings:
			if binding.mode != GF_InputBinding.Mode.HELD: continue
			# 所有 HELD binding 都检查 policy（键盘/手柄/鼠标）
			var is_spatial := binding.source in [GF_InputBinding.Source.MOUSE_BUTTON, GF_InputBinding.Source.TOUCH_PAN]
			if _policy != null and _policy.is_action_blocked_raw(action_id, is_spatial, mouse_pos):
				continue
			if binding.is_down():
				held += binding.scale
		state.accumulate_held(held)

func _get_now() -> int:
	if _now_msec_provider.is_valid():
		return _now_msec_provider.call()
	return Time.get_ticks_msec()
