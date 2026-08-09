## GF_UIService
## UI 管理服务。启动时自动创建 UI 节点树（CanvasLayer → UIRoot → 6层）并挂到场景树。
## 根据面板 kind 路由到对应 UI 层，根据 Lifecycle 控制关闭行为。
class_name GF_UIService
extends GF_ModuleLifecycle

const MAX_CACHED := 5

# ============================================================
# 依赖
# ============================================================

var _scene_factory: GF_SceneFactory = null
var _input_service: GF_InputService = null
var _log: GF_LogService = null

# ============================================================
# UI 节点树（由 configure() 自动创建）
# ============================================================

var _ui_canvas: CanvasLayer = null
var _ui_root: Control = null
var _ui_layers: Dictionary = {}  # {StringName: Control}

# ============================================================
# 面板管理
# ============================================================

var _panel_defs: Dictionary = {}
var _active_panels: Dictionary = {}
var _cache: Dictionary = {}
var _cache_order: Array[String] = []
var _open_order: Array[String] = []

# ============================================================
# 拖拽
# ============================================================

var _drag_manager: GF_UIDragManager = null
var _drop_targets: Array[GF_UIDropTarget] = []
var _last_hovered: GF_UIDropTarget = null
## 焦点栈：打开面板时保存当前焦点，关闭面板时恢复。
var _focus_stack: Array[Control] = []

# ============================================================
# 生命周期
# ============================================================

func _on_init() -> GF_OperationResult:
	return GF_OperationResult.ok()


func _set_bootstrap(p_bs) -> void:
	_bootstrap = p_bs
	# 自动级联注册 UI 模块的依赖（与 GF_SceneFactory / GF_InputService 的模式一致）
	if _bootstrap.service(GF_SceneFactory) == null:
		_bootstrap.register(GF_SceneFactory.new())
	if _bootstrap.service(GF_InputService) == null:
		_bootstrap.register(GF_InputService.new())


func dependencies() -> Array:
	return [GF_SceneFactory, GF_InputService, GF_LogService]


func configure() -> GF_OperationResult:
	_scene_factory = _bootstrap.service(GF_SceneFactory) as GF_SceneFactory
	_input_service = _bootstrap.service(GF_InputService) as GF_InputService
	_log = _bootstrap.service(GF_LogService) as GF_LogService

	if _scene_factory == null or _input_service == null or _log == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "UI 依赖未满足（需要 GF_SceneFactory / GF_InputService / GF_LogService）", module_name)

	_create_ui_tree()
	_bootstrap.add_child(_ui_canvas)

	_input_service.set_ui_service(self)

	_drag_manager = GF_UIDragManager.new()
	_drag_manager.name = "GF_UIDragManager"
	_drag_manager.configure(self)
	_ui_root.add_child(_drag_manager)

	return GF_OperationResult.ok()


# ============================================================
# UI 节点树
# ============================================================

## 创建 UI 节点树：CanvasLayer → UIRoot → 6 层。
## 所有 Control 铺满父节点，mouse_filter=IGNORE 让事件穿透到下层。
func _create_ui_tree() -> void:
	_ui_canvas = CanvasLayer.new()
	_ui_canvas.name = "UiCanvas"
	_ui_canvas.layer = 100

	_ui_root = _make_full_rect_control("UIRoot")
	_ui_canvas.add_child(_ui_root)

	_create_layer(&"hud", "HudLayer")
	_create_layer(&"screen", "ScreenLayer")
	_create_layer(&"popup", "PopupLayer")
	_create_layer(&"tooltip", "TooltipLayer")
	_create_layer(&"system", "SystemLayer")
	_create_layer(&"debug", "DebugLayer")


func _create_layer(p_kind: StringName, p_name: String) -> void:
	var layer: Control = _make_full_rect_control(p_name)
	_ui_root.add_child(layer)
	_ui_layers[p_kind] = layer


func _make_full_rect_control(p_name: String) -> Control:
	var c := Control.new()
	c.name = p_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 按 kind 获取 UI 层 Control。
func get_ui_layer(p_kind: StringName) -> Control:
	var layer: Control = _ui_layers.get(p_kind, null)
	if layer != null:
		return layer
	# 回退：按内建常量匹配
	match p_kind:
		GF_UIPanelDef.KIND_HUD:     return _ui_layers.get(&"hud", _ui_root)
		GF_UIPanelDef.KIND_SCREEN:  return _ui_layers.get(&"screen", _ui_root)
		GF_UIPanelDef.KIND_POPUP:   return _ui_layers.get(&"popup", _ui_root)
		GF_UIPanelDef.KIND_TOOLTIP: return _ui_layers.get(&"tooltip", _ui_root)
		GF_UIPanelDef.KIND_SYSTEM:  return _ui_layers.get(&"system", _ui_root)
		GF_UIPanelDef.KIND_DEBUG:   return _ui_layers.get(&"debug", _ui_root)
		_: return _ui_layers.get(&"screen", _ui_root)


## 获取 UI Canvas 根节点（供外部查询）。
func get_ui_canvas() -> CanvasLayer:
	return _ui_canvas


## 获取 UI Root Control（供外部查询）。
func get_ui_root() -> Control:
	return _ui_root


# ============================================================
# 注册
# ============================================================

## 注册单个面板定义
func register(p_def: GF_UIPanelDef) -> GF_OperationResult:
	if p_def.name.is_empty() or p_def.path.is_empty():
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "无效定义: %s" % p_def.name, module_name)
	_panel_defs[p_def.name] = p_def
	return GF_OperationResult.ok()


## 批量注册面板定义
func register_all(p_defs: Array[GF_UIPanelDef]) -> GF_OperationResult:
	for def in p_defs:
		var r := register(def)
		if r.is_fail(): return r
	_log.info("GF_UIService", "面板注册完成，共 %d 个" % _panel_defs.size())
	_prewarm_deferred()
	return GF_OperationResult.ok()


# ============================================================
# 打开
# ============================================================

## 打开面板。singleton 面板重复打开会 reopen 并提到栈顶。
func open(p_name: String, p_data: Dictionary = {}) -> GF_OperationResult:
	var def := _get_def(p_name)
	if def == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "面板未注册: %s" % p_name, module_name)

	_save_current_focus()
	if _active_panels.has(p_name) and def.singleton:
		var existing: GF_UIPanel = _get_panel_safe(p_name)
		if existing != null:
			existing.reopen(p_data)
		_bring_to_front(p_name)
		_recalculate_input_block()
		return GF_OperationResult.ok(existing)

	if _cache.has(p_name):
		var cached: GF_UIPanel = _get_cached_safe(p_name)
		if cached != null:
			_cache.erase(p_name)
			_cache_order.erase(p_name)
			_active_panels[p_name] = cached
			cached.reopen(p_data)
			_on_opened(p_name)
		return GF_OperationResult.ok(cached)

	var result: GF_OperationResult = _instantiate_panel(def.kind, def.path, {})
	if result.is_fail():
		return result

	var panel := result.data as GF_UIPanel
	if panel == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "根节点不是 GF_UIPanel: %s" % p_name, module_name)

	panel.panel_name = p_name
	panel._bootstrap = _bootstrap
	panel._panel_def = def
	panel.set_focus_config(def.focus_mode, def.default_focus)
	_log.debug("GF_UIService", "open panel: %s mode=%d blocked=%s" % [p_name, def.input_block_mode, str(def.blocked_action_ids)])
	_active_panels[p_name] = panel
	panel.open(p_data)
	_on_opened(p_name)
	return GF_OperationResult.ok(panel)


# ============================================================
# 关闭
# ============================================================

## 关闭面板。PERSISTENT / MANAGED_BY_FLOW 面板会被拒绝。
func close(p_name: String) -> GF_OperationResult:
	var def := _get_def(p_name)
	if def == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "面板未注册: %s" % p_name, module_name)

	if def.lifecycle in [GF_UIPanelDef.Lifecycle.PERSISTENT, GF_UIPanelDef.Lifecycle.MANAGED_BY_FLOW]:
		return GF_OperationResult.fail(GF_OperationResult.ERR_FORBIDDEN, "不允许普通 close: %s" % p_name, module_name)

	_do_close(p_name, def)
	return GF_OperationResult.ok()


## 强制关闭面板（跳过生命周期限制）
func force_close(p_name: String) -> GF_OperationResult:
	var def := _get_def(p_name)
	if def == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "面板未注册: %s" % p_name, module_name)
	_do_close(p_name, def)
	return GF_OperationResult.ok()


# ============================================================
# 显隐
# ============================================================

## 显示已打开的面板
func show(p_name: String) -> GF_OperationResult:
	if not _active_panels.has(p_name):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "面板未打开: %s" % p_name, module_name)
	(_active_panels[p_name] as GF_UIPanel).show()
	_recalculate_input_block()
	return GF_OperationResult.ok()


## 隐藏已打开的面板
func hide(p_name: String) -> GF_OperationResult:
	if not _active_panels.has(p_name):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "面板未打开: %s" % p_name, module_name)
	(_active_panels[p_name] as GF_UIPanel).hide()
	_recalculate_input_block()
	return GF_OperationResult.ok()


# ============================================================
# 批量
# ============================================================

## 关闭栈顶可关闭面板（ESC 键逻辑）。
## 拖拽中 ESC → 取消拖拽，不关面板。
func close_top() -> GF_OperationResult:
	if is_dragging():
		cancel_drag()
		return GF_OperationResult.ok()

	for i in range(_open_order.size() - 1, -1, -1):
		var name: String = _open_order[i]
		var def := _get_def(name)
		if def == null:
			continue
		if def.lifecycle in [GF_UIPanelDef.Lifecycle.PERSISTENT, GF_UIPanelDef.Lifecycle.MANAGED_BY_FLOW]:
			continue
		if not def.close_on_escape:
			continue
		_do_close(name, def)
		return GF_OperationResult.ok()
	return GF_OperationResult.ok()


## 关闭所有非 PERSISTENT/MANAGED_BY_FLOW 面板
func close_all() -> void:
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null and def.lifecycle in [GF_UIPanelDef.Lifecycle.PERSISTENT, GF_UIPanelDef.Lifecycle.MANAGED_BY_FLOW]:
			continue
		_do_close_quiet(name, def)
	_recalculate_input_block()


## 关闭指定 UI 层的全部面板
func clear_layer(p_kind: StringName) -> void:
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null and def.kind == p_kind:
			_do_close_quiet(name, def)
	_recalculate_input_block()


## 关闭游戏内面板（SCREEN/POPUP/TOOLTIP），保留 HUD/系统
func clear_gameplay_ui() -> void:
	for kind in [GF_UIPanelDef.KIND_SCREEN, GF_UIPanelDef.KIND_POPUP, GF_UIPanelDef.KIND_TOOLTIP]:
		_clear_layer_suppressed(kind)
	_recalculate_input_block()


## 关闭所有 UI 面板（含 HUD）
func clear_all_ui() -> void:
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null:
			_do_close_quiet(name, def)
	_recalculate_input_block()


## 隐藏所有 HUD 面板。返回主菜单时调用
func hide_hud() -> void:
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null and def.kind == GF_UIPanelDef.KIND_HUD:
			hide(name)


## 显示所有 HUD 面板。进入游戏时调用。
func show_hud() -> void:
	for name in _panel_defs.keys():
		var def: GF_UIPanelDef = _panel_defs[name]
		if def.kind == GF_UIPanelDef.KIND_HUD and def.lifecycle == GF_UIPanelDef.Lifecycle.PERSISTENT:
			if not _active_panels.has(name):
				var r := open(name)
				if r.is_fail():
					_log.error("GF_UIService", "show_hud 打开失败: %s — %s" % [name, r.error.message])
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null and def.kind == GF_UIPanelDef.KIND_HUD:
			show(name)


# ============================================================
# 查询
# ============================================================

func is_open(p_name: String) -> bool:
	return _active_panels.has(p_name)


func get_panel(p_name: String) -> GF_UIPanel:
	return _active_panels.get(p_name, null) as GF_UIPanel


## 返回所有活跃面板列表（供 GF_InputPolicy 查询）。
func get_active_panels() -> Array[GF_UIPanel]:
	var result: Array[GF_UIPanel] = []
	for name in _active_panels.keys():
		var panel_obj = _active_panels[str(name)]
		if is_instance_valid(panel_obj):
			result.append(panel_obj as GF_UIPanel)
	return result


## 返回所有活跃面板名称。
func get_active_panel_names() -> Array[String]:
	var result: Array[String] = []
	for name in _active_panels.keys():
		result.append(str(name))
	return result


# ============================================================
# 拖拽 API
# ============================================================

## 开始拖拽。p_handler 为游戏层实现的 GF_UIDragHandler 子类。
## 如果有旧拖拽未结束，先 cancel 旧的再开始新的。
func begin_drag(p_handler: GF_UIDragHandler, p_screen_pos: Vector2, p_source: GF_UIPanel = null) -> GF_OperationResult:
	if _drag_manager == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "GF_UIDragManager 未初始化", module_name)
	if p_handler == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "handler 不能为 null", module_name)
	if _drag_manager.is_dragging():
		cancel_drag()
	_drag_manager.begin(p_handler, p_screen_pos, MOUSE_BUTTON_LEFT, p_source)
	return GF_OperationResult.ok()


## 取消当前拖拽。触发 handler.on_end_drag(event) 且 event.drop_receiver = null。
func cancel_drag() -> void:
	if _drag_manager == null:
		return
	if _drag_manager.is_dragging():
		var event: GF_UIDragEvent = _drag_manager.get_current_event()
		event.drop_receiver = null

		if is_instance_valid(_drag_manager.get_current_handler()):
			_drag_manager.get_current_handler().on_end_drag(event)

		if _last_hovered != null:
			if _last_hovered.on_leave.is_valid():
				_last_hovered.on_leave.call()
			_last_hovered = null

		_drag_manager.clear_drag_state()


## 当前是否有活跃拖拽（供 GF_InputPolicy 查询）
func is_dragging() -> bool:
	return _drag_manager != null and _drag_manager.is_dragging()


## 获取当前拖拽位置（游戏层在 on_drop 中用来计算世界坐标）
func get_drag_position() -> Vector2:
	if _drag_manager != null and _drag_manager.is_dragging():
		return _drag_manager.get_current_event().position
	return Vector2.ZERO


## 注册放置目标（面板在 _on_open 中调用）
func register_drop_target(p_target: GF_UIDropTarget) -> GF_OperationResult:
	if p_target == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "target 不能为 null", module_name)
	if p_target.panel == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "target.panel 不能为 null", module_name)
	_drop_targets.append(p_target)
	return GF_OperationResult.ok()


## 注销属于某面板的所有放置目标（框架在面板关闭时自动调用）
func unregister_panel_targets(p_panel: GF_UIPanel) -> void:
	var filtered: Array[GF_UIDropTarget] = []
	for t in _drop_targets:
		if is_instance_valid(t) and t.panel != p_panel:
			filtered.append(t)
	_drop_targets = filtered


## 获取 GF_UIDragManager Node。
func get_drag_manager() -> GF_UIDragManager:
	return _drag_manager


## [L2] 简化拖拽：给 data + icon，框架全管。返回 GF_UIDragHandler 供连接信号。
func begin_simple_drag(p_data: Dictionary, p_icon: Texture2D, p_offset: Vector2 = Vector2(-24, -24), p_source: GF_UIPanel = null) -> GF_UIDragHandler:
	var handler: GF_UIDragHandler = _DefaultDragHandler.new(p_data, p_icon, p_offset)
	begin_drag(handler, _get_global_mouse_pos(), p_source)
	return handler


# ============================================================
# 内部：拖拽（GF_UIDragManager 回调）
# ============================================================

func _on_drag_motion(p_mouse_pos: Vector2) -> void:
	var hovered: GF_UIDropTarget = _hit_test_target(p_mouse_pos)
	if hovered != _last_hovered:
		if _last_hovered != null and _last_hovered.on_leave.is_valid():
			_last_hovered.on_leave.call()
		_last_hovered = hovered
		if hovered != null and hovered.on_hover.is_valid():
			hovered.on_hover.call(_drag_manager.get_current_event().drag_data)


func _on_drag_drop(p_mouse_pos: Vector2) -> void:
	var event: GF_UIDragEvent = _drag_manager.get_current_event()
	var hit_target: GF_UIDropTarget = _hit_test_target(p_mouse_pos)

	var accepted := false
	if hit_target != null and hit_target.on_drop.is_valid():
		event.drop_receiver = hit_target.panel
		accepted = hit_target.on_drop.call(event.drag_data)
		if not accepted:
			event.drop_receiver = null

	if is_instance_valid(_drag_manager.get_current_handler()):
		_drag_manager.get_current_handler().on_drop(event)

	if is_instance_valid(_drag_manager.get_current_handler()):
		_drag_manager.get_current_handler().on_end_drag(event)

	if _last_hovered != null:
		if _last_hovered.on_leave.is_valid():
			_last_hovered.on_leave.call()
		_last_hovered = null

	_drag_manager.clear_drag_state()


func _hit_test_target(p_mouse_pos: Vector2) -> GF_UIDropTarget:
	for i in range(_open_order.size() - 1, -1, -1):
		var panel: GF_UIPanel = _get_panel_safe(_open_order[i])
		if panel == null or not panel.visible:
			continue

		for target in _drop_targets:
			if not is_instance_valid(target):
				continue
			if target.panel != panel:
				continue
			if target.accept_filter.is_valid():
				if not target.accept_filter.call(_drag_manager.get_current_event().drag_data):
					continue
			var global_rect := Rect2(panel.global_position + target.rect.position, target.rect.size)
			if global_rect.has_point(p_mouse_pos):
				return target

	return null


# ============================================================
# 内部：关闭
# ============================================================

func _do_close(p_name: String, p_def: GF_UIPanelDef, p_suppress_recalc: bool = false) -> void:
	if not _active_panels.has(p_name):
		return

	var panel: GF_UIPanel = _get_panel_safe(p_name)
	if panel == null: return

	unregister_panel_targets(panel)

	_active_panels.erase(p_name)
	_remove_from_order(p_name)

	_restore_last_focus()
	if p_def.lifecycle == GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE:
		_cached_store(p_name, panel)
	else:
		panel.close()

	if not p_suppress_recalc:
		_recalculate_input_block()


func _do_close_quiet(p_name: String, p_def: GF_UIPanelDef) -> void:
	_do_close(p_name, p_def, true)


func _clear_layer_suppressed(p_kind: StringName) -> void:
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null and def.kind == p_kind:
			_do_close_quiet(name, def)


# ============================================================
# 内部：缓存
# ============================================================

func _cached_store(p_name: String, p_panel: GF_UIPanel) -> void:
	p_panel.hide_panel()
	if _cache.has(p_name): _cache_order.erase(p_name)

	while _cache.size() >= MAX_CACHED:
		var evict_name := _cache_order[0] if _cache_order.size() > 0 else ""
		if evict_name.is_empty(): break
		_cache_order.pop_front()
		var evict_panel: GF_UIPanel = _get_cached_safe(evict_name)
		_cache.erase(evict_name)
		if evict_panel != null: evict_panel.close()

	_cache[p_name] = p_panel
	_cache_order.append(p_name)


# ============================================================
# 内部：预热
# ============================================================

func _prewarm_deferred() -> void:
	for name in _panel_defs.keys():
		var def: GF_UIPanelDef = _panel_defs[name]
		if def.prewarm and def.lifecycle in [GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE, GF_UIPanelDef.Lifecycle.PERSISTENT]:
			_prewarm_one.call_deferred(name)


func _prewarm_one(p_name: String) -> void:
	if not is_instance_valid(self):
		return

	_log.debug("GF_UIService", "_prewarm_one: %s" % p_name)
	var def: GF_UIPanelDef = _panel_defs[p_name]
	var result: GF_OperationResult = _instantiate_panel(def.kind, def.path, {})
	if result.is_fail(): return

	var panel := result.data as GF_UIPanel
	if panel == null: return

	panel.panel_name = p_name
	panel._bootstrap = _bootstrap
	panel._panel_def = def
	panel.set_focus_config(def.focus_mode, def.default_focus)

	if not def.preview_data.is_empty():
		panel.open(def.preview_data)

	panel.hide()
	_cached_store(p_name, panel)


# ============================================================
# 内部：输入
# ============================================================

var _ui_block_context: GF_InputContext = null


func _recalculate_input_block() -> void:
	if _input_service == null:
		return

	var block_all := false
	var blocked_ids: Array[String] = []

	for name in _active_panels.keys():
		var def := _get_def(name)
		var panel: GF_UIPanel = _get_panel_safe(name)
		if def == null or def.input_block_mode != GF_UIPanelDef.InputBlockMode.ALWAYS or not panel.visible:
			continue
		for action_id in def.blocked_action_ids:
			if action_id == "*":
				block_all = true
				break
			if not blocked_ids.has(action_id):
				blocked_ids.append(action_id)

	var need_block := block_all or not blocked_ids.is_empty()

	if need_block and _ui_block_context == null:
		_ui_block_context = GF_InputContext.new()
		_ui_block_context.name = "ui_block"
		_ui_block_context.priority = 500
		if block_all:
			_ui_block_context.allowed_actions = ["cancel"]
			_ui_block_context.block_all_game_actions = true
		else:
			_ui_block_context.blocked_action_ids = blocked_ids.duplicate()
		_input_service.push_context(_ui_block_context)
	elif need_block:
		if block_all:
			_ui_block_context.allowed_actions = ["cancel"]
			_ui_block_context.blocked_action_ids.clear()
			_ui_block_context.block_all_game_actions = true
		else:
			_ui_block_context.allowed_actions.clear()
			_ui_block_context.block_all_game_actions = false
			_ui_block_context.blocked_action_ids = blocked_ids.duplicate()
		_input_service.push_context(_ui_block_context)
	elif _ui_block_context != null:
		_input_service.pop_context()
		_ui_block_context = null



# ============================================================
# 内部：辅助
# ============================================================

func _get_panel_safe(p_name: String) -> GF_UIPanel:
	if not _active_panels.has(p_name):
		return null
	var panel_obj = _active_panels[p_name]
	if not is_instance_valid(panel_obj):
		_active_panels.erase(p_name)
		return null
	return panel_obj as GF_UIPanel


func _get_cached_safe(p_name: String) -> GF_UIPanel:
	if not _cache.has(p_name):
		return null
	var panel_obj = _cache[p_name]
	if not is_instance_valid(panel_obj):
		_cache.erase(p_name)
		return null
	return panel_obj as GF_UIPanel


func _instantiate_panel(p_kind: StringName, p_path: String, p_data: Dictionary) -> GF_OperationResult:
	var result: GF_OperationResult = _scene_factory.create(p_path, p_data)
	if result.is_fail():
		_log.error("GF_UIService", "加载场景失败: %s — %s" % [p_path, result.error.message])
		return result

	var node: Node = result.data
	var layer: Control = get_ui_layer(p_kind)
	layer.add_child(node)
	_log.info("GF_UIService", "已加载面板: %s → %s" % [p_path, p_kind])
	return GF_OperationResult.ok(node)


func _get_global_mouse_pos() -> Vector2:
	if _ui_canvas != null and is_instance_valid(_ui_canvas):
		var vp: Viewport = _ui_canvas.get_viewport()
		if vp != null:
			return vp.get_mouse_position()
	return Vector2.ZERO


func _save_current_focus() -> void:
	if _ui_canvas == null or not is_instance_valid(_ui_canvas):
		return
	var vp: Viewport = _ui_canvas.get_viewport()
	if vp == null:
		return
	var owner: Control = vp.gui_get_focus_owner()
	if owner != null:
		_focus_stack.push_back(owner)


func _restore_last_focus() -> void:
	if _focus_stack.is_empty():
		return
	var prev: Control = _focus_stack.pop_back()
	if is_instance_valid(prev):
		prev.grab_focus()


func _apply_layer_order(p_kind: StringName) -> void:
	var layer: Control = get_ui_layer(p_kind)
	var children: Array[Node] = layer.get_children()
	if children.size() <= 1:
		return
	children.sort_custom(func(a, b):
		var oa := _get_layer_order(a)
		var ob := _get_layer_order(b)
		return oa < ob
	)
	for i in children.size():
		layer.move_child(children[i], i)


func _get_layer_order(p_node: Node) -> int:
	if p_node is GF_UIPanel:
		var name: String = (p_node as GF_UIPanel).panel_name
		var def := _get_def(name)
		if def != null:
			return def.layer_order
	return 0


func _get_def(p_name: String) -> GF_UIPanelDef:
	return _panel_defs.get(p_name, null) as GF_UIPanelDef


func _on_opened(p_name: String) -> void:
	_remove_from_order(p_name)
	_open_order.append(p_name)
	var def := _get_def(p_name)
	if def != null:
		_apply_layer_order(def.kind)
	_recalculate_input_block()


func _bring_to_front(p_name: String) -> void:
	_remove_from_order(p_name)
	_open_order.append(p_name)


func _remove_from_order(p_name: String) -> void:
	_open_order.erase(p_name)


# ============================================================
# 内部：L2 默认 DragHandler
# ============================================================

class _DefaultDragHandler extends GF_UIDragHandler:

	var _data: Dictionary = {}
	var _icon: Texture2D = null
	var _offset: Vector2 = Vector2.ZERO
	var _ghost: GF_UIDragGhost = null

	func _init(p_data: Dictionary, p_icon: Texture2D, p_offset: Vector2) -> void:
		_data = p_data
		_icon = p_icon
		_offset = p_offset

	func on_begin_drag(event: GF_UIDragEvent) -> void:
		event.drag_data = _data
		if _icon != null:
			_ghost = event.show_ghost_texture(_icon, _offset)
