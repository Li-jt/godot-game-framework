## ActionResolver — 动作解析器（v4.0 重写）。
## 核心：接收 RawSignal，匹配 binding，应用 policy，写入 ActionState，合成输出。
class_name ActionResolver
extends RefCounted

var _defs: Dictionary = {}
var _states: Dictionary = {}
var _normalizer: DeviceNormalizer = null
var _gesture: InputGestureEngine = null
var _policy: InputPolicy = null
var _pending_impulses: Array[Dictionary] = []
var _now_msec_provider: Callable = Callable()


func _init() -> void:
	_normalizer = DeviceNormalizer.new()


## 注入策略层。
func set_policy(p_policy: InputPolicy) -> void:
	_policy = p_policy


## 注入手势引擎。
func set_gesture(p_gesture: InputGestureEngine) -> void:
	_gesture = p_gesture


## 设置时间戳源（默认用 Time.get_ticks_msec）。
func set_clock(p_provider: Callable) -> void:
	_now_msec_provider = p_provider


# ============================================================
# 注册
# ============================================================

func register_action_def(p_def: InputActionDef) -> void:
	_defs[p_def.action_id] = p_def
	_states[p_def.action_id] = InputActionState.new()

func unregister_action(p_action_id: String) -> void:
	_defs.erase(p_action_id); _states.erase(p_action_id)

func get_def(p_action_id: String) -> InputActionDef:
	return _defs.get(p_action_id, null)

func get_state(p_action_id: String) -> InputActionState:
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


func feed_event(p_event: InputEvent) -> void:
	var raw_sigs: Array[InputRawSignal] = _normalizer.normalize(p_event)
	var pointer_pos: Vector2 = _normalizer.extract_pointer_position(p_event)
	var now: int = _get_now()

	for sig in raw_sigs:
		sig.timestamp_msec = now

		# 找所有匹配 binding 的 action
		for action_id in _defs.keys():
			var def: InputActionDef = _defs[action_id]
			var matched := false
			for binding in def.bindings:
				if binding.matches_signal(sig):
					matched = true
					break
			if not matched:
				continue

			# policy 检查
			if _policy != null and _policy.is_action_blocked(action_id, p_event, pointer_pos):
				continue

			var state: InputActionState = _states[action_id]
			if state == null:
				continue

			# 按 mode 写入 state
			for binding in def.bindings:
				if not binding.matches_signal(sig):
					continue
				match binding.mode:
					InputBinding.Mode.IMPULSE:
						if sig.is_press:
							state.accumulate_impulse(binding.scale)
					InputBinding.Mode.HELD:
						pass  # poll_held 阶段处理
					InputBinding.Mode.ANALOG:
						state.accumulate_analog(sig.analog_value * binding.scale)

			# 手势候选
			if _gesture != null and def.gesture_profile != null and def.gesture_profile.enable_click_gesture:
				if sig.is_press and sig.source == InputBinding.Source.MOUSE_BUTTON:
					var gesture_results: Array[Dictionary] = _gesture.on_click_candidate(def, sig, 0)
					for gr in gesture_results:
						_pending_impulses.append(gr)


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
		var state: InputActionState = _states.get(aid, null)
		if state != null:
			state.accumulate_impulse(val)

	# 所有 state finalize
	for action_id in _defs.keys():
		var def: InputActionDef = _defs[action_id]
		var state: InputActionState = _states[action_id]
		state.finalize(def, p_delta)

	_pending_impulses.clear()


# ============================================================
# 查询
# ============================================================

func read_axis(p_action_id: String) -> float:
	var state: InputActionState = _states.get(p_action_id, null) as InputActionState
	return state.smoothed_value if state != null else 0.0

func is_pressed(p_action_id: String) -> bool:
	var state: InputActionState = _states.get(p_action_id, null) as InputActionState
	return state.pressed if state != null else false

func is_just_pressed(p_action_id: String) -> bool:
	var state: InputActionState = _states.get(p_action_id, null) as InputActionState
	return state.just_pressed if state != null else false

func is_just_released(p_action_id: String) -> bool:
	var state: InputActionState = _states.get(p_action_id, null) as InputActionState
	return state.just_released if state != null else false


# ============================================================
# 注入
# ============================================================

func enqueue_impulse(p_action_id: String, p_value: float) -> void:
	_pending_impulses.append({"action_id": p_action_id, "value": p_value})


# ============================================================
# 内部
# ============================================================

func _poll_held_bindings() -> void:
	for action_id in _defs.keys():
		var def: InputActionDef = _defs[action_id]
		var state: InputActionState = _states[action_id]
		var held: float = 0.0
		for binding in def.bindings:
			if binding.mode != InputBinding.Mode.HELD: continue
			if binding.is_down():
				held += binding.scale
		state.accumulate_held(held)

func _get_now() -> int:
	if _now_msec_provider.is_valid():
		return _now_msec_provider.call()
	return Time.get_ticks_msec()
