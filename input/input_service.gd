## InputService
## 游戏输入服务。提供动作注册、上下文栈、输入查询。
##
## 输入上下文栈：
##   栈空 = 所有动作放行（默认 gameplay）
##   push_context(ctx) → 只有 ctx.allowed_actions 中的动作生效
##   pop_context() → 恢复上一层
##
## 使用方式：
##   [codeblock]
##   # Game 层注册
##   input.register_action("interact", "interact")
##
##   # UI 弹窗时压入 UI 上下文（仅允许 ui_accept/ui_cancel）
##   var ui_ctx := InputContext.new()
##   ui_ctx.name = "ui"; ui_ctx.priority = 100
##   ui_ctx.allowed_actions = ["ui_accept", "ui_cancel"]
##   input.push_context(ui_ctx)
##   ...
##   input.pop_context()
##   [/codeblock]
class_name InputService
extends ModuleLifecycle

var _adapter: InputAdapter = null
var _action_map: Dictionary = {}
var _context_stack: Array[InputContext] = []

var _move_left: String = ""
var _move_right: String = ""
var _move_up: String = ""
var _move_down: String = ""


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

func register_action(p_action_id: String, p_input_map_action: String) -> void:
	_action_map[p_action_id] = p_input_map_action


func register_actions(p_entries: Array) -> void:
	for entry in p_entries:
		if not entry is Array or (entry as Array).size() < 2:
			push_warning("InputService: 跳过非法 entry: %s" % str(entry))
			continue
		var pair: Array = entry as Array
		register_action(pair[0] as String, pair[1] as String)


func set_move_keys(p_left: String, p_right: String, p_up: String, p_down: String) -> void:
	_move_left = p_left
	_move_right = p_right
	_move_up = p_up
	_move_down = p_down


# ============================================================
# 上下文栈
# ============================================================

## 压入输入上下文。栈顶上下文决定当前允许哪些动作。
func push_context(p_ctx: InputContext) -> void:
	# 同优先级替换栈顶，避免重复压入
	if _context_stack.size() > 0 and _context_stack.back().priority == p_ctx.priority:
		_context_stack.pop_back()
	_context_stack.append(p_ctx)


## 弹出栈顶上下文。
func pop_context() -> void:
	if _context_stack.size() > 0:
		_context_stack.pop_back()


## 清空所有上下文，恢复默认 gameplay 模式。
func clear_contexts() -> void:
	_context_stack.clear()


## 获取当前上下文，栈空返回 null。
func get_current_context() -> InputContext:
	if _context_stack.is_empty():
		return null
	return _context_stack.back()


# ============================================================
# 输入查询
# ============================================================

func is_pressed(p_action_id: String) -> bool:
	return _is_action_allowed(p_action_id) and _adapter.is_action_pressed(_resolve(p_action_id))


func is_just_pressed(p_action_id: String) -> bool:
	return _is_action_allowed(p_action_id) and _adapter.is_action_just_pressed(_resolve(p_action_id))


func is_just_released(p_action_id: String) -> bool:
	return _is_action_allowed(p_action_id) and _adapter.is_action_just_released(_resolve(p_action_id))


func get_move_vector() -> Vector2:
	if not _is_action_allowed(_move_left):
		return Vector2.ZERO
	if _move_left.is_empty() or _move_right.is_empty() or _move_up.is_empty() or _move_down.is_empty():
		return Vector2.ZERO
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
		ctx.name = "game_disabled"
		ctx.priority = 9999
		ctx.block_all_game_actions = true
		push_context(ctx)


# ============================================================
# 内部
# ============================================================

func _resolve(p_action_id: String) -> String:
	return _action_map.get(p_action_id, p_action_id)


## 检查动作在当前上下文下是否可用。
## 优先级：allowed（白名单）> block_all（全禁）> blocked（黑名单）> 放行。
func _is_action_allowed(p_action_id: String) -> bool:
	if _context_stack.is_empty():
		return true
	var ctx = _context_stack.back()
	# 白名单优先：设了 allowed 则只放行列表内的动作（ESC 逃生用）
	if not ctx.allowed_actions.is_empty():
		return ctx.allowed_actions.has(p_action_id)
	if ctx.block_all_game_actions:
		return false
	if not ctx.blocked_action_ids.is_empty():
		if ctx.blocked_action_ids.has("*"):
			return false
		return not ctx.blocked_action_ids.has(p_action_id)
	return true
