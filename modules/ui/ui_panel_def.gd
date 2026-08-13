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

## 构造面板定义。[param p_name] 和 [param p_path] 必填，其余可选。
## [codeblock]
## var def := GF_UIPanelDef.new("inventory", "res://ui/inventory.tscn",
##     GF_UIPanelDef.KIND_SCREEN, GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE)
## def.blocked_action_ids = ["*"]
## [/codeblock]
func _init(
	p_name: String,
	p_path: String,
	p_kind: StringName = KIND_SCREEN,
	p_lifecycle: Lifecycle = Lifecycle.DESTROY_ON_CLOSE,
	p_prewarm: bool = false,
	p_preview_data: Dictionary = {},
	p_singleton: bool = true,
	p_layer_order: int = 0,
	p_input_block_mode: InputBlockMode = InputBlockMode.NONE,
	p_blocked_action_ids: Array = [],
	p_close_on_escape: bool = true,
	p_focus_mode: Control.FocusMode = Control.FOCUS_ALL,
	p_default_focus: NodePath = NodePath(),
) -> void:
	name = p_name
	path = p_path
	kind = p_kind
	lifecycle = p_lifecycle
	prewarm = p_prewarm
	preview_data = p_preview_data
	singleton = p_singleton
	layer_order = p_layer_order
	input_block_mode = p_input_block_mode
	blocked_action_ids = p_blocked_action_ids
	close_on_escape = p_close_on_escape
	focus_mode = p_focus_mode
	default_focus = p_default_focus


## 从 Dictionary 创建面板定义。只传需要的字段即可。
## [codeblock]GF_UIPanelDef.from_dict({"name": "inventory", "path": "res://ui/inventory.tscn", "lifecycle": GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE})[/codeblock]
static func from_dict(p_data: Dictionary) -> GF_UIPanelDef:
	var def := GF_UIPanelDef.new(p_data.get("name", ""), p_data.get("path", ""))
	for key in p_data:
		if key in def and key != "name" and key != "path":
			def.set(key, p_data[key])
	return def

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


# ============================================================
# 窗口化配置（windowed = true 时生效，见 docs/design/ui-window-mode.md）
# ============================================================

## true = 面板以 Win11 风格窗口呈现（可拖动/缩放/点击置顶）。
## 场景根节点必须挂 GF_UIWindow 脚本，且 kind 必须为 KIND_SCREEN。
var windowed: bool = false
## 初始尺寸（像素，canvas 坐标系）。窗口根在编辑器的 size 仅作预览，运行时被此值覆盖。
var window_size: Vector2 = Vector2(800, 600)
## 缩放最小尺寸。打开时与 window_size 逐分量取 max。
var window_min_size: Vector2 = Vector2(320, 240)
## 多实例预留。v1 不支持：windowed && multi_instance 打开时直接失败。
var multi_instance: bool = false
