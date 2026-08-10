## GF_UIPanel
## 所有游戏 UI 面板的基类。Game 层的面板脚本继承此类。
##
## 生命周期（由 GF_UIService 调用，子类重写带下划线的方法）：
##
##   destroy 策略（默认）：
##     实例化 → _bootstrap 注入 → _on_factory_init(data) → open(data) → _on_open(data)
##     close() → _on_close() → queue_free
##
##   cache 策略：
##     首次实例化 → _bootstrap 注入 → open(data) → _on_open(data)
##     关闭 → _on_hide() → hide（留在内存）
##     再次 open(data) → _on_reopen(data) → show
##     缓存满被回收 → _on_close() → queue_free
##
## 使用方式：
##   [codeblock]
##   class_name ItemDetailPanel
##   extends GF_UIPanel
##
##   func _on_open(p_data: Dictionary) -> void:
##       $Label.text = str(p_data.get("id", ""))
##       _bootstrap.service(GF_LogService).info("面板打开")
##   [/codeblock]
class_name GF_UIPanel
extends Control

## 由 GF_UIService 在 open 时设置，用于反向查找面板定义
var panel_name: String = ""

## 面板定义引用（由 GF_UIService 在 open 时注入）。GF_InputPolicy 直接读取。
var _panel_def: GF_UIPanelDef = null

## 焦点模式（由 GF_UIService 打开面板时注入）
var _focus_mode: Control.FocusMode = Control.FOCUS_ALL
## 默认焦点控件路径（由 GF_UIService 打开面板时注入）
var _default_focus_path: NodePath = NodePath()


## 注入焦点配置（由 GF_UIService 在 open 时调用）。
func set_focus_config(p_mode: Control.FocusMode, p_default_focus: NodePath) -> void:
	_focus_mode = p_mode
	_default_focus_path = p_default_focus


## GF_AppBootstrap 引用。由 GF_UIService 在面板实例化后自动注入。
## 子类在 _on_open / _on_reopen 中通过 _bootstrap.service(GF_XxxService) 获取所需服务。
var _bootstrap: GF_AppBootstrap = null


## GF_SceneFactory 钩子：实例化后自动调用。p_data 为 GF_SceneFactory.create() 传入的 init_data。
func _on_factory_init(_p_data: Dictionary) -> void:
	pass


## 先填数据再显示，避免空面板闪烁。子类不要重写。
func open(p_data: Dictionary = {}) -> void:
	_on_open(p_data)
	_apply_focus_config()
	show()


## 重新打开已缓存面板。先填数据再显示。子类不要重写。
func reopen(p_data: Dictionary = {}) -> void:
	_on_reopen(p_data)
	_apply_focus_config()
	show()


## GF_UIService 调用。子类不要重写。
func close() -> void:
	_on_close()
	hide()
	queue_free()


## 隐藏面板（cache 策略专用）。子类不要重写。
func hide_panel() -> void:
	_on_hide()
	hide()


## 判断指定全局鼠标坐标是否位于会阻挡游戏输入的区域。
## 优先检查子控件的 [member Control.mouse_filter]：STOP → 阻挡，IGNORE → 穿透。
## 若无子控件命中，回退到面板自身矩形（向后兼容）。
func is_pointer_over_game_input_blocking_area(p_global_mouse_pos: Vector2) -> bool:
	if not visible:
		return false

	# 1. 递归查找鼠标下最顶层的子 Control（跳过 IGNORE）
	var hit := _find_control_at_position(self, p_global_mouse_pos)
	if hit != null:
		return hit.mouse_filter == Control.MOUSE_FILTER_STOP

	# 2. 无子控件命中 → 回退到面板自身矩形（向后兼容）
	return get_global_rect().has_point(p_global_mouse_pos)


## 递归查找 p_pos 下最顶层的可见 Control（跳过 MOUSE_FILTER_IGNORE 的控件）。
## 模拟 Godot 原生 GUI hit-test 规则：子节点逆序遍历（后渲染的在上层）。
func _find_control_at_position(p_from: Node, p_pos: Vector2) -> Control:
	var children := p_from.get_children()
	# 逆序遍历：后加入的子节点渲染在上层，优先命中
	for i in range(children.size() - 1, -1, -1):
		var child := children[i]
		if not (child is Control):
			continue
		var ctrl := child as Control
		if not ctrl.visible or ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if not ctrl.get_global_rect().has_point(p_pos):
			continue
		# 命中 → 递归检查子节点（孙子节点更上层）
		var deeper := _find_control_at_position(ctrl, p_pos)
		if deeper != null:
			return deeper
		return ctrl
	return null


# ============================================================
# 焦点导航
# ============================================================

## 根据全局配置和面板定义，递归设置子控件的 focus_mode，并自动聚焦 default_focus。
func _apply_focus_config() -> void:
	# 全局焦点默认值（从 Bootstrap 读取），面板通过 _focus_mode 只能降级
	var cfg: Control.FocusMode = _bootstrap.focus_navigation_default_mode if _bootstrap != null else Control.FOCUS_ALL
	var mode: Control.FocusMode = mini(cfg, _focus_mode)
	if mode == Control.FOCUS_NONE:
		return
	_set_children_focus_mode(self, mode)
	if not _default_focus_path.is_empty():
		var target := get_node_or_null(_default_focus_path)
		if target is Control:
			target.grab_focus()


## 递归设置所有 Control 子节点的 focus_mode。
func _set_children_focus_mode(p_node: Node, p_mode: Control.FocusMode) -> void:
	if p_node is Control:
		p_node.focus_mode = p_mode
	for child in p_node.get_children():
		_set_children_focus_mode(child, p_mode)


# ============================================================
# 子类重写
# ============================================================

func _on_open(_p_data: Dictionary) -> void:
	pass


## 重新打开时调用（仅在 cache 策略、非首次打开时触发）
func _on_reopen(_p_data: Dictionary) -> void:
	pass


func _on_close() -> void:
	pass


## 面板被隐藏时调用（仅在 cache 策略下触发），用于暂停轮询等
func _on_hide() -> void:
	pass
