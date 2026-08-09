## GF_InputService v4.0
## 统一输入服务。内部组合 GF_InputRouter / GF_ActionResolver / GF_InputPolicy / GF_InputRebindService。
## 游戏层只通过此服务查询动作，不接触底层原始事件。
##
## [b]典型用法——注册鼠标左键点击，UI 打开时自动屏蔽地图点击：[/b]
## [codeblock]
## # 1. 启动时注册动作
## var click := GF_InputActionDef.new("map_click", GF_InputActionDef.ActionType.BINARY) \
##     .bind_mouse(MOUSE_BUTTON_LEFT)
## input.register_action_def(click)
##
## # 2. 注册 UI 面板时声明输入阻挡（框架自动处理）
## var def := GF_UIPanelDef.new("inventory", "res://ui/inventory.tscn")
## def.input_block_mode = GF_UIPanelDef.InputBlockMode.ALWAYS
## def.blocked_action_ids = ["*"]      # 面板打开时，所有游戏动作被屏蔽
## ui_service.register(def)
##
## # 3. 主循环中查询
## func _process(_delta: float) -> void:
##     if input.is_just_pressed("map_click"):     # UI 打开时自动返回 false
##         var pos := input.mouse_position()
##         _handle_map_click(pos)
## [/codeblock]
##
## [b]输入屏蔽的三层机制：[/b]
##   1. Context 栈 —— push_context() 限制可用动作（如主菜单只允许 ui_accept）
##   2. UIPanel ALWAYS —— 面板打开即屏蔽，如背包面板 block ["*"]
##   3. UIPanel POINTER_ONLY —— 鼠标在面板区域内才屏蔽
class_name GF_InputService
extends GF_ModuleLifecycle

var _resolver: GF_ActionResolver = null
var _router: GF_InputRouter = null
var _policy: GF_InputPolicy = null
var _gesture: GF_InputGestureEngine = null
var _rebind: GF_InputRebindService = null


func _set_bootstrap(p_bs) -> void:
	_bootstrap = p_bs
	if _bootstrap.service(GF_InputAdapter) == null:
		_bootstrap.register(GF_InputAdapter.new())


func _on_init() -> GF_OperationResult:
	_resolver = GF_ActionResolver.new()
	_policy = GF_InputPolicy.new()
	_gesture = GF_InputGestureEngine.new()
	_rebind = GF_InputRebindService.new()
	_rebind.configure(_resolver)
	_resolver.set_policy(_policy)
	_resolver.set_gesture(_gesture)
	return GF_OperationResult.ok()


func dependencies() -> Array:
	return [GF_InputAdapter]


func configure() -> GF_OperationResult:
	_router = GF_InputRouter.new()
	_router.name = "GF_InputRouter"
	_router.configure(_resolver)
	_bootstrap.add_child(_router)
	return GF_OperationResult.ok()


func _on_dispose() -> GF_OperationResult:
	destroy_router()
	return GF_OperationResult.ok()


# ============================================================
# 内部管理
# ============================================================

## 注入 GF_UIService（GF_UIService.configure() 中自动调用，Game 层无需关心）。
func set_ui_service(p_ui) -> void:
	_policy.set_ui_service(p_ui)


func get_or_create_router() -> GF_InputRouter:
	return _router


func destroy_router() -> void:
	if _router != null:
		_router.set_enabled(false)
		if _router.is_inside_tree():
			_router.queue_free()
		_router = null


# ============================================================
# 动作注册
# ============================================================

## 注册输入动作。传入配置好的 GF_InputActionDef，支持链式构建：
## [codeblock]input.register_action_def(GF_InputActionDef.new("shoot").bind_mouse(MOUSE_BUTTON_LEFT))[/codeblock]
func register_action_def(p_def: GF_InputActionDef) -> void:
	p_def.snapshot_default_bindings()
	_resolver.register_action_def(p_def)


## 获取已注册的动作定义。
func get_action_def(p_action_id: String) -> GF_InputActionDef:
	return _resolver.get_def(p_action_id)


## 获取所有已注册的动作 ID 列表。
func get_all_action_ids() -> Array[String]:
	return _resolver.get_all_action_ids()


# ============================================================
# 动作查询 —— 主循环中每帧调用
# ============================================================

## 读取一维轴值（-1.0 ~ 1.0）。适用于移动、缩放等连续输入。
## [codeblock]var zoom := input.read_axis("camera_zoom")[/codeblock]
func read_axis(p_action_id: String) -> float:
	return _resolver.read_axis(p_action_id)

## 当前帧是否处于按下状态。适用于需要持续检测的场景（如按住 Shift 跑步）。
func is_pressed(p_action_id: String) -> bool:
	return _resolver.is_pressed(p_action_id)

## 当前帧是否刚按下。适用于"按下触发一次"的场景（如射击、跳跃、点击地图）。
## [b]UI 面板通过 blocked_action_ids 屏蔽后，此方法自动返回 false。[/b]
func is_just_pressed(p_action_id: String) -> bool:
	return _resolver.is_just_pressed(p_action_id)

## 当前帧是否刚松开。适用于"松开时触发"的场景（如蓄力攻击释放）。
func is_just_released(p_action_id: String) -> bool:
	return _resolver.is_just_released(p_action_id)


# ============================================================
# 输入上下文栈 —— 控制哪些动作在特定状态下可用
# ============================================================

## 压入输入上下文到栈顶。栈顶上下文的规则优先生效。
## [b]典型场景：[/b]打开主菜单时 push 一个只允许 "ui_accept"/"ui_cancel" 的上下文，
## 关闭菜单时 pop_context() 恢复游戏操作。
func push_context(p_ctx: GF_InputContext) -> void:
	var stack: Array[GF_InputContext] = _policy.get_context_stack()
	if stack.size() > 0 and stack.back().priority == p_ctx.priority:
		stack.pop_back()
	stack.append(p_ctx)

## 弹出栈顶输入上下文，恢复上一层规则。
func pop_context() -> void:
	var stack: Array[GF_InputContext] = _policy.get_context_stack()
	if stack.size() > 0: stack.pop_back()

## 清空所有输入上下文（恢复默认放行模式）。
func clear_contexts() -> void:
	_policy.get_context_stack().clear()


# ============================================================
# 按键重绑定
# ============================================================

## 开始捕获按键以重新绑定指定动作的指定槽位。
func begin_rebind(p_action_id: String, p_slot: int) -> bool:
	return _rebind.begin_rebind(p_action_id, p_slot)

## 取消当前重绑定。
func cancel_rebind() -> void:
	_rebind.cancel_rebind()

## 是否正在等待用户按下按键以完成重绑定。
func is_waiting_rebind() -> bool:
	return _rebind.is_waiting()

## 将输入事件传给重绑定系统处理（GF_InputRouter 自动调用）。
func handle_event_for_rebind(p_event: InputEvent) -> bool:
	return _rebind.handle_event_for_rebind(p_event)

## 保存当前绑定配置到文件。
func save_bindings(p_path: String = "user://input_bindings_v1.tres") -> bool:
	return _rebind.save(p_path)

## 从文件加载绑定配置。
func load_bindings(p_path: String = "user://input_bindings_v1.tres") -> bool:
	return _rebind.load(p_path)

## 将指定动作的绑定重置为默认值。
func reset_action_to_default(p_action_id: String) -> bool:
	return _rebind.reset_action_to_default(p_action_id)


# ============================================================
# 便捷方法
# ============================================================

## 快捷注册二值动作（简单场景，不需要链式配置绑定时使用）。
func register_action(p_action_id: String, _p_input_map_action: String = "") -> void:
	register_action_def(GF_InputActionDef.new(p_action_id))

## 批量注册。p_entries 为 Array[Array]，每项 [action_id]。
func register_actions(p_entries: Array) -> void:
	for entry in p_entries:
		if entry is Array:
			register_action(str(entry[0]))

## 获取移动向量（组合 move_left/right/up/down 四轴）。
func get_move_vector() -> Vector2:
	var x: float = read_axis("move_right") - read_axis("move_left")
	var y: float = read_axis("move_down") - read_axis("move_up")
	return Vector2(x, y)

## 获取当前鼠标屏幕坐标。
func mouse_position() -> Vector2:
	return DisplayServer.mouse_get_position()


# ============================================================
# 录制/回放
# ============================================================

## 开始录制输入。已在录制中则无操作（防止误触丢失数据）。
func start_recording() -> void:
	_resolver.start_recording()

## 强制重新开始录制（清除已有数据）。
func restart_recording() -> void:
	_resolver.restart_recording()

## 停止录制，返回录制数据。
func stop_recording() -> Dictionary:
	return _resolver.stop_recording()

## 获取当前录制快照，不停止录制。
func snapshot_recording() -> Dictionary:
	return _resolver.snapshot_recording()

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

## 保存当前录制到文件（不停止录制）。
func save_recording(p_path: String) -> bool:
	var data: Dictionary = _resolver.snapshot_recording()
	if data.frames.is_empty():
		return false
	var file: FileAccess = FileAccess.open(p_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true

## 从文件加载录制数据并开始回放。
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


## 启用/禁用整个输入系统（如过场动画期间禁用）。
func set_enabled(p_enabled: bool) -> void:
	if _router != null: _router.set_enabled(p_enabled)
