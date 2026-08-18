# 实现拖拽交互

## 场景描述

游戏需要在 UI 面板中实现拖拽交互——玩家从背包格子里拖出物品放入快捷栏，或将装备拖到角色身上。框架的拖拽系统采用三层设计：L1 协议层（自定义 Handler）、L2 便利层（GF_UIDragSlot 开箱即用）、L3 游戏层（具体业务逻辑）。

本章覆盖：L1 自定义拖拽、L2 快速拖拽槽位、拖拽视觉 Ghost、DropTarget 注册和命中检测、物品栏拖拽交换示例。

---

## 最小示例

```gdscript
# L2 快速模式：在场景中放置 GF_UIDragSlot，即可拖拽
# 编辑器配置：
#   drag_enabled = true   — 可从中拖出
#   drop_enabled = true   — 可放入物品
#   accept_tags = ["weapon", "armor"]  — 只接受带有这些标签的物品

# 代码中设置格子数据
$InventoryGrid/Slot1.set_slot_data({
    "item_id": "iron_sword", "count": 1,
    "_tags": ["weapon"], "_icon": preload("res://icons/sword.png")
})

# 连接信号处理业务逻辑
$InventoryGrid/Slot1.slot_drop_received.connect(_on_item_swapped)

func _on_item_swapped(from_slot: GF_UIDragSlot, to_slot: GF_UIDragSlot) -> void:
    var from_data := from_slot.get_slot_data()
    var to_data := to_slot.get_slot_data()
    to_slot.set_slot_data(from_data)
    from_slot.set_slot_data(to_data)
```

---

## 逐步解释

### 架构三层

| 层级 | 类 | 职责 |
|------|-----|------|
| L1 协议层 | `GF_UIDragHandler` + `GF_UIDropTarget` | 自定义拖拽逻辑，最大灵活性 |
| L2 便利层 | `GF_UIDragSlot` + `GF_UIDragExtensions` | 快速实现，编辑器配置 |
| L3 游戏层 | 你的具体业务代码 | 物品数据、交换规则 |

### 第一步：L1 协议层 — 自定义 DragHandler

`GF_UIDragHandler` 是一个接口基类，游戏层继承它来实现自定义拖拽行为：

```gdscript
class_name MyItemDragHandler
extends GF_UIDragHandler

var _ghost: GF_UIDragGhost = null


func on_begin_drag(event: GF_UIDragEvent) -> void:
    # 1. 设置拖拽数据（接收方通过 event.drag_data 获取）
    event.drag_data = {"item_id": "iron_sword", "count": 5, "_tags": ["weapon"]}

    # 2. 创建拖拽视觉（自动挂到 SYSTEM 层，跟随鼠标）
    _ghost = event.show_ghost_item(preload("res://icons/sword.png"), 5)


func on_drag(event: GF_UIDragEvent) -> void:
    # 每帧调用，可用于更新世界预览等
    pass


func on_drop(event: GF_UIDragEvent) -> bool:
    # 有接收者接受时调用（在 on_end_drag 之前）
    # 返回 true = 接受，false = 拒绝
    return true


func on_end_drag(event: GF_UIDragEvent) -> void:
    # 拖拽结束（无论如何都调用）
    # event.drop_receiver 非 null 表示有面板接受了放置
    if event.drop_receiver == null:
        print("拖拽取消，物品弹回")
    # _ghost 由框架自动 dismiss
```

调用顺序：`on_begin_drag` → `on_drag`（每帧）→ `on_drop`（如有接收者）→ `on_end_drag`（必有）。

### 第二步：发起拖拽

```gdscript
# 创建 handler
var handler := MyItemDragHandler.new()

# 通过 UIService 开始拖拽
var result := ui_service.begin_drag(handler, get_global_mouse_position(), self)
if result.is_fail():
    _log.error("UI", "开始拖拽失败: %s" % result.error.message)
```

- `p_handler`：你实现的 GF_UIDragHandler 子类
- `p_screen_pos`：初始屏幕坐标
- `p_source`：拖拽源面板（可选，用于关联）

如果有旧拖拽未结束，`begin_drag` 会先 `cancel_drag()` 再开始新的。

### 第三步：注册 DropTarget

```gdscript
# 在面板的 _on_open 中注册放置目标
func _on_open(_p_data: Dictionary) -> void:
    var target := GF_UIDropTarget.new()
    target.panel = self                     # 所属面板
    target.rect = $DropZone.get_rect()      # 命中区域（面板局部坐标）
    target.accept_filter = func(data: Dictionary) -> bool:
        return data.get("item_id", "") != ""
    target.on_hover = func(data: Dictionary) -> void:
        $DropZone.modulate = Color.GREEN    # 高亮
    target.on_leave = func() -> void:
        $DropZone.modulate = Color.WHITE    # 恢复
    target.on_drop = func(data: Dictionary) -> bool:
        print("收到物品: ", data.item_id)
        return true                         # true = 接受

    ctx.ui.register_drop_target(target)
```

`GF_UIDropTarget` 的字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `panel` | `GF_UIPanel` | 所属面板，用于 Z-order 排序 |
| `rect` | `Rect2` | 命中矩形，面板局部坐标 |
| `accept_filter` | `Callable` | `func(data) -> bool`，过滤不接受的拖拽 |
| `on_hover` | `Callable` | 拖拽悬停到区域上 |
| `on_leave` | `Callable` | 拖拽离开区域 |
| `on_drop` | `Callable` | 松手放入，返回 true 接受/false 拒绝 |

面板关闭时框架自动清理其所有 DropTarget，无需手动注销。

### 第四步：拖拽视觉 Ghost

`GF_UIDragEvent` 提供三种 show 方法，返回 `GF_UIDragGhost` 供进一步定制：

```gdscript
func on_begin_drag(event: GF_UIDragEvent) -> void:
    # 纯图标
    var ghost := event.show_ghost_texture(my_texture, Vector2(-24, -24))

    # 图标 + 数量（数量 > 1 时在右下角显示 "× N"）
    var ghost := event.show_ghost_item(my_texture, 10)

    # 纯文本
    var ghost := event.show_ghost_text("+100 金币")
```

Ghost 自动挂到 SYSTEM 层（最顶层），`mouse_filter = IGNORE`（不拦截鼠标事件），每帧跟随鼠标。

### 第五步：L2 便利层 — GF_UIDragSlot

GF_UIDragSlot 是将拖拽源 + 放置目标打包好的 Control，拖到场景里配置一下就能用：

**编辑器配置属性：**

| 属性 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `drag_enabled` | `bool` | `true` | 是否可从此格子拖出物品 |
| `drop_enabled` | `bool` | `true` | 是否可放入物品 |
| `accept_tags` | `Array[String]` | `[]` | 接受的物品标签（空=全部接受） |
| `reject_tags` | `Array[String]` | `[]` | 拒绝的物品标签 |
| `swap_on_drop` | `bool` | `true` | 放入时是否交换（true=交换，false=移动） |
| `drag_ghost_texture` | `Texture2D` | — | 拖拽时的图标（为空则自动取子节点 "Icon" 的纹理） |
| `drag_ghost_offset` | `Vector2` | `(-24, -24)` | 图标相对于鼠标的偏移 |
| `drag_start_threshold` | `float` | `8.0` | 拖动判定阈值（像素）。按下后移动超过此距离才判定为拖动，否则松开时判定为单击。设为 `0` 表示按下即拖拽 |

**代码使用：**

```gdscript
# 设置格子数据
slot.set_slot_data({"item_id": "potion", "count": 3, "_tags": ["consumable"]})

# 获取格子数据
var data := slot.get_slot_data()

# 检查是否为空
if slot.is_empty():
    print("空槽位")

# 更新标签过滤（运行时动态调整）
slot.accept_tags = ["weapon"]

# 刷新命中区域（格子大小变化后）
slot.refresh_drop_target()
```

**信号：**

| 信号 | 参数 | 说明 |
|------|------|------|
| `slot_drag_begin` | `slot: GF_UIDragSlot` | 物品开始拖出 |
| `slot_drop_received` | `from_slot, to_slot` | 物品放入此格子 |
| `slot_drag_cancelled` | `slot: GF_UIDragSlot` | 拖拽取消（未放入任何目标） |
| `slot_drag_end` | `slot, accepted: bool` | 拖拽结束 |

内置行为（自动处理）：
- 鼠标按下空数据时 → 不拖拽
- 有物品拖过且 `_accepts` 通过时 → 自动高亮（半透明白色覆盖）
- 物品放入成功 → 发射 `slot_drop_received`

### 第五步补充：格子鼠标事件回调（单击/双击/右键/拖动）

GF_UIDragSlot 除了拖拽，还内置了鼠标事件的**判定逻辑**——单击、双击、右键、拖动
由框架自动区分，子类只需重写需要的事件方法，无需自己判断输入类型：

```gdscript
class_name MyItemSlot
extends GF_UIDragSlot


func _on_slot_clicked(p_button: int) -> void:
    match p_button:
        MOUSE_BUTTON_LEFT:
            _select_item()          # 左键单击：选中
        MOUSE_BUTTON_RIGHT:
            _open_context_menu()    # 右键单击：弹出菜单


func _on_slot_double_clicked(p_button: int) -> void:
    _use_item()                     # 双击：使用物品


func _on_slot_drag_ended(p_accepted: bool) -> void:
    if p_accepted:
        _on_swap_success()
```

可重写的回调：

| 回调 | 触发时机 |
|------|---------|
| `_on_slot_pressed(p_button)` | 任意鼠标按键按下 |
| `_on_slot_released(p_button)` | 任意鼠标按键松开 |
| `_on_slot_clicked(p_button)` | 单击：按下 → 松开，且移动未超过 `drag_start_threshold`。左/右/中键通用，通过 `p_button` 区分 |
| `_on_slot_double_clicked(p_button)` | 双击：引擎按 OS 双击时间窗口检测（`InputEventMouseButton.double_click`） |
| `_on_slot_drag_started()` | 拖动开始：按下后移动超过 `drag_start_threshold` 像素（仅左键 + 有数据） |
| `_on_slot_drag_ended(p_accepted)` | 拖动结束（`p_accepted` 表示是否有目标接受了放置） |

行为约定：

- **单击 vs 拖动**：按下后移动超过 `drag_start_threshold`（默认 8px）判定为拖动，
  否则松开时判定为单击。拖动一旦开始，本次按压不再触发单击；
- **双击顺序**：双击时第一击仍会触发 `_on_slot_clicked`（标准行为），
  第二击触发 `_on_slot_double_clicked`，且第二击的松开不再重复触发单击；
- **右键**：右键单击通过 `_on_slot_clicked(MOUSE_BUTTON_RIGHT)` 上报，
  右键不会触发拖拽；
- **滑动**：按下后移动超过阈值但格子无数据 / `drag_enabled=false` 时，
  视为滑动，既不拖拽也不触发单击；
- 原有信号（`slot_drag_begin` / `slot_drop_received` 等）不受影响，可与回调共存；
  对不继承的子类，信号仍是主要接入方式。

### 第六步：L2 便捷 API — begin_simple_drag

```gdscript
# 给 data + icon，框架全管
var handler := ui_service.begin_simple_drag(
    {"item_id": "potion", "count": 1},
    preload("res://icons/potion.png"),
    Vector2(-24, -24)
)
```

返回 `GF_UIDragHandler`，可以连接信号监听拖拽结束。

### 第七步：拖拽生命周期管理

```gdscript
# 检查是否在拖拽中
if ui_service.is_dragging():
    # 获取拖拽位置
    var pos := ui_service.get_drag_position()

# 取消拖拽（ESC 键或窗口失焦自动触发）
ui_service.cancel_drag()
```

---

## 完整示例：物品栏拖拽交换

```gdscript
# ---- inventory_panel.gd ----
class_name InventoryPanel
extends GF_UIPanel

var _slots: Array[GF_UIDragSlot] = []


func _on_open(_p_data: Dictionary) -> void:
    var grid := $GridContainer
    for i in range(20):
        var slot := GF_UIDragSlot.new()
        slot.custom_minimum_size = Vector2(64, 64)
        slot.drag_enabled = true
        slot.drop_enabled = true
        slot.swap_on_drop = true
        slot.slot_drop_received.connect(_on_item_swapped)
        slot.slot_drag_begin.connect(_on_drag_begin)
        slot.slot_drag_cancelled.connect(_on_drag_cancelled)
        grid.add_child(slot)
        _slots.append(slot)

    _load_inventory()


func _load_inventory() -> void:
    # 从 ECS 或 Save 系统加载物品数据
    var items := _get_player_items()
    for i in range(min(items.size(), _slots.size())):
        var item := items[i]
        _slots[i].set_slot_data({
            "item_id": item.id,
            "count": item.count,
            "_tags": item.tags,
            "_icon": item.icon,
        })


func _on_item_swapped(from_slot: GF_UIDragSlot, to_slot: GF_UIDragSlot) -> void:
    var from_data := from_slot.get_slot_data()
    var to_data := to_slot.get_slot_data()

    # 交换数据
    to_slot.set_slot_data(from_data)
    from_slot.set_slot_data(to_data)

    # 持久化更改（通过命令或直接保存）
    ctx.log.info("Inventory", "物品交换: %s ↔ %s" % [
        from_data.get("item_id", "?"), to_data.get("item_id", "?")
    ])


func _on_drag_begin(slot: GF_UIDragSlot) -> void:
    ctx.log.debug("Inventory", "开始拖拽: %s" % slot.get_slot_data().get("item_id"))


func _on_drag_cancelled(slot: GF_UIDragSlot) -> void:
    ctx.log.debug("Inventory", "拖拽取消: %s" % slot.get_slot_data().get("item_id"))


# ---- 自定义 L1 模式：拖拽到世界（非 UI 目标） ----

class WorldDropHandler
extends GF_UIDragHandler

var _ghost: GF_UIDragGhost = null
var _panel: GF_UIPanel = null


func on_begin_drag(event: GF_UIDragEvent) -> void:
    event.drag_data = {"item_id": "torch", "action": "place_in_world"}
    _ghost = event.show_ghost_item(preload("res://icons/torch.png"), 1)
    _ghost.modulate = Color(1, 1, 1, 0.7)


func on_end_drag(event: GF_UIDragEvent) -> void:
    if event.drop_receiver != null:
        return

    # 没有 UI 目标接受 → 尝试丢到游戏世界
    # 通过 Game 层管理的 Camera2D 转换坐标
    var world_pos := _camera.get_global_mouse_position()
    if _is_valid_world_position(world_pos):
        _place_item_in_world(event.drag_data.item_id, world_pos)


func _is_valid_world_position(_pos: Vector2) -> bool:
    return true  # 实现具体的位置校验


func _place_item_in_world(_item_id: String, _pos: Vector2) -> void:
    pass  # 通过 ECS 命令生成实体
```

---

## 常见变体

### 变体 1：使用 GF_UIDragExtensions 给任意 Control 添加拖拽

```gdscript
# 不需要继承 GF_UIDragSlot，给现成的 TextureRect 添加拖拽能力
GF_UIDragExtensions.setup_drag_source($MyIcon, {
    "data": {"item_id": "gem", "count": 1},
    "icon": preload("res://icons/gem.png"),
    "condition": func() -> bool: return _can_drag,
    "on_end": func(accepted: bool): print("拖拽结束, accepted=", accepted),
})

GF_UIDragExtensions.setup_drop_target($DropArea, {
    "accept": func(data: Dictionary) -> bool:
        return data.get("item_id") == "gem",
    "on_drop": func(data: Dictionary) -> bool:
        print("收到宝石")
        return true,
    "on_hover": func(_data): $DropArea.modulate = Color.GREEN,
    "on_leave": func(): $DropArea.modulate = Color.WHITE,
})
```

### 变体 2：禁止特定格子之间的拖拽

```gdscript
func _on_item_swapped(from_slot: GF_UIDragSlot, to_slot: GF_UIDragSlot) -> void:
    var from_data := from_slot.get_slot_data()
    var to_data := to_slot.get_slot_data()

    # 规则：武器只能放入武器栏
    if from_data.get("_tags", []).has("weapon") and not _is_weapon_slot(to_slot):
        ctx.log.warning("Inventory", "武器只能放入武器栏")
        return  # 拒绝交换

    # 执行交换...
```

### 变体 3：部分堆叠

```gdscript
func _on_item_swapped(from_slot: GF_UIDragSlot, to_slot: GF_UIDragSlot) -> void:
    var from_data := from_slot.get_slot_data()
    var to_data := to_slot.get_slot_data()

    # 如果是相同物品，堆叠而非交换
    if from_data.get("item_id") == to_data.get("item_id"):
        var new_count := from_data.count + to_data.count
        to_slot.set_slot_data({"item_id": from_data.item_id, "count": new_count})
        from_slot.set_slot_data({})
        return

    # 不同物品则交换...
```

---

## 错误码

| 方法 | 可能的错误码 | 说明 |
|------|------------|------|
| `begin_drag(handler, pos, source)` | `ERR_INTERNAL` | GF_UIDragManager 未初始化 |
| | `ERR_BAD_REQUEST` | handler 为 null |
| `register_drop_target(target)` | `ERR_BAD_REQUEST` | target 为 null 或 target.panel 为 null |

---

## See Also

- [创建和管理 UI 面板](./create-ui-panels.md) -- 面板的创建和生命周期
- [处理玩家输入](./handle-player-input.md) -- 拖拽中的输入处理
