# GF_UIPanelDef

> 适用版本: 0.3.0 | 继承: GF_UIPanelDef → RefCounted

## 概述

面板定义。描述一个 UI 面板的类型、生命周期和行为策略。由 Game 层创建和配置，GF_UIService 消费。不包含任何运行时状态，仅描述面板的元数据。

**何时使用：** 在 Game 层注册面板时创建并填充各字段。

**何时不使用：** 运行时面板状态管理 — 那是 GF_UIPanel 的职责。

## 枚举

### Lifecycle

面板生命周期策略，决定面板关闭时的行为。

| 枚举值 | 描述 |
|--------|------|
| DESTROY_ON_CLOSE | 关闭时销毁（`queue_free()`）。适用于弹窗、确认框、一次性界面。 |
| HIDE_ON_CLOSE | 关闭时隐藏（保留在内存中，缓存复用）。适用于背包、商城等频繁打开的界面。最大缓存 5 个，LRU 淘汰。 |
| PERSISTENT | 常驻面板。普通 `close()` 被拒绝，只能通过 `force_close()` 或 `clear_all_ui()` 关闭。适用于 HUD、小地图。 |
| MANAGED_BY_FLOW | 流程托管面板。普通 `close()` 被拒绝，由 AppFlow 状态机决定何时关闭。适用于 Loading、黑幕过渡。 |

### InputBlockMode

游戏输入阻挡模式。控制面板打开时是否阻挡游戏层的输入。

| 枚举值 | 描述 |
|--------|------|
| NONE | 不阻挡游戏输入。游戏层和 UI 层输入可同时响应。 |
| ALWAYS | 面板可见时始终阻挡 `blocked_action_ids` 中指定的游戏动作。 |
| POINTER_ONLY | 仅当鼠标位于面板区域内时才阻挡游戏输入。适用于非全屏的 HUD 面板。 |

## 常量

| 常量 | 类型 | 值 | 描述 |
|------|------|-----|------|
| KIND_HUD | StringName | `&"hud"` | HUD 层面板（血条、小地图、状态栏）。常驻，位于最底层。 |
| KIND_SCREEN | StringName | `&"screen"` | 全屏界面层（背包、商城、设置）。位于 HUD 之上。 |
| KIND_POPUP | StringName | `&"popup"` | 弹窗层（确认框、提示框、详情弹窗）。位于 SCREEN 之上。 |
| KIND_TOOLTIP | StringName | `&"tooltip"` | 提示层（悬浮提示、物品信息）。位于 POPUP 之上。 |
| KIND_SYSTEM | StringName | `&"system"` | 系统层（通知、拖拽视觉）。最顶层，在所有面板之上。 |
| KIND_DEBUG | StringName | `&"debug"` | 调试层（调试面板、性能监视器）。位于 SYSTEM 之上。 |

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| name | String | "" | 面板唯一名称。用作 GF_UIService 的 key，`open()` / `close()` 的参数。必须非空。 |
| path | String | "" | 面板场景文件路径（如 `"res://src/ui/inventory_panel.tscn"`）。通过 SceneHost 加载。必须非空。 |
| kind | StringName | KIND_SCREEN | 面板所属 UI 层，决定 Z-order 渲染顺序。使用 KIND_* 常量。 |
| lifecycle | Lifecycle | DESTROY_ON_CLOSE | 面板关闭策略。 |
| prewarm | bool | false | 是否在 `register_all()` 后预加载。仅对 HIDE_ON_CLOSE 和 PERSISTENT 面板生效。 |
| preview_data | Dictionary | {} | 预热时传给 `open()` 的初始数据。用于填充面板默认内容后隐藏。 |
| singleton | bool | true | 是否为单例面板。true 时重复 `open()` 会 `reopen()` 现有实例而非创建新的。 |
| layer_order | int | 0 | 面板在同层内的排序权重。数值小的排前面（渲染在下层）。 |
| input_block_mode | InputBlockMode | NONE | 游戏输入阻挡模式。 |
| blocked_action_ids | Array | [] | 阻挡的游戏动作 ID 列表。空数组 = 不阻挡。`["*"]` = 阻挡所有（仅 cancel 放行）。 |
| close_on_escape | bool | true | ESC 键是否可关闭此面板。false 时 `close_top()` 会跳过此面板。 |
| focus_mode | Control.FocusMode | FOCUS_ALL | 面板内控件的焦点模式。FOCUS_NONE = 此面板不参与键盘/手柄导航。 |
| default_focus | NodePath | NodePath() | 面板打开后自动聚焦的控件路径。空路径表示不自动聚焦。 |

## 示例

```gdscript
# 注册一个 HIDE_ON_CLOSE 的背包面板
var inv_def := GF_UIPanelDef.new()
inv_def.name = "inventory"
inv_def.path = "res://src/ui/inventory_panel.tscn"
inv_def.kind = GF_UIPanelDef.KIND_SCREEN
inv_def.lifecycle = GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE
inv_def.input_block_mode = GF_UIPanelDef.InputBlockMode.ALWAYS
inv_def.blocked_action_ids = ["*"]   # 打开时阻挡所有游戏操作
inv_def.close_on_escape = true
inv_def.prewarm = true               # 注册后预加载

# 注册一个 PERSISTENT HUD
var hud_def := GF_UIPanelDef.new()
hud_def.name = "hud"
hud_def.path = "res://src/ui/hud.tscn"
hud_def.kind = GF_UIPanelDef.KIND_HUD
hud_def.lifecycle = GF_UIPanelDef.Lifecycle.PERSISTENT
hud_def.input_block_mode = GF_UIPanelDef.InputBlockMode.POINTER_ONLY
hud_def.blocked_action_ids = ["interact"]  # 鼠标在 HUD 上时阻挡交互
hud_def.close_on_escape = false
hud_def.focus_mode = Control.FOCUS_NONE     # HUD 不参与焦点导航
```

## See Also

- [GF_UIService](gf_ui_service.md) — 消费面板定义的 UI 管理服务
- [GF_UIPanel](gf_ui_panel.md) — 面板实例基类
- GF_SceneHost — 场景加载宿主（通过 path 加载面板场景）
