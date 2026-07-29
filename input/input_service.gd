## GF_InputService v4.0
## 统一输入服务。内部组合 GF_InputRouter / GF_ActionResolver / GF_InputPolicy / GF_InputRebindService。
## 游戏层只通过此服务查询动作，不接触底层原始事件。
class_name GF_InputService
extends GF_ModuleLifecycle

var _resolver: GF_ActionResolver = null
var _router: GF_InputRouter = null
var _policy: GF_InputPolicy = null
var _gesture: GF_InputGestureEngine = null
var _rebind: GF_InputRebindService = null


func _on_init() -> GF_OperationResult:
	_resolver = GF_ActionResolver.new()
	_policy = GF_InputPolicy.new()
	_gesture = GF_InputGestureEngine.new()
	_rebind = GF_InputRebindService.new()
	_rebind.configure(_resolver)
	_resolver.set_policy(_policy)
	_resolver.set_gesture(_gesture)
	return GF_OperationResult.ok()


func configure(_p_adapter = null) -> GF_OperationResult:
	return GF_OperationResult.ok()


func _on_dispose() -> GF_OperationResult:
	destroy_router()
	return GF_OperationResult.ok()


## 注入 GF_UIService（供 GF_InputPolicy 查询面板状态）。
func set_ui_service(p_ui) -> void:
	_policy.set_ui_service(p_ui)


## 获取或创建 GF_InputRouter Node（懒汉单例）。
## 调用方负责挂到场景树。销毁用 destroy_router()。
func get_or_create_router() -> GF_InputRouter:
	if _router == null:
		_router = GF_InputRouter.new()
		_router.configure(_resolver)
	return _router


## 销毁 GF_InputRouter，从场景树移除并释放。
func destroy_router() -> void:
	if _router != null:
		_router.set_enabled(false)
		if _router.is_inside_tree():
			_router.queue_free()
		_router = null


# ============================================================
# 动作
# ============================================================

func register_action_def(p_def: GF_InputActionDef) -> void:
	p_def.snapshot_default_bindings()
	_resolver.register_action_def(p_def)

func get_action_def(p_action_id: String) -> GF_InputActionDef:
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
# 上下文（透传到 GF_InputPolicy）
# ============================================================

func push_context(p_ctx: GF_InputContext) -> void:
	var stack: Array[GF_InputContext] = _policy.get_context_stack()
	if stack.size() > 0 and stack.back().priority == p_ctx.priority:
		stack.pop_back()
	stack.append(p_ctx)

func pop_context() -> void:
	var stack: Array[GF_InputContext] = _policy.get_context_stack()
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

func register_action(p_action_id: String, _p_input_map_action: String = "") -> void:
	register_action_def(GF_InputActionDef.new(p_action_id))

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


# ============================================================
# 录制/回放
# ============================================================

## 开始录制输入。
func start_recording() -> void:
	_resolver.start_recording()

## 停止录制，返回录制数据 Dictionary。
func stop_recording() -> Dictionary:
	return _resolver.stop_recording()

## 是否正在录制。
func is_recording() -> bool:
	return _resolver.is_recording()

## 从录制数据回放。回放期间真实输入被忽略。
func replay(p_data: Dictionary) -> void:
	_resolver.load_recording(p_data)

## 停止回放。
func stop_replay() -> void:
	_resolver.stop_replay()

## 是否正在回放。
func is_replaying() -> bool:
	return _resolver.is_replaying()

## 停止录制并保存到文件。
func save_recording(p_path: String) -> void:
	var data: Dictionary = _resolver.stop_recording()
	var file: FileAccess = FileAccess.open(p_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

## 从文件加载录制数据并开始回放。返回 false 表示文件不存在或格式错误。
func load_and_replay(p_path: String) -> bool:
	if not FileAccess.file_exists(p_path):
		return false
	var file: FileAccess = FileAccess.open(p_path, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null:
		return false
	_resolver.load_recording(data)
	return true
