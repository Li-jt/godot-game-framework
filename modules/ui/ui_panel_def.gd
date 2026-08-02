## GF_UIPanelDef
## 面板定义。描述一个 UI 面板的类型、生命周期和行为策略。
## Game 层配置，GF_UIService 消费。
class_name GF_UIPanelDef
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
	PERSISTENT,        # 常驻，普通 close 不允许关闭（HUD）
	MANAGED_BY_FLOW,   # 流程托管，普通 close 不允许关闭（Loading、黑幕）
}

## 游戏输入阻挡模式。
enum InputBlockMode {
	NONE,          # 不阻挡游戏输入
	ALWAYS,        # 面板可见时阻挡指定游戏输入
	POINTER_ONLY,  # 鼠标位于面板区域内时才阻挡指定游戏输入
}

var name: String = ""
var path: String = ""
var kind: StringName = KIND_SCREEN
var lifecycle: Lifecycle = Lifecycle.DESTROY_ON_CLOSE

var prewarm: bool = false
var preview_data: Dictionary = {}

var singleton: bool = true
var layer_order: int = 0

## 游戏输入阻挡模式。默认 NONE。
var input_block_mode: InputBlockMode = InputBlockMode.NONE
## 阻挡的游戏动作 ID 列表。空 = 不挡任何动作。["*"] = 全挡（仅 cancel 放行）。
var blocked_action_ids: Array = []
## 面板打开后是否阻挡下层 UI 输入。
var close_on_escape: bool = true

## 此面板的焦点模式。默认 FOCUS_ALL。FOCUS_NONE = 此面板不参与键盘/手柄导航。
var focus_mode: Control.FocusMode = Control.FOCUS_ALL
## 面板打开后自动聚焦的控件路径。空 = 不自动聚焦。
var default_focus: NodePath = NodePath()
