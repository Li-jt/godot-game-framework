## GF_InputPolicy — 输入策略层（v4.0）。
## 统一判定"动作是否可通过"：Context + UI Panel + allowlist。
## 核心原则：按 action 级别判定，不按 event 级别。
class_name GF_InputPolicy
extends RefCounted

var _context_stack: Array[GF_InputContext] = []
## GF_UIService 引用（只读）
var _ui_service: Variant = null  # GF_UIService
var _dbg_once: int = 0


func set_ui_service(p_ui) -> void:
	_ui_service = p_ui


func get_context_stack() -> Array[GF_InputContext]:
	return _context_stack


## 判定指定动作是否被阻挡。
## p_event: 原始 Godot 事件
## p_pointer_pos: 指针位置（viewport 坐标；非空间事件为 Vector2.INF）。
## POINTER_ONLY 命中检测内部会换算为 canvas 坐标，调用方无需关心拉伸窗口。
func is_action_blocked(p_action_id: String, _p_event: InputEvent, p_pointer_pos: Vector2) -> bool:
	# 1. Context allow 命中 -> 永不阻挡
	if _context_allows(p_action_id):
		return false

	# 2. Context block 命中 -> 阻挡
	if _context_blocks(p_action_id):
		return true

	# 3. UI ALWAYS 面板命中 action -> 阻挡
	if _ui_always_blocks(p_action_id):
		return true

	# 4. 空间事件 + POINTER_ONLY 面板命中区域 + action 在 blocked 列表 -> 阻挡
	if p_pointer_pos != Vector2.INF:
		if _ui_pointer_blocks(p_action_id, p_pointer_pos):
			return true

	return false


## 原始事件级判定（resolver 每事件调用）。p_pointer_pos 同 [method is_action_blocked]。
func is_action_blocked_raw(p_action_id: String, p_is_spatial: bool, p_pointer_pos: Vector2) -> bool:
	if _context_allows(p_action_id): return false
	if _context_blocks(p_action_id): return true
	if _ui_always_blocks(p_action_id): return true
	if p_is_spatial and p_pointer_pos != Vector2.INF:
		if _ui_pointer_blocks(p_action_id, p_pointer_pos): return true
	return false


# ============================================================
# 调试
# ============================================================

func get_block_reason(p_action_id: String, p_is_spatial: bool, p_pointer_pos: Vector2) -> String:
	if _context_allows(p_action_id): return "context_allow"
	if _context_blocks(p_action_id): return "context_block"
	if _ui_always_blocks(p_action_id): return "ui_always"
	if p_is_spatial and _ui_pointer_blocks(p_action_id, p_pointer_pos): return "ui_pointer"
	return ""


# ============================================================
# 内部
# ============================================================

func _context_allows(p_action_id: String) -> bool:
	for ctx in _context_stack:
		if ctx.allowed_actions.has(p_action_id):
			return true
	return false

func _context_blocks(p_action_id: String) -> bool:
	for ctx in _context_stack:
		if ctx.block_all_game_actions: return true
		if ctx.blocked_action_ids.has("*"): return true
		if ctx.blocked_action_ids.has(p_action_id): return true
	return false

func _ui_always_blocks(p_action_id: String) -> bool:
	if _ui_service == null: return false
	if _ui_service.is_dragging(): return false
	var panels: Array = _ui_service.get_active_panels()
	for panel in panels:
		var def = panel._panel_def
		if def == null: continue
		if def.input_block_mode != GF_UIPanelDef.InputBlockMode.ALWAYS: continue
		if def.blocked_action_ids.has("*") or def.blocked_action_ids.has(p_action_id):
			return true
	return false

func _ui_pointer_blocks(p_action_id: String, p_viewport_pos: Vector2) -> bool:
	if _ui_service == null: return false
	if _ui_service.is_dragging(): return false
	# 坐标系统一：InputEvent 的指针坐标是 viewport 空间，而面板命中检测
	# （Control.get_global_rect）是 canvas 空间——stretch/mode=canvas_items
	# 缩放窗口下两者不一致，必须换算（同 GF_UIDragManager._to_canvas 的坑，
	# 见 ui_drag_manager.gd:55-57 注释）。换算前不阻挡，会导致点击透传到地图。
	var canvas_pos := _to_canvas(p_viewport_pos)
	# 只检查 z 顺序最顶层的命中面板：窗口重叠时被遮挡区域不阻挡
	var top: GF_UIPanel = _ui_service.get_top_panel_at_position(canvas_pos)
	if top == null: return false
	var def = top._panel_def
	if def == null: return false
	if def.input_block_mode != GF_UIPanelDef.InputBlockMode.POINTER_ONLY: return false
	return def.blocked_action_ids.has("*") or def.blocked_action_ids.has(p_action_id)


## viewport 坐标 → canvas 坐标（与 GF_UIDragManager._to_canvas 同一换算）。
## 依赖 UI Root 的 make_canvas_position_local；无 UI 树时原样返回。
func _to_canvas(p_viewport_pos: Vector2) -> Vector2:
	if _ui_service == null or not _ui_service.has_method("get_ui_root"):
		return p_viewport_pos
	var ui_root: Control = _ui_service.get_ui_root()
	if ui_root == null or not ui_root.is_inside_tree():
		return p_viewport_pos
	return ui_root.make_canvas_position_local(p_viewport_pos)
