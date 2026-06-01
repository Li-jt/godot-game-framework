## UIService
## UI 管理服务。根据 PanelKind 路由到对应 UI 层，根据 Lifecycle 控制关闭行为。
class_name UIService
extends ModuleLifecycle

const MAX_CACHED := 5
const GAME_INPUT_BLOCK_ALWAYS := 1
const GAME_INPUT_BLOCK_POINTER_ONLY := 2

var _scene_host: SceneHost = null
var _input_service: InputService = null
var _log: LogService = null

var _panel_defs: Dictionary = {}
var _active_panels: Dictionary = {}
var _cache: Dictionary = {}
var _cache_order: Array[String] = []
var _open_order: Array[String] = []

## 面板上下文。configure 时由上层传入，每次面板实例化后自动设置到 panel.ctx。
var _panel_context: UiContext = null


func _on_init() -> OperationResult:
	return OperationResult.ok()


## 配置 UI 服务。p_ui_context 为上层装配器构建的 UiContext，
## UIService 将其存储为 _panel_context，后续所有面板实例化后自动注入。
func configure(p_ui_context: UiContext) -> OperationResult:
	if p_ui_context == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "ui_context 不能为 null", module_name)
	if p_ui_context.scene_host == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "ui_context.scene_host 不能为 null", module_name)
	if p_ui_context.input == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "ui_context.input 不能为 null", module_name)
	if p_ui_context.log == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "ui_context.log 不能为 null", module_name)

	_panel_context = p_ui_context
	_panel_context.ui = self

	_scene_host = p_ui_context.scene_host
	_input_service = p_ui_context.input
	_input_service.set_game_input_blocker(_should_block_game_action)
	_log = p_ui_context.log
	return OperationResult.ok()


# ============================================================
# 注册
# ============================================================

## 注册单个面板定义
func register(p_def: UIPanelDef) -> OperationResult:
	if p_def.name.is_empty() or p_def.path.is_empty():
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "无效定义: %s" % p_def.name, module_name)
	_panel_defs[p_def.name] = p_def
	return OperationResult.ok()


## 批量注册面板定义
func register_all(p_defs: Array[UIPanelDef]) -> OperationResult:
	for def in p_defs:
		var r := register(def)
		if r.is_fail(): return r
	_log.info("UIService", "面板注册完成，共 %d 个" % _panel_defs.size())
	_prewarm_deferred()
	return OperationResult.ok()


# ============================================================
# 打开
# ============================================================

## 打开面板。singleton 面板重复打开会 reopen 并提到栈顶。
func open(p_name: String, p_data: Dictionary = {}) -> OperationResult:
	var def := _get_def(p_name)
	if def == null:
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "面板未注册: %s" % p_name, module_name)

	if _active_panels.has(p_name) and def.singleton:
		var existing: UIPanel = _active_panels[p_name]
		existing.reopen(p_data)
		_bring_to_front(p_name)
		_recalculate_input_block()
		return OperationResult.ok(existing)

	if _cache.has(p_name):
		var cached: UIPanel = _cache[p_name]
		_cache.erase(p_name)
		_cache_order.erase(p_name)
		_active_panels[p_name] = cached
		cached.reopen(p_data)
		_on_opened(p_name)
		return OperationResult.ok(cached)

	var result = _scene_host.load_ui_panel(def.kind, def.path, {})
	if result.is_fail():
		return result

	var panel := result.data as UIPanel
	if panel == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "根节点不是 UIPanel: %s" % p_name, module_name)

	panel.panel_name = p_name
	panel.ctx = _panel_context
	# v4.0: 注入输入阻挡配置到面板实例
	panel._ui_block_mode = def.game_input_block_mode
	panel._blocked_action_ids = def.blocked_action_ids.duplicate()
	panel._allowed_action_ids = def.blocked_action_ids.filter(func(a): return a == "cancel")
	_active_panels[p_name] = panel
	panel.open(p_data)
	_on_opened(p_name)
	return OperationResult.ok(panel)


# ============================================================
# 关闭
# ============================================================

## 关闭面板。PERSISTENT / MANAGED_BY_FLOW 面板会被拒绝。
func close(p_name: String) -> OperationResult:
	var def := _get_def(p_name)
	if def == null:
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "面板未注册: %s" % p_name, module_name)

	if def.lifecycle in [UIPanelDef.Lifecycle.PERSISTENT, UIPanelDef.Lifecycle.MANAGED_BY_FLOW]:
		return OperationResult.fail(OperationResult.ERR_FORBIDDEN, "不允许普通 close: %s" % p_name, module_name)

	_do_close(p_name, def)
	return OperationResult.ok()


## 强制关闭面板（跳过生命周期限制）
func force_close(p_name: String) -> OperationResult:
	var def := _get_def(p_name)
	if def == null:
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "面板未注册: %s" % p_name, module_name)
	_do_close(p_name, def)
	return OperationResult.ok()


# ============================================================
# 显隐
# ============================================================

## 显示已打开的面板
func show(p_name: String) -> OperationResult:
	if not _active_panels.has(p_name):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "面板未打开: %s" % p_name, module_name)
	(_active_panels[p_name] as UIPanel).show()
	_recalculate_input_block()
	return OperationResult.ok()


## 隐藏已打开的面板
func hide(p_name: String) -> OperationResult:
	if not _active_panels.has(p_name):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "面板未打开: %s" % p_name, module_name)
	(_active_panels[p_name] as UIPanel).hide()
	_recalculate_input_block()
	return OperationResult.ok()


# ============================================================
# 批量
# ============================================================

## 关闭栈顶可关闭面板（ESC 键逻辑）。
func close_top() -> OperationResult:
	for i in range(_open_order.size() - 1, -1, -1):
		var name: String = _open_order[i]
		var def := _get_def(name)
		if def == null:
			continue
		if def.lifecycle in [UIPanelDef.Lifecycle.PERSISTENT, UIPanelDef.Lifecycle.MANAGED_BY_FLOW]:
			continue
		if not def.close_on_escape:
			continue
		_do_close(name, def)
		return OperationResult.ok()
	return OperationResult.ok()


## 关闭所有非 PERSISTENT/MANAGED_BY_FLOW 面板
func close_all() -> void:
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null and def.lifecycle in [UIPanelDef.Lifecycle.PERSISTENT, UIPanelDef.Lifecycle.MANAGED_BY_FLOW]:
			continue
		_do_close_quiet(name, def)
	_recalculate_input_block()


## 关闭指定 UI 层的全部面板
func clear_layer(p_kind: UIPanelDef.PanelKind) -> void:
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null and def.kind == p_kind:
			_do_close_quiet(name, def)
	_recalculate_input_block()


## 关闭游戏内面板（SCREEN/POPUP/TOOLTIP），保留 HUD/系统
func clear_gameplay_ui() -> void:
	for kind in [UIPanelDef.PanelKind.SCREEN, UIPanelDef.PanelKind.POPUP, UIPanelDef.PanelKind.TOOLTIP]:
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
		if def != null and def.kind == UIPanelDef.PanelKind.HUD:
			hide(name)


## 显示所有 HUD 面板。进入游戏时调用。
func show_hud() -> void:
	for name in _panel_defs.keys():
		var def: UIPanelDef = _panel_defs[name]
		if def.kind == UIPanelDef.PanelKind.HUD and def.lifecycle == UIPanelDef.Lifecycle.PERSISTENT:
			if not _active_panels.has(name):
				var r := open(name)
				if r.is_fail():
					_log.error("UIService", "show_hud 打开失败: %s — %s" % [name, r.error.message])
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null and def.kind == UIPanelDef.PanelKind.HUD:
			show(name)


# ============================================================
# 查询
# ============================================================

func is_open(p_name: String) -> bool:
	return _active_panels.has(p_name)


func get_panel(p_name: String) -> UIPanel:
	return _active_panels.get(p_name, null) as UIPanel


## v4.0：返回所有活跃面板列表（供 InputPolicy 查询）。
func get_active_panels() -> Array[UIPanel]:
	var result: Array[UIPanel] = []
	for panel in _active_panels.values():
		result.append(panel as UIPanel)
	return result


## v4.0：返回所有活跃面板名称。
func get_active_panel_names() -> Array[String]:
	var result: Array[String] = []
	for name in _active_panels.keys():
		result.append(str(name))
	return result


## 当前是否有可见的模态面板
func has_modal_active() -> bool:
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null and def.modal and (_active_panels[name] as UIPanel).visible:
			return true
	return false


## 当前是否有阻塞下层 UI 的面板
func has_ui_blocker_active() -> bool:
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null and def.blocks_ui_below and (_active_panels[name] as UIPanel).visible:
			return true
	return false


# ============================================================
# 内部：关闭
# ============================================================

func _do_close(p_name: String, p_def: UIPanelDef, p_suppress_recalc: bool = false) -> void:
	if not _active_panels.has(p_name):
		return

	var panel: UIPanel = _active_panels[p_name]
	_active_panels.erase(p_name)
	_remove_from_order(p_name)

	if p_def.lifecycle == UIPanelDef.Lifecycle.HIDE_ON_CLOSE:
		_cached_store(p_name, panel)
	else:
		panel.close()

	if not p_suppress_recalc:
		_recalculate_input_block()


func _do_close_quiet(p_name: String, p_def: UIPanelDef) -> void:
	_do_close(p_name, p_def, true)


func _clear_layer_suppressed(p_kind: UIPanelDef.PanelKind) -> void:
	for name in _active_panels.keys():
		var def := _get_def(name)
		if def != null and def.kind == p_kind:
			_do_close_quiet(name, def)


# ============================================================
# 内部：缓存
# ============================================================

func _cached_store(p_name: String, p_panel: UIPanel) -> void:
	p_panel.hide_panel()
	if _cache.has(p_name): _cache_order.erase(p_name)

	while _cache.size() >= MAX_CACHED:
		var evict_name := _cache_order[0] if _cache_order.size() > 0 else ""
		if evict_name.is_empty(): break
		_cache_order.pop_front()
		var evict_panel: UIPanel = _cache.get(evict_name)
		_cache.erase(evict_name)
		if evict_panel != null: evict_panel.close()

	_cache[p_name] = p_panel
	_cache_order.append(p_name)


# ============================================================
# 内部：预热
# ============================================================

func _prewarm_deferred() -> void:
	for name in _panel_defs.keys():
		var def: UIPanelDef = _panel_defs[name]
		if def.prewarm and def.lifecycle in [UIPanelDef.Lifecycle.HIDE_ON_CLOSE, UIPanelDef.Lifecycle.PERSISTENT]:
			_prewarm_one.call_deferred(name)


func _prewarm_one(p_name: String) -> void:
	if not is_instance_valid(self):
		return

	var def: UIPanelDef = _panel_defs[p_name]
	var result = _scene_host.load_ui_panel(def.kind, def.path, {})
	if result.is_fail(): return

	var panel := result.data as UIPanel
	if panel == null: return

	panel.panel_name = p_name
	panel.ctx = _panel_context

	if not def.preview_data.is_empty():
		panel.open(def.preview_data)

	panel.hide()
	_cached_store(p_name, panel)


# ============================================================
# 内部：输入
# ============================================================

var _ui_block_context: InputContext = null

func _recalculate_input_block() -> void:
	if _input_service == null:
		return

	var block_all := false
	var blocked_ids: Array[String] = []

	for name in _active_panels.keys():
		var def := _get_def(name)
		var panel: UIPanel = _active_panels[name]
		if def == null or not _uses_always_game_input_block(def) or not panel.visible:
			continue
		for action_id in def.blocked_action_ids:
			if action_id == "*":
				block_all = true
				break
			if not blocked_ids.has(action_id):
				blocked_ids.append(action_id)

	var need_block := block_all or not blocked_ids.is_empty()

	if need_block and _ui_block_context == null:
		_ui_block_context = InputContext.new()
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


func _should_block_game_action(p_action_id: String) -> bool:
	for name in _active_panels.keys():
		var def := _get_def(name)
		var panel: UIPanel = _active_panels[name]
		if def == null or panel == null or not panel.visible:
			continue
		if def.game_input_block_mode != GAME_INPUT_BLOCK_POINTER_ONLY:
			continue
		if not _def_blocks_action(def, p_action_id):
			continue
		if panel.is_pointer_over_game_input_blocking_area(panel.get_global_mouse_position()):
			return true
	return false


func _uses_always_game_input_block(p_def: UIPanelDef) -> bool:
	return p_def.blocks_game_input or p_def.game_input_block_mode == GAME_INPUT_BLOCK_ALWAYS


func _def_blocks_action(p_def: UIPanelDef, p_action_id: String) -> bool:
	if p_def.blocked_action_ids.has("*"):
		return true
	return p_def.blocked_action_ids.has(p_action_id)


# ============================================================
# 内部：辅助
# ============================================================

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


func _apply_layer_order(p_kind: UIPanelDef.PanelKind) -> void:
	var layer = _scene_host.get_ui_layer(p_kind)
	var children = layer.get_children()
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
	if p_node is UIPanel:
		var name: String = (p_node as UIPanel).panel_name
		var def := _get_def(name)
		if def != null:
			return def.layer_order
	return 0


func _get_def(p_name: String) -> UIPanelDef:
	return _panel_defs.get(p_name, null) as UIPanelDef
