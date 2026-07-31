# GF_UIDragManager / GF_UIDragHandler / GF_UIDragEvent / GF_UIDragGhost / GF_UIDropTarget / GF_UIDragExtensions

> 适用版本: 0.3.0 | 拖拽系统协议层 (L1)

## 概述

拖拽系统的核心协议层（L1）。负责拖拽的事件驱动、状态机管理、命中检测和视觉呈现。由以下六个类协作构成：

- **GF_UIDragManager** — 拖拽驱动节点，挂场景树，处理原始输入事件
- **GF_UIDragHandler** — 拖拽源接口，游戏层继承实现具体拖拽行为
- **GF_UIDragEvent** — 拖拽事件数据，贯穿整个拖拽周期
- **GF_UIDragGhost** — 拖拽视觉控件，提供三种展示模式
- **GF_UIDropTarget** — 放置目标，定义命中区域和接收回调
- **GF_UIDragExtensions** — 静态工具方法，为任意 Control 快速添加拖拽能力

**何时使用：**

- 需要自定义拖拽行为的游戏层代码（继承 GF_UIDragHandler）
- 需要定义放置区域的面板代码（创建 GF_UIDropTarget）
- 需要快速给控件加拖拽能力（调用 GF_UIDragExtensions 静态方法）

**何时不使用：**

- 简单的格子拖拽 — 使用 L2 层的 [GF_UIDragSlot](gf_ui_drag_slot.md)
- 简单图标拖拽 — 使用 GF_UIService 的 `begin_simple_drag()`

---

## GF_UIDragManager

> 继承: GF_UIDragManager → Node → Object

拖拽事件驱动节点。由 GF_UIService 在 `configure()` 时创建，通过 GF_ServiceInstallerImpl 挂到场景树。使用 `_input()`（在 GUI 之前触发）确保 drop 事件不会被 Control 消费而丢失。

**状态机：** `idle → dragging → drop/cancel → idle`

### 公共方法

#### configure(p_service: GF_UIService)

由 GF_UIService 调用，存储对服务的弱引用。

---

#### begin(p_handler: GF_UIDragHandler, p_screen_pos: Vector2, p_button: int, p_source: GF_UIPanel)

由 GF_UIService.begin_drag 调用。创建 GF_UIDragEvent，设置 handler 的 ghost 附着回调，调用 `handler.on_begin_drag(event)`。

---

#### get_current_event() → GF_UIDragEvent

返回当前拖拽事件数据。空闲时返回 null。

---

#### get_current_handler() → GF_UIDragHandler

返回当前拖拽处理器。空闲时返回 null。

---

#### is_dragging() → bool

判断是否正在拖拽中。等价于 `_event != null`。

---

#### clear_drag_state()

清理拖拽状态（dismiss ghost、置空 handler/event）。由 GF_UIService 在拖拽结束时调用。

### 内部行为

- **`_input(p_event)`：** 处理鼠标移动（更新 event 坐标、通知 handler.on_drag、驱动 ghost 跟随、hit_test hover/leave）和鼠标释放（路由到 GF_UIService._on_drag_drop 做最终放置）。
- **ESC 键：** 在 `_input` 中检测 KEY_ESCAPE，调 `cancel_drag()`。
- **窗口失焦：** `NOTIFICATION_WM_WINDOW_FOCUS_OUT` 时自动 `cancel_drag()`，防止拖拽卡死。

---

## GF_UIDragHandler

> 继承: GF_UIDragHandler → RefCounted

拖拽源接口。游戏层继承此类实现拖拽行为。框架在拖拽生命周期的各个阶段调用对应方法。

**调用顺序：** `on_begin_drag` → `on_drag`（每帧）→ `on_drop`（如有接收者）→ `on_end_drag`（必有）

### 公共方法

#### on_begin_drag(_event: GF_UIDragEvent)

拖拽开始时调用。游戏层在此：
1. 设置 `event.drag_data`（告诉潜在接收者正在拖什么）
2. 调用 `event.show_ghost_xxx()` 创建拖拽视觉

#### on_drag(_event: GF_UIDragEvent)

每帧移动中调用。`event.position` 和 `event.delta` 已由框架更新。游戏层在此更新视觉位置、世界预览等。

---

#### on_drop(_event: GF_UIDragEvent) → bool

有接收者接受时调用（在 on_end_drag 之前）。返回 true 表示接受放置，false 表示拒绝。默认返回 true。

---

#### on_end_drag(_event: GF_UIDragEvent)

拖拽结束（无论如何都调用）。调用顺序：on_drop（如有）→ on_end_drag（必有）。`event.drop_receiver` 非 null 表示有面板接受了放置。游戏层在此销毁视觉、清理临时状态。

---

## GF_UIDragEvent

> 继承: GF_UIDragEvent → RefCounted

拖拽事件数据。框架在 begin_drag 时创建，贯穿整个拖拽周期。游戏层在 `on_begin_drag` 回调中填写 `drag_data`。

### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| position | Vector2 | Vector2.ZERO | 当前屏幕坐标（框架每帧更新）。 |
| delta | Vector2 | Vector2.ZERO | 位移增量 -- 本帧移动量（框架每帧更新）。 |
| button | int | MOUSE_BUTTON_LEFT | 触发拖拽的鼠标按键。 |
| drag_source | GF_UIPanel | null | 拖拽源面板（框架自动填充）。 |
| drag_data | Dictionary | {} | 拖拽携带的数据。游戏层在 on_begin_drag 中填写。例如 `{"item_id": "iron_sword", "count": 5, "from_slot": 3}`。 |
| drop_receiver | Variant | null | 松手时接收者。null 表示没有接收者接受此次拖拽。 |

### 公共方法 (L2 Ghost 快捷方法)

#### show_ghost_texture(p_texture: Texture2D, p_offset: Vector2 = Vector2(-24, -24)) → GF_UIDragGhost

显示图标跟随鼠标。游戏层在 `on_begin_drag` 中调用。返回 GF_UIDragGhost 供进一步定制。

#### show_ghost_item(p_texture: Texture2D, p_count: int, p_offset: Vector2 = Vector2(-24, -24)) → GF_UIDragGhost

显示图标 + 数量。数量 > 1 时显示 "x N" 标签。例如：铁矿石图标下显示 "x 5"。

#### show_ghost_text(p_text: String) → GF_UIDragGhost

显示纯文本拖拽。例如：`"+100 金币"`。

---

## GF_UIDragGhost

> 继承: GF_UIDragGhost → Control → CanvasItem → Node → Object

拖拽视觉控件。由游戏层通过 `event.show_ghost_xxx()` 一键创建，无需手写 TextureRect 管理代码。自动挂载到 SYSTEM 层（最顶层），确保不被任何面板遮挡。`mouse_filter = IGNORE`，不拦截鼠标事件。

**三种模式：**
1. 纯图标：`show_with_texture(tex, offset)`
2. 图标 + 数量：`show_with_item(tex, count, offset)`
3. 纯文本：`show_with_text("+100 金币")`

### 公共方法

#### show_with_texture(p_texture: Texture2D, p_offset: Vector2 = Vector2(-24, -24))

显示纯图标。p_offset 为图标相对于鼠标的偏移，默认 (-24, -24) 即居中（假设图标 48x48）。

#### show_with_item(p_texture: Texture2D, p_count: int, p_offset: Vector2 = Vector2(-24, -24))

显示图标 + 数量。数量 > 1 时显示 "x N" 标签。

#### show_with_text(p_text: String)

显示纯文本。用于非图标类的拖拽信息展示。

#### _follow(p_screen_pos: Vector2)

每帧由 GF_UIDragManager._input 调用，跟随鼠标移动。

#### dismiss()

由 GF_UIDragManager.clear_drag_state 调用。隐藏并释放 ghost 节点。

---

## GF_UIDropTarget

> 继承: GF_UIDropTarget → RefCounted

放置目标。游戏层创建并注册给 GF_UIService。包含命中区域、接收条件和回调。面板关闭时框架自动清理其所有 GF_UIDropTarget。

### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| panel | GF_UIPanel | null | 所属面板。框架用于 Z-order 排序和面板关闭时自动清理。必须设置。 |
| rect | Rect2 | Rect2() | 命中矩形（面板局部坐标）。框架自动转为全局坐标做 hit_test。 |
| accept_filter | Callable | (空) | 可选。业务判断：此拖拽数据是否被本区域接受。`func(data: Dictionary) -> bool`。为空则接受所有。 |
| on_hover | Callable | (空) | 可选。拖拽悬停到本区域时回调。`func(data: Dictionary) -> void`。 |
| on_leave | Callable | (空) | 可选。拖拽离开本区域时回调。`func() -> void`。 |
| on_drop | Callable | (空) | 可选。物品放入此区域时回调。`func(data: Dictionary) -> bool`。返回 true=接受，false=拒绝（物品弹回）。 |

### 示例

```gdscript
func _on_open(_p_data: Dictionary) -> void:
    # 为面板中的装备槽注册放置目标
    var target := GF_UIDropTarget.new()
    target.panel = self
    target.rect = $EquipSlot.get_rect()
    target.accept_filter = func(data: Dictionary) -> bool:
        return data.get("item_type", "") == "weapon"
    target.on_hover = func(_data: Dictionary) -> void:
        $EquipSlot/Highlight.show()
    target.on_leave = func() -> void:
        $EquipSlot/Highlight.hide()
    target.on_drop = func(data: Dictionary) -> bool:
        ctx.log.info("装备", "装备了: %s" % data.get("item_id"))
        _equip_item(data["item_id"])
        return true
    ctx.ui.register_drop_target(target)
```

---

## GF_UIDragExtensions

> 继承: GF_UIDragExtensions → RefCounted

对任意 Control 快速添加拖拽能力的静态方法集合。游戏层无需继承 GF_UIDragSlot 即可让任意 UI 元素参与拖拽。自动查找所属 GF_UIPanel 和 GF_UIService。

### 静态方法

#### setup_drag_source(p_control: Control, p_config: Dictionary)

让一个 Control 可从中拖出物品。p_config 支持字段：

| 字段 | 类型 | 必填 | 默认值 | 描述 |
|------|------|------|--------|------|
| data | Dictionary | 是 | — | 拖拽携带的数据。 |
| icon | Texture2D | 否 | null | 拖拽时显示的图标。 |
| offset | Vector2 | 否 | Vector2(-24, -24) | 图标相对于鼠标的偏移。 |
| condition | Callable | 否 | `func() -> bool: return true` | 是否允许拖出。返回 false 则忽略鼠标按下。 |
| on_begin | Callable | 否 | (空) | 拖出时回调。`func() -> void`。 |
| on_end | Callable | 否 | (空) | 拖拽结束回调。`func(accepted: bool) -> void`。 |
| on_cancel | Callable | 否 | (空) | 拖拽取消回调。`func() -> void`。 |

**示例:** ```gdscript
GF_UIDragExtensions.setup_drag_source($ItemIcon, {
    "data": {"item_id": "iron_sword", "count": 1},
    "icon": sword_texture,
    "condition": func() -> bool: return not is_locked,
    "on_begin": func() -> void: modulate = Color(1, 1, 1, 0.5),
    "on_end": func(accepted: bool) -> void: modulate = Color.WHITE,
})
```

---

#### setup_drop_target(p_control: Control, p_config: Dictionary)

让一个 Control 成为放置目标。p_config 支持字段：

| 字段 | 类型 | 必填 | 默认值 | 描述 |
|------|------|------|--------|------|
| accept | Callable | 否 | `func(_d) -> bool: return true` | 是否接受拖拽数据。`func(data: Dictionary) -> bool`。 |
| on_drop | Callable | 否 | (空) | 放入时回调。`func(data: Dictionary) -> bool`。 |
| on_hover | Callable | 否 | (空) | 悬停回调。`func(data: Dictionary) -> void`。 |
| on_leave | Callable | 否 | (空) | 离开回调。`func() -> void`。 |
| rect_override | Rect2 | 否 | p_control.get_rect() | 覆盖命中区域。 |

## See Also

- [GF_UIService](gf_ui_service.md) — UI 管理服务（拖拽的对外 API 入口）
- [GF_UIDragSlot](gf_ui_drag_slot.md) — L2 层可拖拽格子控件
- [GF_UIPanel](gf_ui_panel.md) — 面板基类（drop_target 的所属容器）
