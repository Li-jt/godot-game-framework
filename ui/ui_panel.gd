## UIPanel
## 所有游戏 UI 面板的基类。Game 层的面板脚本继承此类。
##
## 字段：
##   panel_name  — 面板名称，由 UIService 在 open 时赋值
##   ctx         — GameServices 上下文，由 UIService 在实例化后自动注入
##
## 生命周期（由 UIService 调用，子类重写带下划线的方法）：
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
##   extends UIPanel
##
##   func _on_open(p_data: Dictionary) -> void:
##       $Label.text = str(p_data.get("id", ""))
##       ctx.log.info("面板打开")  # 直接使用 self.ctx
##   [/codeblock]
class_name UIPanel
extends Control

## 由 UIService 在 open 时设置，用于反向查找面板定义
var panel_name: String = ""
## v4.0：输入阻挡模式（由 UIService 从 UIPanelDef 注入）
var _ui_block_mode: int = 0
## v4.0：阻挡的动作 ID 列表
var _blocked_action_ids: Array = []
## v4.0：始终放行的动作 ID 列表
var _allowed_action_ids: Array = []


func set_input_block_config(p_mode: int, p_blocked: Array, p_allowed: Array) -> void:
	_ui_block_mode = p_mode
	_blocked_action_ids = p_blocked.duplicate()
	_allowed_action_ids = p_allowed.duplicate()

## GameServices 上下文。由 UIService 在面板实例化后自动注入。
## 子类在 _on_open / _on_reopen 中可直接使用。
var ctx: UiContext = null


## SceneFactory 钩子：实例化后自动调用。p_data 为 SceneFactory.create() 传入的 init_data。
func _on_factory_init(_p_data: Dictionary) -> void:
	pass


## 先填数据再显示，避免空面板闪烁。子类不要重写。
func open(p_data: Dictionary = {}) -> void:
	_on_open(p_data)
	show()


## 重新打开已缓存面板。先填数据再显示。子类不要重写。
func reopen(p_data: Dictionary = {}) -> void:
	_on_reopen(p_data)
	show()


## UIService 调用。子类不要重写。
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


# ============================================================
# v4.0：InputPolicy 查询接口（子类按需覆写）
# ============================================================

## 返回此面板的输入阻挡模式（GAME_INPUT_BLOCK_*）。
## 默认从 UIPanelDef 读取，子类一般不需要覆写。
func get_game_input_block_mode() -> int:
	return _ui_block_mode


func get_blocked_action_ids() -> Array:
	return _blocked_action_ids


func get_allowed_action_ids() -> Array:
	return _allowed_action_ids
