## InputRebindService — 按键重绑定服务（v4.0）。
## 管理"监听新按键"流程 + 校验 + 应用 + 冲突处理。
class_name InputRebindService
extends RefCounted

enum ConflictPolicy { ALLOW, WARN, REPLACE }

var _resolver: ActionResolver = null
var _waiting: bool = false
var _target_action_id: String = ""
var _target_slot: int = 0
var _conflict_policy: int = ConflictPolicy.WARN

signal rebind_changed(action_id: String, slot: int)


func configure(p_resolver: ActionResolver) -> void:
	_resolver = p_resolver


func begin_rebind(p_action_id: String, p_slot: int) -> bool:
	var def: InputActionDef = _resolver.get_def(p_action_id)
	if def == null or not def.rebindable:
		return false
	_waiting = true
	_target_action_id = p_action_id
	_target_slot = p_slot
	return true


func cancel_rebind() -> void:
	_waiting = false


func is_waiting() -> bool:
	return _waiting


## 在 InputRouter._input 中调用，检查是否是改键等待中的按键事件。
func handle_event_for_rebind(p_event: InputEvent) -> bool:
	if not _waiting or _resolver == null:
		return false
	var def: InputActionDef = _resolver.get_def(_target_action_id)
	if def == null:
		return false

	# 过滤非按键事件
	if not (p_event is InputEventKey or p_event is InputEventMouseButton or p_event is InputEventJoypadButton):
		return false

	# 鼠标移动忽略
	if p_event is InputEventMouseButton:
		var mb := p_event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return false  # 滚轮暂不作为重绑定目标

	if not can_bind_event_to_action(p_event, def):
		return false

	# 从事件创建 binding
	var source := _event_to_source(p_event)
	var code := _event_to_code(p_event)
	var mode := InputBinding.Mode.IMPULSE
	if source == InputBinding.Source.KEYBOARD:
		mode = InputBinding.Mode.HELD
	var binding := InputBinding.new(source, code, 1.0, mode, false, _target_slot)

	# 应用
	apply_binding(_target_action_id, _target_slot, binding)
	_waiting = false
	rebind_changed.emit(_target_action_id, _target_slot)
	return true


func can_bind_event_to_action(p_event: InputEvent, p_def: InputActionDef) -> bool:
	var source := _event_to_source(p_event)
	match p_def.device_constraint:
		InputActionDef.DeviceConstraint.KEYBOARD_ONLY:
			return source == InputBinding.Source.KEYBOARD
		InputActionDef.DeviceConstraint.MOUSE_ONLY:
			return source in [InputBinding.Source.MOUSE_BUTTON, InputBinding.Source.MOUSE_WHEEL]
		InputActionDef.DeviceConstraint.KEYBOARD_MOUSE:
			return source in [InputBinding.Source.KEYBOARD, InputBinding.Source.MOUSE_BUTTON, InputBinding.Source.MOUSE_WHEEL]
		InputActionDef.DeviceConstraint.GAMEPAD_ONLY:
			return source in [InputBinding.Source.GAMEPAD_BUTTON, InputBinding.Source.GAMEPAD_AXIS]
	return true


func apply_binding(p_action_id: String, p_slot: int, p_binding: InputBinding) -> bool:
	var def := _resolver.get_def(p_action_id)
	if def == null: return false
	# 移除同 slot 的旧绑定
	var i := 0
	while i < def.bindings.size():
		if def.bindings[i].slot == p_slot:
			def.bindings.remove_at(i)
		else:
			i += 1
	def.bindings.append(p_binding)
	return true


func reset_action_to_default(p_action_id: String) -> bool:
	var def := _resolver.get_def(p_action_id)
	if def == null: return false
	def.bindings.clear()
	for b in def.default_bindings:
		def.bindings.append(b.duplicate_binding())
	rebind_changed.emit(p_action_id, -1)
	return true


func save(p_path: String = "user://input_bindings_v1.tres") -> bool:
	var config := InputBindingConfig.from_defs(_resolver._defs)
	return config.save_to_file(p_path)


func load(p_path: String = "user://input_bindings_v1.tres") -> bool:
	var config := InputBindingConfig.load_from_file(p_path)
	if config == null: return false
	config.apply_to_defs(_resolver._defs)
	return true


# ============================================================
# 内部
# ============================================================

func _event_to_source(p_event: InputEvent) -> int:
	if p_event is InputEventKey: return InputBinding.Source.KEYBOARD
	if p_event is InputEventMouseButton:
		var mb := p_event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return InputBinding.Source.MOUSE_WHEEL
		return InputBinding.Source.MOUSE_BUTTON
	if p_event is InputEventJoypadButton: return InputBinding.Source.GAMEPAD_BUTTON
	return -1

func _event_to_code(p_event: InputEvent) -> int:
	if p_event is InputEventKey: return (p_event as InputEventKey).keycode
	if p_event is InputEventMouseButton: return (p_event as InputEventMouseButton).button_index
	if p_event is InputEventJoypadButton: return (p_event as InputEventJoypadButton).button_index
	return 0
