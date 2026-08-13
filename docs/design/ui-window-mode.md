# UI 窗口模式（Win11 风格多窗口）设计文档

> 状态：**设计定稿，未实现**
> 修订记录：v2 — 窗口结构改为"编辑器搭建 + @export 槽位"（原 v1 代码构建 chrome + 包装器方案已废弃，见文末变更说明）
> 关联模块：[modules/ui/](../../modules/ui/)
> 关联手册：[创建和管理 UI 面板](../manual/feature-guides/create-ui-panels.md)

## 1. 概述

### 1.1 需求

在现有 UI 面板系统之上，提供 Win11 风格的多窗口体验：

1. 多个窗口面板同时打开
2. 窗口可随意拖动
3. 窗口可随意缩放，内容随缩放自适应
4. 点击哪个窗口，哪个窗口置顶
5. ESC 关闭当前焦点窗口

### 1.2 目标与非目标

**目标（v1）**

- 窗口结构（标题栏、边缘手柄）在 **Godot 编辑器**中搭建，框架只提供交互逻辑（脚本）与开箱模板，样式/布局完全由 Game 层掌控
- 窗口化能力通过 `GF_UIPanelDef` 配置开关，普通面板路径完全不受影响
- 与现有 6 层 Canvas 架构、拖拽系统（item drag）、输入阻挡、面板缓存全部兼容
- 窗口位置/尺寸在 HIDE_ON_CLOSE 缓存下自然保留（内存级记忆）

**非目标（v1 不做）**

- 同一定义面板的多实例（见 [第 8 节 v2 预留](#8-v2-预留多实例)）
- 最小化/最大化按钮、窗口布局持久化到存档
- 使用 Godot 原生 `Window` 类（嵌入 SubViewport 与 CanvasLayer 架构、焦点系统摩擦大，样式定制反而受限）
- 编辑器内运行预览（@tool）——窗口初始位置/尺寸在运行时由 Service 注入

## 2. 现状分析

| Win11 需求 | 现状 | 缺口 |
|---|---|---|
| 多面板同时打开 | 已有。`_active_panels` 为 Dictionary，不同 def 可并存 | 同 def 多实例不支持（key 是 String name） |
| 点击置顶 | 半有。`_bring_to_front()` 只更新 `_open_order`（影响 ESC 顺序、drop hit-test 顺序），**不改视觉渲染顺序** | 视觉 z 由 `_apply_layer_order` 按 `def.layer_order` 静态排序 |
| 窗口拖动 | 无。现有拖拽系统是 **item 数据拖拽**（UIDragSlot → UIDropTarget + ghost） | 需新增窗口级拖动手势 |
| 窗口缩放 | 无 | 需新增 resize 手柄 |
| 内容随缩放自适应 | Godot 容器布局天然支持 | 前提：面板内容用 Container 布局（文档约束） |

### 2.1 与现有系统的冲突点及对策

| 冲突点 | 对策 |
|---|---|
| 6 层固定 z（hud < screen < popup < …）阻碍跨层置顶 | 新增独立 `window` 层，窗口面板统一路由到该层，层内自由 z-order；非窗口面板维持固定层语义（对应 Win11 中"桌面窗口"与"系统通知"的关系） |
| 逻辑 z（`_open_order`）与视觉 z（child 顺序）分离 | `focus_window()` 同时执行 `move_child` 置顶 + `_bring_to_front`，两者绑定 |
| POINTER_ONLY 输入阻挡在窗口重叠时误判（平面 rect 判断） | 按 z 顺序取顶层命中面板，只判顶层 |
| 窗口场景根 anchors 由 Game 层任意设置 | 打开时框架强制 `PRESET_TOP_LEFT`（窗口定位语义要求），覆盖场景配置 |

**不需要担心的**：item 拖拽与窗口拖动手势区域不重叠（标题栏/边缘 `MOUSE_FILTER_STOP` 拦截 vs 内容区），天然共存；ESC 关闭语义在置顶同步 `_open_order` 后自然正确。

## 3. 架构设计

### 3.1 核心决策

**窗口场景的根节点挂 `GF_UIWindow` 脚本，窗口结构（标题栏/手柄/内容）由 Game 层在编辑器搭建；框架提供交互逻辑与开箱模板。**

```
Game 层（编辑器搭建，scenes/ui/window_shell.tscn 模板起步）
┌──────────────────────────────────────────┐
│ WindowRoot (Control, script: GF_UIWindow)│ ← 服务端校验根节点类型
│  ├ TitleBar（@export drag_area 拖入）    │    框架接管拖动 + 置顶
│  ├ ContentBox（任意容器布局）             │    内容自适应由 Godot 容器完成
│  │   └ ... Game 内容                     │
│  └ ResizeEdge × 8（script: GF_ResizeHandle，Inspector 选方向）
└──────────────────────────────────────────┘
                    │
GF_UIService        │  def.windowed = true
                    ▼
   实例化 → 校验根 is GF_UIWindow → 强制 TOP_LEFT → 设初始尺寸/位置
   → 挂 window 层 → _active_panels[name] = 窗口根（无包装层）
```

**为什么是"根节点挂脚本"而不是"框架代码构建 chrome"**（v1 方案已废弃）：

- Game 的窗口都在编辑器创建，chrome 代码构建则不可见、不可预览、改样式只能靠 theme 覆盖
- `@export` 节点槽是 Godot 标准工作流：拖入即装配，不拖即禁用该能力（拖动/缩放能力由场景结构表达，结构即配置）
- 废弃后整个包装器消失：`attach_content` / 生命周期转发 / `window_host` 反向引用 / hit-test 适配 / `_apply_focus_config` 覆写全部不需要——窗口根**就是**面板，`target.panel == 窗口根` 天然匹配，`default_focus` 路径天然相对窗口根

**为什么窗口拖动不复用 GF_UIDragManager**：UIDragManager 是 item 拖拽协议（ghost + 全量 drop-target hit-test + hover 回调），窗口拖动只需持续更新 position。复用带来每帧无谓 O(n) hit-test 和误触发回调。窗口手势用 `_gui_input` + 本地坐标实现，同时绕开 viewport/canvas 坐标换算问题（`_to_canvas`，见 [ui_drag_manager.gd](../../modules/ui/ui_drag_manager.gd)）。

### 3.2 层插入位置

`_create_ui_tree` 创建顺序即渲染顺序（从底到顶）：`hud → screen → window → popup → tooltip → system → debug`。

## 4. 详细设计

### 4.1 GF_UIPanelDef 扩展（修改 [ui_panel_def.gd](../../modules/ui/ui_panel_def.gd)）

新增字段**不进 `_init()` 位置参数**（已有 13 个），用 `from_dict()` 或属性赋值配置，全部默认关闭、向后兼容：

```gdscript
## true = 面板以 Win11 风格窗口呈现。场景根节点必须挂 GF_UIWindow 脚本。
var windowed: bool = false
## 初始尺寸（像素，canvas 坐标系）。窗口根在编辑器的 size 仅作预览，运行时被此值覆盖。
var window_size: Vector2 = Vector2(800, 600)
## 缩放最小尺寸。
var window_min_size: Vector2 = Vector2(320, 240)
## 多实例预留。v1 不支持：windowed && multi_instance 打开时 fail fast。
var multi_instance: bool = false
```

约束校验：`windowed=true` 的面板必须使用 `KIND_SCREEN`，其余 kind 打开时返回 `ERR_BAD_REQUEST`（窗口化语义只存在于 screen 级）。

`from_dict()` 是纯字段遍历，新字段自动生效，无需改动。

### 4.2 GF_UIWindow（新增 [ui_window.gd](../../modules/ui/ui_window.gd)，~250 行）

挂到 Game 层窗口场景的根节点。**只含交互逻辑，不含任何视觉节点**——窗口结构由 Game 在编辑器搭建。

```gdscript
class_name GF_UIWindow
extends GF_UIPanel

## 拖动/缩放结束时发射（存档窗口布局用）。
signal moved(new_position: Vector2)
signal resized(new_size: Vector2)
## 焦点变化时发射（非焦点窗口标题栏变灰等视觉由 Game 层订阅定制）。
signal focused
signal unfocused

## 编辑器拖入：窗口拖动手柄区域（通常是标题栏）。null = 窗口不可拖动。
@export var drag_area: Control = null

# —— 内部状态 ——
var _is_moving := false
var _drag_grab_offset := Vector2.ZERO
var _resize_handles: Array[GF_ResizeHandle] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS   # 让冒泡点击进 _gui_input（置顶兜底通道）
    _discover_resize_handles()
    if drag_area != null:
        drag_area.gui_input.connect(_on_drag_area_input)
```

#### 4.2.1 拖动（drag_area `gui_input`，全本地坐标）

```gdscript
func _on_drag_area_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
            _is_moving = true
            _drag_grab_offset = mb.position   # drag_area 本地坐标
            _notify_focus_requested()        # press 即置顶（Win11 语义）
        elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
            _is_moving = false
            moved.emit(position)
    elif event is InputEventMouseMotion and _is_moving:
        var mm := event as InputEventMouseMotion
        position += mm.position - _drag_grab_offset   # 相对增量，无累计误差
        _clamp_position()
```

- 增量式 `position += delta`，全本地坐标，不涉及 viewport/canvas 换算
- `_clamp_position()`：标题栏始终保留在父层 Control 可视区内（父层是 FULL_RECT，其 size 即 canvas 逻辑尺寸，坐标自洽），防拖丢
- 文档建议 drag_area 保持 `MOUSE_FILTER_STOP`（Godot 默认），避免标题栏点击穿透到游戏

#### 4.2.2 点击置顶（双通道，Win11 语义：点任意处都置顶）

- **通道 1**：`_ready` 连接 `get_viewport().gui_focus_changed`。`_apply_focus_config` 已把窗口子树全部设为 FOCUS_ALL，点击可聚焦控件必触发 focus；从焦点 owner 向上找祖先 GF_UIWindow → 通知 Service 置顶
- **通道 2**：窗口根 `_gui_input` 收到 LEFT press（点 Label、空白区等不可聚焦处，经 PASS 冒泡上来）→ 通知 Service 置顶
- 内容里 `STOP` 控件消费的事件到不了通道 2，但必走通道 1，两者互补无遗漏

统一走 `_notify_focus_requested()` → `_bootstrap.service(GF_UIService).focus_window(panel_name)`。

#### 4.2.3 缩放手柄发现

```gdscript
func _discover_resize_handles() -> void:
    _resize_handles = []
    for child in find_children("*", "GF_ResizeHandle", true, false):
        _resize_handles.append(child as GF_ResizeHandle)
```

手柄脚本 `_ready` 自动向上找祖先窗口，无需导出 8 个字段。

### 4.3 GF_ResizeHandle（新增 [ui_resize_handle.gd](../../modules/ui/ui_resize_handle.gd)，~120 行）

挂到窗口场景中的 8 个边缘 Control（或框架模板实例）。每个手柄一个方向：

```gdscript
class_name GF_ResizeHandle
extends Control

## 位标志：LEFT=1, RIGHT=2, TOP=4, BOTTOM=8；角方向 = 两个边方向的组合。
## 编辑器 Inspector 中下拉选择（枚举类型自动生成下拉）。
@export var edge: Edge = Edge.RIGHT

enum Edge {
    LEFT = 1, RIGHT = 2, TOP = 4, BOTTOM = 8,
    TOP_LEFT = 5, TOP_RIGHT = 6, BOTTOM_LEFT = 9, BOTTOM_RIGHT = 10,
}

var _window: GF_UIWindow = null
var _press_size := Vector2.ZERO
var _press_mouse := Vector2.ZERO   # 窗口本地坐标
var _is_resizing := false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_default_cursor_shape = _cursor_for(edge)   # 悬停自动变光标，Godot 原生支持
    _window = _find_window()                          # 沿父链向上找 GF_UIWindow

func _gui_input(event: InputEvent) -> void:
    # press：记录 _press_size = _window.size；_press_mouse = mb.position + position（窗口本地）；通知窗口置顶
    # motion（按下状态）：_apply_resize(mm.position + position)
    # release：_window.resized.emit(_window.size)

func _apply_resize(p_mouse_local: Vector2) -> void:
    var delta := p_mouse_local - _press_mouse
    var new_size := _press_size
    var new_pos := _window.position
    var min_size: Vector2 = _window._panel_def.window_min_size if _window._panel_def != null else MIN_FALLBACK_SIZE
    if _edge & Edge.LEFT:   # LEFT / TOP_LEFT / BOTTOM_LEFT
        new_size.x = maxf(min_size.x, _press_size.x - delta.x)
        new_pos.x = _window.position.x + (_press_size.x - new_size.x)
    if _edge & Edge.RIGHT:
        new_size.x = maxf(min_size.x, _press_size.x + delta.x)
    # TOP / BOTTOM 同理（y 轴）
    _window.size = new_size
    _window.position = new_pos
```

- N/W 方向缩放时 position 同步收缩（保持对角锚定）
- 8 个手柄共用同一段逻辑（位标志组合判断），窗口缩放时手柄锚定在窗口边缘自动跟随
- **内容自适应零框架代码**：窗口 size 变 → Game 的容器布局自动 reflow。文档约束"窗口内容必须用容器布局"

### 4.4 开箱模板（新增 [scenes/ui/window_shell.tscn](../../scenes/ui/window_shell.tscn)）

框架提供窗口骨架场景，Game 复制到自己的窗口场景做起点（或 Instance 为子场景）。纯框架内容，无任何游戏业务名词：

```
WindowShell (Control, script: GF_UIWindow, anchors 任意→运行时被强制 TOP_LEFT)
├── TitleBar (PanelContainer, 顶部铺满, 高 32px)
│   └── TitleLabel (Label, 左对齐留白 12px)   ← Game 可删可改可加按钮
├── ContentBox (MarginContainer, 铺满 TitleBar 以下区域)
│   └── ... Game 内容放这里（模板内留空）
├── ResizeLeft    (Control, script: GF_ResizeHandle, edge=LEFT,   8px 左边条)
├── ResizeRight   (Control, script: GF_ResizeHandle, edge=RIGHT,  8px 右边条)
├── ResizeTop     (Control, script: GF_ResizeHandle, edge=TOP,    8px 上边条)
├── ResizeBottom  (Control, script: GF_ResizeHandle, edge=BOTTOM, 8px 下边条)
└── ResizeCorner × 4 (Control, script: GF_ResizeHandle, edge=四角, 8×8)
```

**布局语义（非覆盖式）**：

- **TitleBar 是占位条带**，不是透明覆盖层。内容放在它下方的 ContentBox 区域，互不重叠、互不遮挡
- **手柄锚定在窗口四边**，渲染在内容之上：窗口最外圈 8px 的鼠标事件被手柄拦截（resize 手势优先），内容不被裁剪，只是最外圈 8px 的点击不归内容管——Win11 边缘隐形 resize 区的语义
- **顶部 8px 手势重叠区**：TOP 手柄与标题栏在窗口顶边重合，z 序上手柄在标题栏之上，故窗口最顶 8px = resize、标题栏其余部分 = 拖动（Windows 标准行为）
- 模板只是起点：Game 可改手柄宽度、删掉某个手柄（如固定高度窗口删 TOP/BOTTOM）、换掉 TitleBar 样式

### 4.5 GF_UIService 改动（修改 [ui_service.gd](../../modules/ui/ui_service.gd)，+~80 行）

#### 4.5.1 window 层

- `_create_ui_tree()` 插入 `_create_layer(&"window", "WindowLayer")`（screen 之后、popup 之前）
- `get_ui_layer` fallback match 同步加 case
- `_instantiate_panel` 路由：`get_ui_layer(def.windowed ? &"window" : def.kind)`

#### 4.5.2 打开时窗口初始化（open 路径，无包装层）

```gdscript
# open() 中 _instantiate_panel 之后、panel 初始化之前：
if def.windowed:
    if not (panel is GF_UIWindow):
        panel.queue_free()
        return GF_OperationResult.fail(
            GF_OperationResult.ERR_BAD_REQUEST,
            "windowed 面板场景根必须是 GF_UIWindow: %s" % p_name, module_name)
    # 窗口定位语义：强制 TOP_LEFT + 初始尺寸/位置
    panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    panel.size = def.window_size.max(def.window_min_size)
    panel.position = _next_window_position()   # 居中 + 同级错开（_open_order.size() * 24px）
```

`_active_panels[p_name] = panel` 直接存窗口根，无包装、无转发。`_prewarm_one` 同样走此初始化（提取 `_init_window(panel, def)` 私有方法共用）。

#### 4.5.3 focus_window（新增 API）

```gdscript
## 将窗口面板置顶：同步逻辑顺序（_open_order）、视觉顺序（move_child）并重算输入阻挡。
func focus_window(p_name: String) -> GF_OperationResult:
    if not _active_panels.has(p_name):
        return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "面板未打开: %s" % p_name, module_name)
    var def := _get_def(p_name)
    var panel := _get_panel_safe(p_name)
    if def == null or panel == null:
        return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "面板状态异常: %s" % p_name, module_name)

    _bring_to_front(p_name)                      # 逻辑 z：ESC 顺序、hit-test 顺序
    if panel is GF_UIWindow:                     # 视觉 z：window 层内 move 到末尾（后渲染在上）
        var layer: Control = get_ui_layer(&"window")
        layer.move_child(panel, layer.get_child_count() - 1)
    _recalculate_input_block()                   # 遮挡关系变化后重算
    return GF_OperationResult.ok()
```

置顶后逻辑 z 与视觉 z 一致：ESC 关焦点窗口、drop hit-test 命中顶层、渲染顺序三者同步。

#### 4.5.4 顶层命中查询（新增 API）

```gdscript
## 按 z 顺序（_open_order 逆序）返回第一个包含 p_pos 的可见面板，无命中返回 null。
## 用于 POINTER_ONLY 输入阻挡判定：窗口重叠时只有顶层窗口算命中。
func get_top_panel_at_position(p_pos: Vector2) -> GF_UIPanel
```

#### 4.5.5 无需改动的路径（确认清单）

`close` / `force_close` / `close_top` / `close_all` / `clear_layer` / `clear_gameplay_ui` / 缓存 `_cached_store` / `_do_close` / `show` / `hide` / `_hit_test_target`（`target.panel == 窗口根` 天然匹配，无适配）：全部对 GF_UIPanel 操作，窗口作为 GF_UIPanel 无感通过。

- `hide`：window.hide() 整个子树隐藏，reopen 时 window.show() 即恢复
- **HIDE_ON_CLOSE 窗口关闭再打开自动保留 position/size**（不销毁即记忆），符合 Win11 预期

### 4.6 GF_InputPolicy 改动（修改 [input_policy.gd](../../modules/input/input_policy.gd)，±10 行）

`_ui_pointer_blocks` 从"遍历所有面板平面判断"改为"只判顶层命中面板"：

```gdscript
func _ui_pointer_blocks(p_action_id: String, p_pos: Vector2) -> bool:
    if _ui_service == null: return false
    if _ui_service.is_dragging(): return false
    # 只检查 z 顺序最顶层的命中面板：窗口重叠时被遮挡区域不阻挡
    var top: GF_UIPanel = _ui_service.get_top_panel_at_position(p_pos)
    if top == null: return false
    var def = top._panel_def
    if def == null: return false
    if def.input_block_mode != GF_UIPanelDef.InputBlockMode.POINTER_ONLY: return false
    return def.blocked_action_ids.has("*") or def.blocked_action_ids.has(p_action_id)
```

非窗口场景（面板不重叠或全部铺满）行为与现状一致，向后兼容。`_ui_always_blocks` 不动（ALWAYS 语义是"可见即挡"，与重叠无关）。

## 5. 实现阶段与提交计划（main 分支）

按双分支工作流，每阶段一个 commit：

| 阶段 | 内容 | commit |
|---|---|---|
| 1 | `GF_UIPanelDef` 窗口字段 + windowed kind 约束校验 | `feat(ui): UIPanelDef 增加窗口化配置字段` |
| 2 | `GF_ResizeHandle`（edge 枚举、resize 逻辑、窗口发现） | `feat(ui): 新增 GF_ResizeHandle 窗口缩放手柄` |
| 3 | `GF_UIWindow`（drag_area 拖动、置顶双通道、手柄发现、clamp） | `feat(ui): 新增 GF_UIWindow 窗口根脚本（拖动/置顶）` |
| 4 | `scenes/ui/window_shell.tscn` 开箱模板 | `feat(ui): 新增 window_shell 窗口场景模板` |
| 5 | `GF_UIService`：window 层 + `_init_window` + `focus_window` + `get_top_panel_at_position` | `feat(ui): UIService 支持窗口面板管理与焦点置顶` |
| 6 | `GF_InputPolicy` 顶层命中判定 | `fix(input): POINTER_ONLY 按 z 顺序只判顶层面板` |
| 7 | 使用指南 [windowed-panels.md](../manual/feature-guides/windowed-panels.md) | `docs(ui): 窗口模式使用指南` |

每个阶段在 test 分支 `merge main` 后补测试再提交（见第 6 节）。

## 6. 测试计划（test 分支）

**新增 `tests/unit/ui/test_ui_resize_handle.gd`**（autoq 挂树，构造 InputEvent 调 `_gui_input` 模拟手势）：

- 8 个方向：每向拖动后 size/position 正确（N/W 向 position 同步收缩）
- min_size clamp（从窗口 `_panel_def.window_min_size` 读取）
- `resized` 信号在松手时发射
- 光标形状与 edge 匹配；`_find_window` 沿父链正确找到 GF_UIWindow

**新增 `tests/unit/ui/test_ui_window.gd`**：

- 拖动：press → motion 序列后 position 增量正确；clamp 后标题栏不越出父层边界；`moved` 信号在松手时发射
- `drag_area = null` 时不响应拖动
- 手柄发现：`find_children` 递归找到挂 GF_ResizeHandle 的节点
- 置顶：`gui_focus_changed` 与根节点 press 两通道均触发 `focus_window`
- 窗口根 mouse_filter 被强制为 PASS

**增补 `tests/unit/ui/test_ui_service.gd`**（用 FakeWindowPanel 构建 PackedScene）：

- windowed 打开：`_active_panels` 条目 `is GF_UIWindow`；anchors 被强制 TOP_LEFT；初始尺寸/位置正确（居中错开）
- windowed + 根非 GF_UIWindow → `ERR_BAD_REQUEST`
- windowed + 非 SCREEN kind → `ERR_BAD_REQUEST`
- `focus_window` 后 `move_child` 顺序在 window 层末尾；非 window 面板调用只改逻辑序
- `_hit_test_target` 在窗口化面板内正常命中（`target.panel == 窗口根`）
- HIDE_ON_CLOSE 窗口 close → open 往返后 position/size 保留
- `clear_all_ui` 清理窗口无泄漏（`is_instance_valid` 断言）

**增补 `tests/unit/input/test_input_policy.gd`**：

- 两窗口重叠：指针在重叠区 → 只有顶层窗口的 def 生效
- 非窗口面板行为回归不变

## 7. 风险与边界情况清单

| 边界 | 处理 |
|---|---|
| `window_size < window_min_size` | 初始化时取 max |
| 窗口拖出屏幕 | `_clamp_position()`，标题栏必须留在父层可视区 |
| Game 场景根 anchors 任意设置 | 打开时强制 `PRESET_TOP_LEFT`，覆盖场景配置 |
| Game 忘记挂 drag_area / 手柄 | 能力自动禁用（null 检查）；文档模板兜底 |
| 拖动中窗口被 `force_close` | `_gui_input` 随节点释放停止，无悬空引用 |
| item 拖拽进行中窗口被置顶 | `begin_drag` 不触发 `focus_window`，z 不变，drop 语义稳定 |
| prewarm + windowed | `_prewarm_one` 走同一 `_init_window` |
| 缩放极小 → 内容溢出 | min_size 兜底；极端内容 Game 层用 ScrollContainer（文档建议） |
| 非焦点窗口视觉区分 | `focused`/`unfocused` 信号，Game 订阅后切标题栏样式（模板提供默认置灰） |
| 窗口布局持久化 | v1 内存级（缓存自然保留）；`moved`/`resized` 信号已备好存档接口，接 ISaveable 是 v1.1 |
| 手柄脚本挂到窗口外节点 | `_find_window` 找不到则失效并 push_warning，不静默 |

## 8. v2 预留（多实例）

`multi_instance` 字段已进 Def，v1 `windowed && multi_instance` 直接 fail fast（不静默降级）。

真正实现时：`_active_panels` key 从 `String` 变为 `String + "#n"` 复合 key，波及 `is_open`/`get_panel`/`close`/hit-test/焦点栈的全查询链——单独一期做，不在本方案范围。

## 9. 工作量估计

- 框架代码：~450 行新增/修改（GF_UIWindow ~250 + GF_ResizeHandle ~120 + Service ~80 + Def ~25 + InputPolicy ±10）
- 场景模板：1 个 window_shell.tscn
- 测试：~18 个新用例 + 2 个文件增补
- 对既有行为的唯一改变：`GF_InputPolicy._ui_pointer_blocks` 顶层命中（非窗口场景等价），其余全部增量

## 附录：v1 → v2 方案变更说明

| v1（已废弃） | v2（当前） | 废弃理由 |
|---|---|---|
| 框架代码构建 chrome，包装 Game 内容面板 | Game 编辑器搭建窗口，根节点挂 GF_UIWindow | chrome 代码构建不可预览、样式只能 theme 覆盖；编辑器搭建是 Godot 标准工作流 |
| `attach_content` / `get_content` / 生命周期转发 | 删除 | 无包装层则无需转发 |
| `window_host` 反向引用 + hit-test 适配 | 删除 | `target.panel == 窗口根` 天然匹配 |
| `_apply_focus_config` 覆写（default_focus 路径重写） | 删除 | 路径天然相对窗口根 |
| `window_movable` / `window_resizable` 字段 | 删除 | 能力由场景结构表达（有没有 drag_area / 手柄），结构即配置 |
