# UI 模块

GF_UIService 是框架的 UI 可选模块。启动时自动创建 CanvasLayer → UIRoot → 6 层 UI 画布，并挂到场景树。

## 注册（一行搞定）

```gdscript
class_name MyGame
extends GF_AppBootstrap

func _assemble() -> void:
    # 注册 UI 模块（需要同时注册其依赖）
    register(GF_InputService.new())
    register(GF_UIService.new())   # ← 就这一行

func _on_ready() -> void:
    var ui := service(GF_UIService) as GF_UIService
    # 注册面板定义
    ui.register_all([...])
    # 打开初始面板
    ui.open("main_hud")
```

## 自动创建的 UI 树

GF_UIService 在 `configure()` 中自动创建节点树并挂到 Bootstrap 下：

```text
Bootstrap (Node)
└── UiCanvas (CanvasLayer, layer=100) ← 自动创建
    └── UIRoot (Control, 全屏, mouse_filter=IGNORE)
        ├── HudLayer       ← 常驻 HUD（血条、小地图）
        ├── ScreenLayer    ← 全屏面板（背包、商城）
        ├── PopupLayer     ← 弹窗（确认框）
        ├── TooltipLayer   ← 提示（悬浮提示）
        ├── SystemLayer    ← 系统（加载界面、拖拽幽灵）
        └── DebugLayer     ← 调试（FPS 面板）
```

各层按 add_child 顺序形成 z-order，后添加的在上层。

## 面板设计

每个 UI 面板是**独立的 .tscn 文件**，在 Godot 编辑器中双击打开即可设计——不需要看到 UIRoot/层容器：

```text
inventory_panel.tscn
├── InventoryPanel (GF_UIPanel)       ← 根节点
│   ├── Background (ColorRect)
│   ├── Title (Label)
│   ├── Grid (GridContainer)
│   │   ├── Slot1 (GF_UIDragSlot)
│   │   └── ...
│   └── CloseButton (Button)
```

面板根节点必须继承 `GF_UIPanel`。

## 面板生命周期

通过 `GF_UIPanelDef` 声明面板的元数据和行为：

```gdscript
var def := GF_UIPanelDef.new()
def.name = "inventory"
def.path = "res://content/ui/inventory_panel.tscn"
def.kind = GF_UIPanelDef.KIND_SCREEN       # 路由到 ScreenLayer
def.lifecycle = GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE  # 关闭时缓存复用
def.input_block_mode = GF_UIPanelDef.InputBlockMode.ALWAYS
def.blocked_action_ids = ["*"]             # 打开时阻止所有游戏输入
def.close_on_escape = true                 # ESC 可关闭
```

| 生命周期 | 关闭行为 | 适用 |
|---------|---------|------|
| `DESTROY_ON_CLOSE` | `queue_free()` | 弹窗、确认框 |
| `HIDE_ON_CLOSE` | `hide()`，缓存复用（LRU 5个） | 背包、商城 |
| `PERSISTENT` | 普通 close 被拒绝 | HUD、玩家信息 |
| `MANAGED_BY_FLOW` | 普通 close 被拒绝 | Loading、黑幕 |

## 6 层 UI 的用途

| 层级 | 常量 | 典型面板 |
|------|------|---------|
| HudLayer | `GF_UIPanelDef.KIND_HUD` | 血条、小地图、快捷栏 |
| ScreenLayer | `GF_UIPanelDef.KIND_SCREEN` | 背包、商城、技能树 |
| PopupLayer | `GF_UIPanelDef.KIND_POPUP` | 确认框、物品详情 |
| TooltipLayer | `GF_UIPanelDef.KIND_TOOLTIP` | 鼠标悬浮提示 |
| SystemLayer | `GF_UIPanelDef.KIND_SYSTEM` | 加载界面、拖拽幽灵、全局通知 |
| DebugLayer | `GF_UIPanelDef.KIND_DEBUG` | FPS 面板、ECS 查看器 |

## 输入阻挡

面板通过 `UIPanelDef.game_input_block_mode` 声明阻挡策略：
- `GAME_INPUT_BLOCK_ALWAYS` — 打开即阻挡
- `GAME_INPUT_BLOCK_POINTER_ONLY` — 鼠标在面板区域内才阻挡

配合 `blocked_action_ids` 精确控制阻挡哪些游戏操作。

## 拖拽系统

三层设计：L1 协议层（UIDragManager + Handler）→ L2 便利层（UIDragSlot + SimpleDrag）→ L3 游戏层。

## 自定义 UI 层

如果 6 层不够，可以通过 `get_ui_root()` 获取根节点后手动添加：

```gdscript
var ui := service(GF_UIService) as GF_UIService
var my_layer := Control.new()
my_layer.name = "MyLayer"
ui.get_ui_root().add_child(my_layer)
```
