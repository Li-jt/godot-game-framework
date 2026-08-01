# tests/unit/ui/test_ui_drag_manager.gd
## GF_UIDragManager 公共 API 单元测试。
## 验证封装修复：getters 替代直接访问私有字段。
extends GutTest

var _manager: GF_UIDragManager


func before_each() -> void:
	var mgr := GF_UIDragManager.new()
	add_child(mgr)
	_manager = mgr


func after_each() -> void:
	_manager.free()
	_manager = null


# ============================================================
# 初始状态
# ============================================================

func test_initial_state_no_event() -> void:
	assert_null(_manager.get_current_event(), "初始状态下 event 应为 null")


func test_initial_state_no_handler() -> void:
	assert_null(_manager.get_current_handler(), "初始状态下 handler 应为 null")


func test_initial_state_not_dragging() -> void:
	assert_false(_manager.is_dragging(), "初始状态下不应在拖拽中")


# ============================================================
# 拖拽中状态
# ============================================================

func test_after_begin_event_returns_event() -> void:
	var handler := _FakeDragHandler.new()
	_manager.begin(handler, Vector2(100, 200), MOUSE_BUTTON_LEFT, null)

	assert_not_null(_manager.get_current_event(), "begin 后 event 不应为 null")
	assert_eq(_manager.get_current_event().position, Vector2(100, 200))
	assert_eq(_manager.get_current_event().button, MOUSE_BUTTON_LEFT)


func test_after_begin_handler_returns_handler() -> void:
	var handler := _FakeDragHandler.new()
	_manager.begin(handler, Vector2.ZERO, MOUSE_BUTTON_LEFT, null)

	assert_eq(_manager.get_current_handler(), handler, "begin 后 handler 应可获取")


func test_is_dragging_true_after_begin() -> void:
	var handler := _FakeDragHandler.new()
	_manager.begin(handler, Vector2.ZERO, MOUSE_BUTTON_LEFT, null)

	assert_true(_manager.is_dragging(), "begin 后 is_dragging 应为 true")


# ============================================================
# 清理后状态
# ============================================================

func test_clear_drag_state_resets_all() -> void:
	var handler := _FakeDragHandler.new()
	_manager.begin(handler, Vector2(100, 200), MOUSE_BUTTON_LEFT, null)

	_manager.clear_drag_state()

	assert_null(_manager.get_current_event(), "clear 后 event 应为 null")
	assert_null(_manager.get_current_handler(), "clear 后 handler 应为 null")
	assert_false(_manager.is_dragging(), "clear 后 is_dragging 应为 false")


# ============================================================
# getter 方法存在性（契约测试）
# ============================================================

func test_get_current_event_method_exists() -> void:
	assert_true(_manager.has_method("get_current_event"))

func test_get_current_handler_method_exists() -> void:
	assert_true(_manager.has_method("get_current_handler"))

func test_is_dragging_method_exists() -> void:
	assert_true(_manager.has_method("is_dragging"))

func test_clear_drag_state_method_exists() -> void:
	assert_true(_manager.has_method("clear_drag_state"))


# ============================================================
# 辅助类
# ============================================================

class _FakeDragHandler extends GF_UIDragHandler:
	func on_begin_drag(_event: GF_UIDragEvent) -> void: pass
	func on_drag(_event: GF_UIDragEvent) -> void: pass
	func on_drop(_event: GF_UIDragEvent) -> bool: return true
	func on_end_drag(_event: GF_UIDragEvent) -> void: pass
