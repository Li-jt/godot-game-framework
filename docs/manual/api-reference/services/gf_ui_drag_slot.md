# GF_UIDragSlot

> 适用版本: 0.3.0 | 继承: GF_UIDragSlot → Control → CanvasItem → Node → Object

## 概述

可拖拽格子控件，拖拽系统便捷层（L2）。既是拖拽源也是放置目标，在编辑器中配置即可使用，无需编写代码。自动处理鼠标按下拖出、物品悬停高亮、放置信号发射。

**何时使用：** 背包格子、装备槽、快捷栏、物品交换等场景。在场景中放置 GF_UIDragSlot 子节点，编辑器中勾选属性即可。

**何时不使用：** 非格子的拖拽（需要 GF_UIDragExtensions 或手写 GF_UIDragHandler），或仅需拖出能力（用 GF_UIDragExtensions.setup_drag_source）。

## 编辑器可导出属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| drag_enabled | bool | true | 此格子是否可从中拖出物品。 |
| drop_enabled | bool | true | 此格子是否可接受物品放入。 |
| accept_tags | Array[String] | [] | 接受的物品标签。空数组表示接受所有物品。只有 drag_data 的 `_tags` 包含至少一个 accept_tags 时才会被接受。 |
| reject_tags | Array[String] | [] | 拒绝的物品标签。如果 drag_data 的 `_tags` 包含任意一个 reject_tags，则拒绝。 |
| swap_on_drop | bool | true | 放入时是否交换（true=交换两个格子的内容，false=移动，源格子变空）。 |
| drag_ghost_texture | Texture2D | (空) | 自定义拖拽图标。为空时自动使用格子的 `Icon` 子节点纹理。 |
| drag_ghost_offset | Vector2 | Vector2(-24, -24) | 拖拽图标相对于鼠标的偏移。默认 (-24, -24) 适合 48x48 的图标居中。 |

## 信号

### slot_drag_begin(slot: GF_UIDragSlot)

物品从此格子拖出时发射。

---

### slot_drop_received(from_slot: GF_UIDragSlot, to_slot: GF_UIDragSlot)

物品从 from_slot 放入此格子（to_slot）时发射。游戏层连接此信号处理业务逻辑（更新数据、交换物品等）。

---

### slot_drag_cancelled(slot: GF_UIDragSlot)

拖拽取消（物品弹回）时发射。例如拖到无效区域松手。

---

### slot_drag_end(slot: GF_UIDragSlot, accepted: bool)

拖拽结束（无论成功与否）时发射。accepted 为 true 表示有格子接受了放置。

## 公共方法

### set_slot_data(p_data: Dictionary)

设置格子数据。游戏层在填充格子内容时调用。p_data 中应包含 `_tags`（Array）字段供 accept_tags / reject_tags 过滤。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_data | Dictionary | 格子数据。推荐字段：`item_id`、`count`、`_tags`、`icon` 等。 |

---

### get_slot_data() → Dictionary

获取当前格子数据。返回的是内部引用，如需修改应使用 `duplicate()`。

---

### is_empty() → bool

检查格子是否为空。等价于 `_slot_data.is_empty()`。

---

### refresh_drop_target()

手动刷新注册的放置目标。当格子的 `rect` 发生变化时（如动画、自适应布局）调用此方法更新命中区域。

## 内部行为

以下行为由框架自动处理，游戏层无需干预：

- **拖出：** 鼠标左键（非双击）在 `drag_enabled=true` 且 `_slot_data` 非空的格子上按下时，自动调用 `ctx.ui.begin_drag()`。拖拽数据自动包含 `_source_slot` 引用。
- **高亮：** 有物品拖过且 `_accepts()` 返回 true 时，自动显示半透明白色矩形高亮。
- **放置：** 物品放入时，自动发射 `slot_drop_received` 信号。源格子等于自身时忽略（防止自己拖给自己）。
- **注册：** `_ready()` 时通过 `call_deferred` 延迟注册 drop target（等待父面板 `ctx` 注入完成）。如果 ctx 尚未就绪，继续延迟重试。

### 标签过滤逻辑 (_accepts)

```text
1. 如果 drop_enabled=false → 拒绝
2. 如果 accept_tags 非空:
   - drag_data._tags 包含至少一个 accept_tags → 接受
   - 否则 → 拒绝
3. 如果 reject_tags 非空:
   - drag_data._tags 包含至少一个 reject_tags → 拒绝
4. 否则 → 接受
```

## 使用示例

### 场景结构

```text
InventoryPanel (GF_UIPanel)
├── GridContainer
│   ├── GF_UIDragSlot  (drag_enabled=true, drop_enabled=true)
│   ├── GF_UIDragSlot
│   └── ...
```

### 脚本

```gdscript
extends GF_UIPanel

func _on_open(p_data: Dictionary) -> void:
    # 填充格子数据
    var items := ctx.save_service.get_inventory_items()
    var slots := _get_all_slots()
    for i in min(items.size(), slots.size()):
        var item := items[i]
        slots[i].set_slot_data({
            "item_id": item.id,
            "count": item.count,
            "icon": item.icon,
            "_tags": item.tags  # 如 ["consumable", "potion"]
        })
        slots[i].slot_drop_received.connect(_on_item_swapped)

func _on_item_swapped(from_slot: GF_UIDragSlot, to_slot: GF_UIDragSlot) -> void:
    # 交换两个格子的数据
    var temp := from_slot.get_slot_data().duplicate()
    from_slot.set_slot_data(to_slot.get_slot_data().duplicate())
    to_slot.set_slot_data(temp)
    ctx.log.info("Inventory", "物品交换完成")
```

## See Also

- [GF_UIDragManager / GF_UIDragHandler / GF_UIDragEvent](gf_ui_drag_system.md) — 拖拽系统的协议层（L1）
- [GF_UIService](gf_ui_service.md) — UI 管理服务（begin_drag、register_drop_target 的入口）
- [GF_UIPanel](gf_ui_panel.md) — 面板基类（Slot 的父容器）
