## InputService v4.0
## 统一输入服务。内部组合 InputRouter / ActionResolver / InputPolicy / InputRebindService。
## 游戏层只通过此服务查询动作，不接触底层原始事件。
class_name InputService
extends ModuleLifecycle

var _resolver: ActionResolver = null
var _router: InputRouter = null
var _policy: InputPolicy = null
var _gesture: InputGestureEngine = null
var _rebind: InputRebindService = null


func _on_init() -> OperationResult:
	_resolver = ActionResolver.new()
	_policy = InputPolicy.new()
	_gesture = InputGestureEngine.new()
	_rebind = InputRebindService.new()
	_rebind.configure(_resolver)
	_resolver.set_policy(_policy)
	_resolver.set_gesture(_gesture)
	return OperationResult.ok()


func configure(_p_adapter = null) -> OperationResult:
	return OperationResult.ok()


## 注入 UIService（供 InputPolicy 查询面板状态）。
func set_ui_service(p_ui) -> void:
	_policy.set_ui_service(p_ui)


## 创建 InputRouter Node。调用方负责挂到场景树。
func create_router() -> InputRouter:
	if _router == null:
		_router = InputRouter.new()
		_router.configure(_resolver)
	return _router


# ============================================================
# 动作
# ============================================================

func register_action_def(p_def: InputActionDef) -> void:
	p_def.snapshot_default_bindings()
	_resolver.register_action_def(p_def)

func get_action_def(p_action_id: String) -> InputActionDef:
	return _resolver.get_def(p_action_id)

func get_all_action_ids() -> Array[String]:
	return _resolver.get_all_action_ids()


# ============================================================
# 查询
# ============================================================

func read_axis(p_action_id: String) -> float:
	return _resolver.read_axis(p_action_id)

func is_pressed(p_action_id: String) -> bool:
	return _resolver.is_pressed(p_action_id)

func is_just_pressed(p_action_id: String) -> bool:
	return _resolver.is_just_pressed(p_action_id)

func is_just_released(p_action_id: String) -> bool:
	return _resolver.is_just_released(p_action_id)


# ============================================================
# 上下文（透传到 InputPolicy）
# ============================================================

func push_context(p_ctx: InputContext) -> void:
	var stack: Array[InputContext] = _policy.get_context_stack()
	if stack.size() > 0 and stack.back().priority == p_ctx.priority:
		stack.pop_back()
	stack.append(p_ctx)

func pop_context() -> void:
	var stack: Array[InputContext] = _policy.get_context_stack()
	if stack.size() > 0: stack.pop_back()

func clear_contexts() -> void:
	_policy.get_context_stack().clear()


# ============================================================
# Rebind 透传
# ============================================================

func begin_rebind(p_action_id: String, p_slot: int) -> bool:
	return _rebind.begin_rebind(p_action_id, p_slot)

func cancel_rebind() -> void:
	_rebind.cancel_rebind()

func is_waiting_rebind() -> bool:
	return _rebind.is_waiting()

func handle_event_for_rebind(p_event: InputEvent) -> bool:
	return _rebind.handle_event_for_rebind(p_event)

func save_bindings(p_path: String = "user://input_bindings_v1.tres") -> bool:
	return _rebind.save(p_path)

func load_bindings(p_path: String = "user://input_bindings_v1.tres") -> bool:
	return _rebind.load(p_path)

func reset_action_to_default(p_action_id: String) -> bool:
	return _rebind.reset_action_to_default(p_action_id)


# ============================================================
# 向后兼容
# ============================================================

func register_action(p_action_id: String, _p_input_map_action: String) -> void:
	register_action_def(InputActionDef.new(p_action_id))

func register_actions(p_entries: Array) -> void:
	for entry in p_entries:
		if entry is Array:
			register_action(str(entry[0]))

func set_move_keys(p_left: String, p_right: String, p_up: String, p_down: String) -> void:
	pass  # v4.0: move keys are registered as regular actions

func get_move_vector() -> Vector2:
	var x: float = read_axis("move_right") - read_axis("move_left")
	var y: float = read_axis("move_down") - read_axis("move_up")
	return Vector2(x, y)

func mouse_position() -> Vector2:
	return DisplayServer.mouse_get_position()

func set_game_input_blocker(_p: Callable) -> void: pass
func set_game_input_enabled(p_enabled: bool) -> void:
	if _router != null: _router.set_enabled(p_enabled)
