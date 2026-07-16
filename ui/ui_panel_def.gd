## UIPanelDef
## 面板定义。描述一个 UI 面板的类型、生命周期和行为策略。
## Game 层配置，UIService 消费。
class_name UIPanelDef
extends RefCounted

## 面板类型——StringName 常量。Mod 可自定义。
const KIND_HUD: StringName = &"hud"
const KIND_SCREEN: StringName = &"screen"
const KIND_POPUP: StringName = &"popup"
const KIND_TOOLTIP: StringName = &"tooltip"
const KIND_SYSTEM: StringName = &"system"
const KIND_DEBUG: StringName = &"debug"

enum Lifecycle {
	DESTROY_ON_CLOSE,  # 关闭时销毁（确认框、弹窗）
	HIDE_ON_CLOSE,     # 关闭时隐藏（背包、商城）
	PERSISTENT,        # 常驻，普通 close 不允许关闭（HUD、用户信息）
	MANAGED_BY_FLOW,   # 流程托管，普通 close 不允许关闭（Loading、黑幕）
}

enum GameInputBlockMode {
	NONE,          # 不阻挡游戏输入
	ALWAYS,        # 面板可见时阻挡指定游戏输入
	POINTER_ONLY,  # 鼠标位于面板阻挡区域时才阻挡指定游戏输入
}

var name: String = ""
var path: String = ""
var kind: StringName = KIND_SCREEN
var lifecycle: Lifecycle = Lifecycle.DESTROY_ON_CLOSE

var prewarm: bool = false
var preview_data: Dictionary = {}

var singleton: bool = true
var layer_order: int = 0
## 游戏输入阻挡模式。新代码优先使用此字段。
var game_input_block_mode: GameInputBlockMode = GameInputBlockMode.NONE
## 旧配置兼容字段。为 true 时等效于 game_input_block_mode = ALWAYS。
var blocks_game_input: bool = false
## 打开时屏蔽的动作 ID 列表。空 = 不屏蔽。["*"] = 全禁（仅 cancel 放行）。
var blocked_action_ids: Array = []
var blocks_ui_below: bool = false
var close_on_escape: bool = true
var modal: bool = false
