## InputPolicy — 输入策略层（v4.0）。
## 统一判定"动作是否可通过"：Context + UI Panel + allowlist。
## 核心原则：按 action 级别判定，不按 event 级别。
class_name InputPolicy
extends RefCounted

var _context_stack: Array[InputContext] = []
## UIService 引用（只读）
var _ui_service = null  # UIService


func set_ui_service(p_ui) -> void:
	_ui_service = p_ui


func get_context_stack() -> Array[InputContext]:
	return _context_stack


## 判定指定动作是否被阻挡。
## p_event: 原始 Godot 事件
## p_pointer_pos: 指针位置（非空间事件为 Vector2.INF）
func is_action_blocked(p_action_id: String, p_event: InputEvent, p_pointer_pos: Vector2) -> bool:
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
		if ctx.allowed_action_ids.has(p_action_id):
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
	var panels: Array = _ui_service.get_active_panels()
	for panel in panels:
		var mode := panel.get_game_input_block_mode()
		if mode == 1:  # GAME_INPUT_BLOCK_ALWAYS
			var blocked: Array[String] = panel.get_blocked_action_ids()
			if blocked.has("*") or blocked.has(p_action_id):
				return true
	return false

func _ui_pointer_blocks(p_action_id: String, p_pos: Vector2) -> bool:
	if _ui_service == null: return false
	var panels: Array = _ui_service.get_active_panels()
	for panel in panels:
		var mode := panel.get_game_input_block_mode()
		if mode != 2: continue  # POINTER_ONLY
		var blocked: Array[String] = panel.get_blocked_action_ids()
		if not (blocked.has("*") or blocked.has(p_action_id)): continue
		if panel.is_pointer_over_game_input_blocking_area(p_pos):
			return true
	return false
