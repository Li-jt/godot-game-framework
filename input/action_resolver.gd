## ActionResolver — 动作解析器（v3.0）。
## 维护所有注册动作的状态，匹配原始事件到绑定，更新状态。
class_name ActionResolver
extends RefCounted

## { action_id → InputActionState }
var _states: Dictionary = {}
## { action_id → InputActionDef }
var _defs: Dictionary = {}


## 注册一个动作定义。已注册的同 ID 会被覆盖。
func register(p_def: InputActionDef) -> void:
	_defs[p_def.action_id] = p_def
	_states[p_def.action_id] = InputActionState.new(p_def)


## 获取动作状态。未注册时返回 null。
func get_state(p_action_id: String) -> InputActionState:
	return _states.get(p_action_id, null)


## 获取动作定义。未注册时返回 null。
func get_def(p_action_id: String) -> InputActionDef:
	return _defs.get(p_action_id, null)


## 处理单个原始事件。遍历所有动作的所有绑定，匹配则更新状态。
func process_event(p_event: InputEvent) -> void:
	for state in _states.values():
		var def: InputActionDef = state._def
		for binding in def.bindings:
			if binding.matches(p_event):
				state.apply_event(p_event, binding)


## 每帧结束时调用。对每个动作调用 end_frame 合成最终值。
func end_frame(p_delta: float) -> void:
	for state in _states.values():
		state.end_frame(p_delta)


## 已注册的动作数量。
func action_count() -> int:
	return _states.size()
