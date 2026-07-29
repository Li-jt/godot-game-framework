## GF_UIPanel
## 所有游戏 UI 面板的基类。Game 层的面板脚本继承此类。
##
## 生命周期（由 GF_UIService 调用，子类重写带下划线的方法）：
##
##   destroy 策略（默认）：
##     实例化 → ctx 注入 → _on_factory_init(data) → open(data) → _on_open(data)
##     close() → _on_close() → queue_free
##
##   cache 策略：
##     首次实例化 → ctx 注入 → open(data) → _on_open(data)
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
##       ctx.log.info("面板打开")  # 直接使用 self.ctx
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


## GF_GameServices 上下文。由 GF_UIService 在面板实例化后自动注入。
## 子类在 _on_open / _on_reopen 中可直接使用。
var ctx: GF_UiContext = null


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
## 默认使用面板自身矩形；HUD 等非全屏交互面板可覆盖为更窄的阻挡区域。
func is_pointer_over_game_input_blocking_area(p_global_mouse_pos: Vector2) -> bool:
	return visible and get_global_rect().has_point(p_global_mouse_pos)


# ============================================================
# 焦点导航
# ============================================================

## 根据全局配置和面板定义，递归设置子控件的 focus_mode，并自动聚焦 default_focus。
func _apply_focus_config() -> void:
	var cfg: Control.FocusMode = ctx.config.ui.focus_navigation.default_mode
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
