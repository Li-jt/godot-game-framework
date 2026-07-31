# 自定义拖拽处理器

## 概述

框架的拖拽系统采用三层架构：

- **L1 协议层**：`GF_UIDragManager` + `GF_UIDragHandler` — 核心状态机和事件驱动
- **L2 便利层**：`GF_UIDragSlot` + `GF_UIDragGhost` — 提供开箱即用的拖拽视觉效果
- **L3 游戏层**：业务相关的拖拽逻辑

当 L2 的 `GF_UIDragSlot` 不够灵活时（如需要自定义视觉、非矩形拖拽区域、复杂的放置条件），你可以继承 `GF_UIDragHandler` 实现完全自定义的拖拽行为。

## 拖拽生命周期

```
用户按下鼠标
  │
  ▼
on_begin_drag(event)  ← 开始拖拽。设置 drag_data、创建 visual
  │
  ▼
on_drag(event)        ← 每帧调用。更新视觉位置、世界预览
  │
  ▼ 用户松开鼠标
  │
  ├─→ 命中 DropTarget → on_drop(event)   ← 有接收者时调用
  │                      │                  返回 true=接受, false=拒绝
  │                      ▼
  └────────────────→ on_end_drag(event)  ← 无论如何都调用。清理 visual
```

## UIDragHandler 虚方法详解

### on_begin_drag(event: GF_UIDragEvent)

拖拽开始时调用一次。在此方法中：

1. 设置 `event.drag_data` — 告诉潜在的接收者你在拖什么
2. 调用 `event.show_ghost_xxx()` — 创建拖拽视觉

```gdscript
func on_begin_drag(p_event: GF_UIDragEvent) -> void:
    # 设置拖拽数据（接收方通过此数据判断是否接受）
    p_event.drag_data = {
        "type": "skill",
        "skill_id": "fireball",
        "slot_index": _slot_index,
    }

    # 创建拖拽视觉：用纹理
    p_event.show_ghost_from_texture(preload("res://icons/fireball.png"))

    # 或者：用文字（如物品数量）
    # p_event.show_ghost_from_label("x99")

    # 或者：完全自定义 Node
    # var custom := _create_custom_ghost()
    # p_event.show_ghost_from_node(custom)
```

### on_drag(event: GF_UIDragEvent)

每帧拖动中调用。`event.position` 和 `event.delta` 已由框架更新。

用于更新世界预览（如物品放置时的半透明预览、连线等）。

```gdscript
func on_drag(p_event: GF_UIDragEvent) -> void:
    # 更新世界坐标预览
    var world_pos := _screen_to_world(p_event.position)
    _preview_node.position = world_pos

    # 根据放置合法性改变预览颜色
    if _can_place_at(world_pos):
        _preview_node.modulate = Color.GREEN
    else:
        _preview_node.modulate = Color.RED
```

### on_drop(event: GF_UIDragEvent) -> bool

有接收者接受时调用（在 `on_end_drag` 之前）。返回 `true` 表示接受放置，`false` 表示拒绝。

默认为 `true`，游戏层按需覆写。

```gdscript
func on_drop(p_event: GF_UIDragEvent) -> bool:
    if p_event.drop_receiver == null:
        return false

    # 获取接收面板
    var receiver: GF_UIPanel = p_event.drop_receiver

    # 业务校验：技能不能拖到自己身上
    if receiver == _source_panel:
        return false

    return true
```

### on_end_drag(event: GF_UIDragEvent)

拖拽结束（无论如何都调用）。在此方法中：

1. 销毁 world preview
2. 清理临时状态
3. 如果 `event.drop_receiver` 非 null，说明有面板接受了放置

调用顺序：`on_drop`（如有）而后 `on_end_drag`（必有）。

```gdscript
func on_end_drag(p_event: GF_UIDragEvent) -> void:
    # 清理预览
    if is_instance_valid(_preview_node):
        _preview_node.queue_free()
        _preview_node = null

    # 处理成功的放置
    if p_event.drop_receiver != null:
        var data: Dictionary = p_event.drag_data
        _apply_skill_to_bar(data["skill_id"], p_event.drop_receiver)

    # 清理源 UI 状态
    _source_slot.highlight = false
```

## DragEvent 数据传递

`GF_UIDragEvent` 是拖拽过程中的核心数据结构：

| 字段 | 类型 | 说明 |
|------|------|------|
| `position` | Vector2 | 当前鼠标/触摸屏幕坐标 |
| `delta` | Vector2 | 上一帧到本帧的位移 |
| `button` | int | 触发拖拽的鼠标按键 |
| `drag_source` | GF_UIPanel | 拖拽发起的源面板 |
| `drag_data` | Variant | 游戏层设置的自定义数据 |
| `drop_receiver` | GF_UIPanel | 松手时命中的目标面板（`on_end_drag` 时可读取） |

## Ghost 自定义

框架提供三种 ghost 创建方式：

### 从纹理创建

```gdscript
p_event.show_ghost_from_texture(p_texture: Texture2D)
```

自动创建带纹理的 Control 节点，跟随鼠标移动。

### 从文字创建

```gdscript
p_event.show_ghost_from_label(p_text: String)
```

常用于显示物品数量等信息。

### 从自定义 Node 创建

```gdscript
p_event.show_ghost_from_node(p_node: Control)
```

传入完全自定义的 Control 节点，framework 负责把它挂到 SYSTEM 层并跟随鼠标。

```gdscript
func on_begin_drag(p_event: GF_UIDragEvent) -> void:
    var ghost := Control.new()
    ghost.custom_minimum_size = Vector2(64, 64)

    var icon := TextureRect.new()
    icon.texture = _item.icon
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.size = Vector2(64, 64)
    ghost.add_child(icon)

    if _item.count > 1:
        var label := Label.new()
        label.text = str(_item.count)
        label.add_theme_color_override("font_color", Color.WHITE)
        label.position = Vector2(4, 44)
        ghost.add_child(label)

    p_event.show_ghost_from_node(ghost)
```

## DropTarget 条件过滤

接收方通过 `GF_UIDropTarget` 声明它能接受什么类型的数据：

```gdscript
# 在接收方面板上
var drop_target := GF_UIDropTarget.new()
drop_target.accept_tags = ["skill", "item"]  # 只接受这些类型的拖拽数据
add_child(drop_target)
```

拖拽数据中的 `type` 字段用于匹配：

```gdscript
# 发送方
p_event.drag_data = {"type": "skill", "skill_id": "fireball"}

# 接收方的 accept_tags 包含 "skill" 即可匹配
```

## 完整示例：技能栏拖拽到快捷栏

```gdscript
# skill_drag_handler.gd
class_name SkillDragHandler
extends GF_UIDragHandler

var _skill_id: String
var _source_panel: GF_UIPanel
var _source_slot: Control
var _preview_node: Node2D = null
var _world_root: GF_WorldRoot = null


func _init(p_skill_id: String, p_source_panel: GF_UIPanel, p_source_slot: Control, p_world_root: GF_WorldRoot) -> void:
    _skill_id = p_skill_id
    _source_panel = p_source_panel
    _source_slot = p_source_slot
    _world_root = p_world_root


func on_begin_drag(p_event: GF_UIDragEvent) -> void:
    # 设置拖拽数据
    p_event.drag_data = {
        "type": "skill",
        "skill_id": _skill_id,
        "source_slot": _source_slot,
    }

    # 创建拖拽视觉
    var icon := _load_skill_icon(_skill_id)
    p_event.show_ghost_from_texture(icon)

    # 在世界中创建半透明预览
    _preview_node = Sprite2D.new()
    _preview_node.texture = icon
    _preview_node.modulate = Color(1, 1, 1, 0.5)
    _world_root.add_child(_preview_node)

    _source_slot.modulate = Color(1, 1, 1, 0.4)


func on_drag(p_event: GF_UIDragEvent) -> void:
    if _preview_node != null:
        var world_pos := _screen_to_world(p_event.position)
        _preview_node.global_position = world_pos


func on_drop(p_event: GF_UIDragEvent) -> bool:
    if p_event.drop_receiver == null:
        return false
    # 不能拖到自己的面板
    if p_event.drop_receiver == _source_panel:
        return false
    return true


func on_end_drag(p_event: GF_UIDragEvent) -> void:
    # 清理预览
    if is_instance_valid(_preview_node):
        _preview_node.queue_free()
    _preview_node = null

    # 恢复源 slot 外观
    _source_slot.modulate = Color.WHITE

    # 处理成功放置
    if p_event.drop_receiver != null:
        print("技能 %s 从 %s 拖到了 %s" % [
            _skill_id,
            _source_panel.name,
            p_event.drop_receiver.name,
        ])
```

```gdscript
# 在 UI 控件上发起拖拽
func _gui_input(p_event: InputEvent) -> void:
    if p_event is InputEventMouseButton:
        var mb := p_event as InputEventMouseButton
        if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
            var handler := SkillDragHandler.new(
                _skill_id, _panel, self, _world_root
            )
            _ui_service.begin_drag(handler, mb.global_position, mb.button_index, _panel)
```

## 与 L2 便利层的选择

| 场景 | 推荐方案 |
|------|---------|
| 物品栏拖拽（同类型 slot 间移动） | L2 `GF_UIDragSlot` |
| 需要自定义视觉的拖拽 | L3 `GF_UIDragHandler` |
| 跨面板复杂拖拽（带世界预览） | L3 `GF_UIDragHandler` |
| 拖拽到非 UI 区域（世界坐标） | L3 `GF_UIDragHandler` |
| 拖拽时需要业务校验 | 重写 `on_drop()` |
