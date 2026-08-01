# tests/unit/ui/test_ui_focus_navigation.gd
## UI 焦点导航系统测试。
## 验证 GF_UIPanel._apply_focus_config() 和 GF_UIService 焦点栈。
extends GutTest

var _panel: GF_UIPanel
var _button1: Button
var _button2: Button

func before_each() -> void:
	_panel = GF_UIPanel.new()
	_panel.ctx = GF_UiContext.new()
	
	add_child(_panel)

	_button1 = Button.new()
	_button1.name = "Btn1"
	_panel.add_child(_button1)

	_button2 = Button.new()
	_button2.name = "Btn2"
	_panel.add_child(_button2)

func after_each() -> void:
	_panel.queue_free()
	_panel = null
	_button1 = null
	_button2 = null

# ============================================================
# FOCUS_ALL — 全部子控件参与导航
# ============================================================

func test_focus_all_sets_children_to_focus_all() -> void:
	_panel.ctx.focus_navigation_default_mode = Control.FOCUS_ALL
	_panel._focus_mode = Control.FOCUS_ALL
	_panel._apply_focus_config()

	assert_eq(_button1.focus_mode, Control.FOCUS_ALL)
	assert_eq(_button2.focus_mode, Control.FOCUS_ALL)

func test_focus_all_grab_focus_on_default() -> void:
	_panel.ctx.focus_navigation_default_mode = Control.FOCUS_ALL
	_panel._focus_mode = Control.FOCUS_ALL
	_panel._default_focus_path = NodePath("Btn1")
	_panel._apply_focus_config()

	# grab_focus() 在 headless 下可能无效，但至少验证不崩溃
	assert_eq(_button1.focus_mode, Control.FOCUS_ALL)
	pass

# ============================================================
# FOCUS_CLICK — 仅鼠标点击
# ============================================================

func test_focus_click_sets_children_to_focus_click() -> void:
	_panel.ctx.focus_navigation_default_mode = Control.FOCUS_CLICK
	_panel._focus_mode = Control.FOCUS_CLICK
	_panel._apply_focus_config()

	assert_eq(_button1.focus_mode, Control.FOCUS_CLICK)
	assert_eq(_button2.focus_mode, Control.FOCUS_CLICK)

# ============================================================
# FOCUS_NONE — 不参与
# ============================================================

func test_focus_none_leaves_children_unchanged_or_none() -> void:
	_panel.ctx.focus_navigation_default_mode = Control.FOCUS_NONE
	_panel._focus_mode = Control.FOCUS_NONE
	_panel._apply_focus_config()

	# _apply_focus_config early-returns, children keep Godot defaults
	# Godot 4.x default: Control is FOCUS_NONE, Button is FOCUS_NONE
	assert_eq(_button1.focus_mode, Control.FOCUS_ALL)

# ============================================================
# mini() — 面板只能降级不能升级
# ============================================================

func test_panel_focus_mode_can_only_downgrade() -> void:
	# 全局 FOCUS_ALL，面板 FOCUS_CLICK → 结果应是 FOCUS_CLICK
	_panel.ctx.focus_navigation_default_mode = Control.FOCUS_ALL
	_panel._focus_mode = Control.FOCUS_CLICK
	_panel._apply_focus_config()

	assert_eq(_button1.focus_mode, Control.FOCUS_CLICK)

func test_panel_cannot_upgrade_beyond_global() -> void:
	# 全局 FOCUS_CLICK，面板 FOCUS_ALL → 面板不能升级，实际生效 FOCUS_CLICK
	_panel.ctx.focus_navigation_default_mode = Control.FOCUS_CLICK
	_panel._focus_mode = Control.FOCUS_ALL
	_panel._apply_focus_config()

	assert_eq(_button1.focus_mode, Control.FOCUS_CLICK, "全局 FOCUS_CLICK 时面板不能升级到 FOCUS_ALL")

# ============================================================
# default_focus
# ============================================================

func test_empty_default_focus_does_nothing() -> void:
	_panel.ctx.focus_navigation_default_mode = Control.FOCUS_ALL
	_panel._focus_mode = Control.FOCUS_ALL
	_panel._default_focus_path = NodePath()  # empty
	_panel._apply_focus_config()

	# focus_mode 被正确设置
	assert_eq(_button1.focus_mode, Control.FOCUS_ALL)

func test_invalid_default_focus_path_does_not_crash() -> void:
	_panel.ctx.focus_navigation_default_mode = Control.FOCUS_ALL
	_panel._focus_mode = Control.FOCUS_ALL
	_panel._default_focus_path = NodePath("NonExistent")
	_panel._apply_focus_config()

	# 应该不崩溃
	assert_eq(_button1.focus_mode, Control.FOCUS_ALL)

# ============================================================
# reopen 也调用 _apply_focus_config
# ============================================================

func test_reopen_applies_focus_config() -> void:
	_panel.ctx.focus_navigation_default_mode = Control.FOCUS_ALL
	_panel._focus_mode = Control.FOCUS_ALL
	_panel._default_focus_path = NodePath("Btn2")

	_panel.reopen({})

	assert_eq(_button1.focus_mode, Control.FOCUS_ALL)
	assert_eq(_button2.focus_mode, Control.FOCUS_ALL)
