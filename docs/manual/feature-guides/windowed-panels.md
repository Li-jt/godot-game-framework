# 窗口化面板（Win11 风格多窗口）

## 场景描述

游戏需要 Win11 风格的多窗口体验：同时打开多个面板，每个窗口可随意拖动、缩放（内容随缩放自适应），点击哪个窗口哪个置顶，ESC 关闭当前焦点窗口。典型场景：策略游戏的多个信息面板、模拟经营类游戏的详情窗口。

本章覆盖：搭建窗口场景、注册并打开窗口面板、拖动/缩放能力、置顶与输入语义、样式定制。

> 设计文档：[docs/design/ui-window-mode.md](../../design/ui-window-mode.md)

---

## 核心概念

窗口化面板 = 普通面板 + 三个约定：

1. 面板场景的**根节点挂 `GF_UIWindow` 脚本**（它继承 `GF_UIPanel`，生命周期钩子照常用）
2. `GF_UIPanelDef.windowed = true`，kind 必须为 `KIND_SCREEN`
3. 能力由场景结构表达：拖入了 `drag_area` → 可拖动；子树中有 `GF_ResizeHandle` → 可缩放

框架不构建任何视觉节点——标题栏长什么样、手柄多宽、内容怎么布局，全部由你在编辑器决定。

## 最小示例

### 1. 搭建窗口场景

从框架模板起步：复制 `addons/godot-game-framework/scenes/ui/window_shell.tscn` 到你自己的目录（如 `content/ui/windows/`），重命名为你的面板名。模板结构：

```
MyDetailWindow (Control, script: GF_UIWindow)   ← 根节点
├── TitleBar (PanelContainer)                    ← 拖入根节点的 drag_area 字段
│   └── TitleLabel (Label)
├── ContentBox (MarginContainer)                 ← 你的内容放这里
│   └── ... 你的面板内容
└── ResizeEdge × 8 (Control, script: GF_ResizeHandle)  ← 四边四角，Inspector 选方向
```

也可以不复制模板，自己搭：根 Control 挂 `GF_UIWindow` 脚本，把标题栏节点拖进 `drag_area` 字段，边缘放 Control 挂 `GF_ResizeHandle` 脚本并选方向。

### 2. 注册并打开

```gdscript
# 注册
var def := GF_UIPanelDef.new()
def.name = "detail_window"
def.path = "res://content/ui/windows/my_detail_window.tscn"
def.kind = GF_UIPanelDef.KIND_SCREEN   # windowed 必须用 KIND_SCREEN
def.lifecycle = GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE
def.windowed = true
def.window_size = Vector2(640, 420)    # 运行时初始尺寸（覆盖编辑器里的 size）
def.window_min_size = Vector2(280, 200)
ui_service.register(def)

# 打开（与普通面板完全一样）
ui_service.open("detail_window")
```

窗口自动居中并随已开窗口数错开排列。

## 拖动与缩放

| 能力 | 开启方式 | 关闭方式 |
|---|---|---|
| 拖动 | 根节点 `drag_area` 字段拖入标题栏 | `drag_area` 保持 null |
| 缩放 | 子树挂 `GF_ResizeHandle`（每个手柄 Inspector 里选方向） | 不放手柄，或删掉部分手柄（如固定高度窗口删 TOP/BOTTOM） |

- 拖动/缩放中窗口自动置顶
- 拖出屏幕时窗口自动钳制：标题栏始终保留 32px 在屏幕内
- 缩放下限由 `def.window_min_size` 控制
- 内容自适应**零框架代码**：窗口尺寸变化 → 容器布局自动 reflow。窗口内容必须用容器布局（BoxContainer / GridContainer / ScrollContainer 等），不要用绝对定位写死控件坐标

## 置顶与焦点

- 点击窗口**任意处**（标题栏、内容、空白区）→ 窗口置顶（视觉 + ESC 顺序 + drop 命中顺序三者同步）
- ESC 关闭当前焦点窗口（`close_top` 逻辑自动跟随）
- 焦点切换时窗口发射 `focused` / `unfocused` 信号——订阅后切换标题栏样式（非焦点窗口标题栏变灰）：

```gdscript
# 窗口脚本内
func _ready() -> void:
    focused.connect(_on_focused)
    unfocused.connect(_on_unfocused)

func _on_focused() -> void:
    $TitleBar.modulate = Color(1, 1, 1)

func _on_unfocused() -> void:
    $TitleBar.modulate = Color(0.7, 0.7, 0.7)
```

## 样式定制

窗口 chrome 是普通节点，用 Godot 常规手段定制：

- 标题栏换 StyleBox（theme 覆盖）、改高度、加按钮（最小化/最大化/关闭按钮自己挂逻辑）
- 手柄改宽度、换光标（`mouse_default_cursor_shape`）
- 模板的默认深色标题栏只是占位，随意替换

## 约束与注意事项

| 项 | 说明 |
|---|---|
| 场景根类型 | 必须挂 `GF_UIWindow` 脚本，否则打开时返回 `ERR_BAD_REQUEST` |
| kind | 必须 `KIND_SCREEN`（窗口化语义只存在于 screen 级） |
| 窗口层 | windowed 面板统一渲染在 window 层（screen 之上、popup 之下），HUD/tooltip/system 等固定层面板始终在窗口层之上或之下，符合"系统通知压过桌面窗口"的语义 |
| 顶部 8px 重叠区 | 窗口最顶 8px 是 resize 区（手柄 z 序高于标题栏），其下才是拖动区——Windows 标准行为 |
| 内容布局 | 内容必须用容器布局才能随缩放自适应；极端内容放 ScrollContainer |
| 输入阻挡 | `input_block_mode` 语义不变；窗口重叠时 POINTER_ONLY 只按**顶层命中窗口**判定（被遮挡区域不算） |
| 多实例 | v1 不支持同 def 多实例，`windowed && multi_instance` 打开时直接失败 |
| 位置记忆 | HIDE_ON_CLOSE 窗口关闭再打开保留位置/尺寸（内存级）；持久化存档可通过 `move_finished` / `resize_finished` 信号自行实现 |

## 与 item 拖拽共存

窗口拖动/缩放与物品拖拽（UIDragSlot → UIDropTarget）手势区域不重叠：标题栏和边缘手柄用 `MOUSE_FILTER_STOP` 拦截，内容区的 item 拖拽照常工作；drop hit-test 按窗口 z 顺序从顶层窗口向下匹配。
