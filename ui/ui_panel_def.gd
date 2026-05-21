## UIPanelDef
## 面板定义。描述一个 UI 面板的类型、生命周期和行为策略。
## Game 层配置，UIService 消费。
class_name UIPanelDef
extends RefCounted

enum PanelKind {
	HUD,      # 常驻 HUD：用户信息、资源栏、小地图
	SCREEN,   # 游戏内主面板：背包、商城、角色面板
	POPUP,    # 弹窗：确认框、奖励弹窗
	TOOLTIP,  # 提示：物品说明、技能说明
	SYSTEM,   # 系统：Loading、黑幕、断线重连
	DEBUG,    # 调试面板
}

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
var kind: PanelKind = PanelKind.SCREEN
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
