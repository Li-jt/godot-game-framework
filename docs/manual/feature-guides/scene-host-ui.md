# SceneHost UI 节点树

`GF_SceneHost` 是框架的场景宿主，管理世界挂载、相机和 6 层 UI Canvas。它的核心设计是**三级自动发现**：`@export 注入 → .tscn 已有节点 → 代码自动创建`。你可以从零配置开始，需要时逐步加控制。

---

## 快速开始（零配置）

在你的主场景中加一个节点，挂上 `GF_SceneHost` 脚本，不用建任何子节点：

```text
Main (Node)
├── YourBootstrap (Node, 挂你的 Bootstrap 脚本)
└── SceneHost (Node, 挂 GF_SceneHost 脚本)   ← 就这一个节点
```

运行项目，`GF_SceneHost._ready()` 自动建好完整节点树：

```text
SceneHost
├── WorldMount (Node2D)
├── GameCamera (Camera2D)
└── UiCanvas (CanvasLayer, layer=100)
    └── UIRoot (Control)
        ├── HudLayer       — HUD、血条、小地图
        ├── ScreenLayer    — 全屏面板（背包、商城）
        ├── PopupLayer     — 弹窗、确认框
        ├── TooltipLayer   — 提示条
        ├── SystemLayer    — 加载界面、通知
        └── DebugLayer     — 调试面板
```

不需要任何配置，直接就能用了。

---

## 方式二：在 .tscn 中搭建节点树

如果你希望在编辑器中**可视化编辑**节点树（比如给 GameCamera 调位置/zoom，给各层加背景），可以在 `.tscn` 中手动建好。SceneHost 发现子节点已存在就复用不复建。

### 步骤

**1.** 在场景中选中 `SceneHost` 节点，逐级添加子节点：

| 节点 | 类型 | 关键属性 |
|------|------|---------|
| WorldMount | Node2D | 默认 |
| GameCamera | Camera2D | position=(640,360), zoom=(1.5,1.5) |
| UiCanvas | CanvasLayer | layer=100 |
| UiCanvas/UIRoot | Control | 全屏铺满, mouse_filter=Ignore |
| UIRoot/HudLayer | Control | 全屏, mouse_filter=Ignore |
| UIRoot/ScreenLayer | Control | 全屏, mouse_filter=Ignore |
| UIRoot/PopupLayer | Control | 全屏, mouse_filter=Ignore |
| UIRoot/TooltipLayer | Control | 全屏, mouse_filter=Ignore |
| UIRoot/SystemLayer | Control | 全屏, mouse_filter=Ignore |
| UIRoot/DebugLayer | Control | 全屏, mouse_filter=Ignore |

**UIRoot 和各 Layer 的 Control 属性设置**：

```
Layout → Anchors Preset → Full Rect（铺满父节点）
Layout → Mouse Filter → Ignore（鼠标事件穿透到底层）
```

**2.** 保存场景，运行。SceneHost 的 `_build_default_tree()` 检测到 `WorldMount`、`GameCamera`、`UIRoot` 等节点已存在，跳过代码创建。

### 参考

框架自带的 `scenes/default_main.tscn` 就是一个完整的 .tscn 搭建示例，可以直接打开参考。

---

## 方式三：@export 注入（最灵活）

这是最灵活的方式：你在场景中自由搭建节点树，然后把节点**拖给 SceneHost 的导出变量槽位**。

### @export 怎么用

**1.** 选中 `SceneHost` 节点，在右侧 **Inspector（检查器）** 面板中，`GF_SceneHost` 脚本会展开以下导出变量：

| @export 变量 | 类型 | 作用 |
|---|---|---|
| `World Mount` | Node2D | 世界挂载点（场景、角色） |
| `Game Camera` | Camera2D | 主相机 |
| `Ui Canvas` | CanvasLayer | UI Canvas 层 |
| `Ui Root` | Control | UI 根节点 |
| `Hud Layer` | Control | HUD 层 |
| `Screen Layer` | Control | 全屏面板层 |
| `Popup Layer` | Control | 弹窗层 |
| `Tooltip Layer` | Control | 提示层 |
| `System Layer` | Control | 系统层 |
| `Debug Layer` | Control | 调试层 |

**2.** 在 Scene 面板中，用鼠标把节点**拖到 Inspector 中对应的槽位**：

```
1. 在场景树中点击你要注入的节点（比如你自己建的 Camera2D）
2. 按住拖到 Inspector 里 SceneHost 的 "Game Camera" 槽位
3. 松手 — 槽位显示节点的名称，注入完成
```

**3.** 不需要全部填满。填了几个就用几个，没填的 SceneHost 会在 `_build_default_tree()` 中自动创建。

### @export 注入 vs .tscn 搭建 对比

| | .tscn 搭建 | @export 注入 |
|---|---|---|
| 节点在场景树中 | ✅ 可见可编辑 | ✅ 可见可编辑 |
| 与 SceneHost 的父子关系 | 必须是 SceneHost 的子节点 | 可以在任意位置（拖入槽位即关联） |
| 自动创建补缺 | ✅ 已有则复用 | ✅ 已有则复用 |
| 适用场景 | 标准结构 | 自定义节点树（如相机用你自己的脚本） |

### 典型场景：自定义相机

```text
Main
├── YourBootstrap
├── SceneHost (GF_SceneHost)
└── MyGameCamera (Camera2D, 挂你的自定义脚本)
    # 你给 MyGameCamera 加了自己的脚本，
    # 有跟随逻辑、屏幕震动等
```

1. 把 `MyGameCamera` 拖到 SceneHost 的 `Game Camera` 槽位
2. SceneHost 不再创建默认的 Camera2D
3. 所有通过 `scene_host.get_camera()` 拿到的都是你的自定义相机

---

## 6 层 UI 的用途

每层是一个全屏 `Control`，按 add_child 顺序形成 z-order（后添加的在上层）：

| 层级 | 常量 | 用途 | 典型面板 |
|------|------|------|---------|
| HudLayer | `GF_UIPanelDef.KIND_HUD` | 常驻 HUD | 血条、小地图、快捷栏 |
| ScreenLayer | `GF_UIPanelDef.KIND_SCREEN` | 全屏界面 | 背包、商城、技能树 |
| PopupLayer | `GF_UIPanelDef.KIND_POPUP` | 弹窗 | 确认框、物品详情 |
| TooltipLayer | `GF_UIPanelDef.KIND_TOOLTIP` | 提示 | 鼠标悬浮提示 |
| SystemLayer | `GF_UIPanelDef.KIND_SYSTEM` | 系统级 | 加载界面、全局通知 |
| DebugLayer | `GF_UIPanelDef.KIND_DEBUG` | 调试 | FPS 面板、ECS 查看器 |

### 添加面板到指定层

在 Bootstrap 中通过 `SceneHost` 添加面板：

```gdscript
func _on_ready() -> void:
    var host := get_node("SceneHost") as GF_SceneHost
    host.load_ui_panel(GF_UIPanelDef.KIND_SCREEN, "res://scenes/ui/inventory_panel.tscn")
```

### BOSS说: 注册自定义层

如果 6 层不够用，可以添加自定义层：

```gdscript
var my_layer := Control.new()
my_layer.name = "MyCustomLayer"
ui_root.add_child(my_layer)

var host := get_node("SceneHost") as GF_SceneHost
host.register_ui_layer(&"custom", my_layer)
```

---

## GF_SceneHost 脚本在哪

脚本路径：`addons/godot-game-framework/engine/scene_host/scene_host.gd`

由于框架使用 `class_name GF_SceneHost` 全局注册，你在编辑器中可以通过以下方式使用：

- **添加节点**：点击 "+" 添加子节点 → 搜索 `GF_SceneHost`
- **手动挂脚本**：建一个 Node 节点 → Inspector → script 下拉 → 选 `GF_SceneHost`

挂上脚本后，Inspector 中就会出现上面列出的 @export 槽位。

---

## 总结

| 你的需求 | 做法 |
|---------|------|
| 快速跑起来 | 加个空 SceneHost 节点，挂上 GF_SceneHost 脚本，完事 |
| 我要在编辑器里看到 UI 层级 | 在 .tscn 中手动建好节点树（参考 `default_main.tscn`） |
| 我要用自己的相机/自定义层 | 建好节点 → 拖到 SceneHost 的 @export 槽位 |
| 我要加第 7 层 UI | `register_ui_layer()` |
