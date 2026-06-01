## InputService v3.0
## 统一输入服务。提供动作注册、轴/二进制读取和上下文管理。
## 底层由 InputProvider（Node）收集原始事件，ActionResolver 解析，InputActionState 合成。
##
## 变更（v3.0）：
##   - 不再依赖 InputAdapter
##   - 新增 InputProvider（_unhandled_input 统一事件源）+ ActionResolver + InputActionState
##   - InputActionDef 支持设备绑定链式配置 + ComposeMode
##   - 鼠标滚轮通过 _unhandled_input 原生支持，UI 冲突由 Godot 引擎自动隔离
class_name InputService
extends ModuleLifecycle

var _resolver: ActionResolver = null
var _provider: InputProvider = null
var _context_stack: Array[InputContext] = []
var _move_left: String = ""; var _move_right: String = ""
var _move_up: String = ""; var _move_down: String = ""
var _game_input_blocker: Callable = Callable()


func _on_init() -> OperationResult:
	_resolver = ActionResolver.new()
	return OperationResult.ok()


## configure 不再需要 InputAdapter。保留参数兼容性。
func configure(_p_adapter = null) -> OperationResult:
	return OperationResult.ok()


## 创建并返回 InputProvider Node。调用方负责挂到场景树。
func create_provider() -> InputProvider:
	if _provider == null:
		_provider = InputProvider.new()
		_provider.configure(_resolver)
	return _provider


# ============================================================
# 动作注册
# ============================================================

## 注册动作定义（v3.0 主入口）。
func register_action_def(p_def: InputActionDef) -> void:
	_resolver.register(p_def)


# ============================================================
# 轴读取
# ============================================================

## 读取一维轴值（平滑后）。
func read_axis(p_action_id: String) -> float:
	if not _can_pass(p_action_id): return 0.0
	var state := _resolver.get_state(p_action_id)
	return state.smoothed_value if state != null else 0.0


## 读取一维轴原始值（未经平滑）。
func read_axis_raw(p_action_id: String) -> float:
	if not _can_pass(p_action_id): return 0.0
	var state := _resolver.get_state(p_action_id)
	return state.value if state != null else 0.0


# ============================================================
# 二进制读取
# ============================================================

## 是否按住。
func is_pressed(p_action_id: String) -> bool:
	if not _can_pass(p_action_id): return false
	var state := _resolver.get_state(p_action_id)
	return state._pressed if state != null else false


## 是否刚按下（本帧首次）。
func is_just_pressed(p_action_id: String) -> bool:
	if not _can_pass(p_action_id): return false
	var state := _resolver.get_state(p_action_id)
	return state._just_pressed if state != null else false


## 是否刚释放（本帧首次）。
func is_just_released(p_action_id: String) -> bool:
	if not _can_pass(p_action_id): return false
	var state := _resolver.get_state(p_action_id)
	return state._just_released if state != null else false


# ============================================================
# 方向向量（WASD/摇杆）
# ============================================================

func get_move_vector() -> Vector2:
	if not _is_action_allowed(_move_left): return Vector2.ZERO
	if _move_left.is_empty(): return Vector2.ZERO
	var x := read_axis(_move_right) - read_axis(_move_left)
	var y := read_axis(_move_down) - read_axis(_move_up)
	return Vector2(x, y)

func mouse_position() -> Vector2:
	return DisplayServer.mouse_get_position()

func set_move_keys(p_left: String, p_right: String, p_up: String, p_down: String) -> void:
	_move_left = p_left; _move_right = p_right
	_move_up = p_up; _move_down = p_down


# ============================================================
# 上下文栈
# ============================================================

func push_context(p_ctx: InputContext) -> void:
	if _context_stack.size() > 0 and _context_stack.back().priority == p_ctx.priority:
		_context_stack.pop_back()
	_context_stack.append(p_ctx)

func pop_context() -> void:
	if _context_stack.size() > 0: _context_stack.pop_back()

func clear_contexts() -> void:
	_context_stack.clear()

func get_current_context() -> InputContext:
	if _context_stack.is_empty(): return null
	return _context_stack.back()

func set_game_input_blocker(p_blocker: Callable) -> void:
	_game_input_blocker = p_blocker


# ============================================================
# 向后兼容
# ============================================================

## 注册简单二进制动作（兼容旧 API）。内部转为无绑定的 InputActionDef。
func register_action(p_action_id: String, p_input_map_action: String) -> void:
	_resolver.register(InputActionDef.new(p_action_id, InputActionDef.ActionType.BINARY))

## 批量注册（兼容旧 API）。
func register_actions(p_entries: Array) -> void:
	for entry in p_entries:
		if entry is Array and (entry as Array).size() >= 1:
			_resolver.register(InputActionDef.new(str(entry[0]), InputActionDef.ActionType.BINARY))

func set_game_input_enabled(p_enabled: bool) -> void:
	if p_enabled:
		if _context_stack.size() > 0 and _context_stack.back().name == "game_disabled":
			_context_stack.pop_back()
	else:
		var ctx := InputContext.new()
		ctx.name = "game_disabled"; ctx.priority = 9999
		ctx.block_all_game_actions = true
		push_context(ctx)


# ============================================================
# 内部
# ============================================================

func _can_pass(p_action_id: String) -> bool:
	return _is_action_allowed(p_action_id) and not _is_blocked_by_game_input_gate(p_action_id)

func _is_action_allowed(p_action_id: String) -> bool:
	if _context_stack.is_empty(): return true
	var ctx = _context_stack.back()
	if not ctx.allowed_actions.is_empty():
		return ctx.allowed_actions.has(p_action_id)
	if ctx.block_all_game_actions: return false
	if not ctx.blocked_action_ids.is_empty():
		if ctx.blocked_action_ids.has("*"): return false
		return not ctx.blocked_action_ids.has(p_action_id)
	return true

func _is_blocked_by_game_input_gate(p_action_id: String) -> bool:
	if not _game_input_blocker.is_valid(): return false
	return bool(_game_input_blocker.call(p_action_id))
