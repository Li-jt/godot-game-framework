## InputService
## 游戏输入服务。提供动作注册、上下文栈、二进制查询、轴读取。
## 所有游戏输入必须通过此服务，禁止直接使用 Input / _input / _unhandled_input。
##
## v2.0 变更：
##   - 新增 register_action_def() / read_axis()
##   - _game_input_blocker 扩展到所有查询方法
##   - 不再依赖 _input/_unhandled_input 回调
class_name InputService
extends ModuleLifecycle

var _adapter: InputAdapter = null
var _action_map: Dictionary = {}       # { game_action_id → InputMap action name }
var _action_defs: Dictionary = {}      # { game_action_id → InputActionDef }
var _context_stack: Array[InputContext] = []

var _move_left: String = ""
var _move_right: String = ""
var _move_up: String = ""
var _move_down: String = ""
var _game_input_blocker: Callable = Callable()


func _on_init() -> OperationResult:
	return OperationResult.ok()


func configure(p_adapter: InputAdapter) -> OperationResult:
	if p_adapter == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: adapter 不能为 null", module_name)
	_adapter = p_adapter
	return OperationResult.ok()


# ============================================================
# 动作注册
# ============================================================

## 注册简单二进制动作（向后兼容）。
func register_action(p_action_id: String, p_input_map_action: String) -> void:
	_action_map[p_action_id] = p_input_map_action


## 批量注册简单动作。
func register_actions(p_entries: Array) -> void:
	for entry in p_entries:
		if not entry is Array or (entry as Array).size() < 2:
			continue
		var pair: Array = entry as Array
		register_action(pair[0] as String, pair[1] as String)


## v2.0：注册完整动作定义（支持轴动作）。
func register_action_def(p_def: InputActionDef) -> void:
	_action_defs[p_def.action_id] = p_def
	# 同时注册到简单映射（兼容 is_pressed 查询）
	if not p_def.input_map_actions.is_empty():
		register_action(p_def.action_id, p_def.input_map_actions[0])


func set_move_keys(p_left: String, p_right: String, p_up: String, p_down: String) -> void:
	_move_left = p_left; _move_right = p_right
	_move_up = p_up; _move_down = p_down


## 设置游戏输入动态阻挡回调。UIService 用此实现鼠标悬停 UI 时屏蔽世界动作。
func set_game_input_blocker(p_blocker: Callable) -> void:
	_game_input_blocker = p_blocker


# ============================================================
# 上下文栈
# ============================================================

func push_context(p_ctx: InputContext) -> void:
	if _context_stack.size() > 0 and _context_stack.back().priority == p_ctx.priority:
		_context_stack.pop_back()
	_context_stack.append(p_ctx)


func pop_context() -> void:
	if _context_stack.size() > 0:
		_context_stack.pop_back()


func clear_contexts() -> void:
	_context_stack.clear()


func get_current_context() -> InputContext:
	if _context_stack.is_empty(): return null
	return _context_stack.back()


# ============================================================
# 二进制查询
# ============================================================

func is_pressed(p_action_id: String) -> bool:
	if not _can_pass(p_action_id): return false
	return _adapter.is_action_pressed(_resolve(p_action_id))


func is_just_pressed(p_action_id: String) -> bool:
	if not _can_pass(p_action_id): return false
	return _adapter.is_action_just_pressed(_resolve(p_action_id))


func is_just_released(p_action_id: String) -> bool:
	if not _can_pass(p_action_id): return false
	return _adapter.is_action_just_released(_resolve(p_action_id))


# ============================================================
# 轴查询（v2.0 新增）
# ============================================================

## 读取轴动作的当前值。聚合所有绑定的设备输入。
func read_axis(p_action_id: String) -> float:
	if not _can_pass(p_action_id): return 0.0
	var def: InputActionDef = _action_defs.get(p_action_id, null)
	if def == null:
		# 回退：简单动作用 get_action_strength
		return _adapter.get_action_strength(_resolve(p_action_id))
	return _adapter.read_axis(def.input_map_actions, def.axis_sensitivity, def.axis_deadzone)


# ============================================================
# 移动向量
# ============================================================

func get_move_vector() -> Vector2:
	if not _is_action_allowed(_move_left): return Vector2.ZERO
	if _move_left.is_empty(): return Vector2.ZERO
	return _adapter.get_vector(_move_left, _move_right, _move_up, _move_down)


func mouse_position() -> Vector2:
	return _adapter.mouse_position()


# ============================================================
# 向后兼容
# ============================================================

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

func _resolve(p_action_id: String) -> String:
	return _action_map.get(p_action_id, p_action_id)


## 综合过滤：上下文允许 + 未被子系统动态阻挡。
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
