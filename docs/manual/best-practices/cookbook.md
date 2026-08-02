# 菜谱式解决方案

本文提供 10 个常见游戏功能的完整代码方案。每个方案包含问题描述、涉及模块、完整代码和关键说明。

---

## 1. 如何实现暂停菜单？

**问题：** 按下 ESC 时弹出暂停菜单，游戏冻结，关闭后恢复。

**涉及模块：** GF_AppFlow, GF_InputService, GF_UIService, GF_EventBus

```gdscript
# pause_manager.gd
class_name PauseManager
extends RefCounted

var _app_flow: GF_AppFlow = null
var _ui: GF_UIService = null
var _input: GF_InputService = null
var _event_bus: GF_EventBus = null
var _is_paused: bool = false


func configure(p_context: GF_GameServices) -> void:
    _app_flow = p_context.app_flow
    _ui = p_context.ui
    _input = p_context.input
    _event_bus = p_context.event_bus

    # 监听 ESC 按下
    _event_bus.subscribe("input_pause", _on_pause_pressed, "pause_manager")

    # 监听 Flow 状态变化，自动处理面板开关
    _event_bus.subscribe("flow_state_changed", _on_flow_changed, "pause_manager")


func _on_pause_pressed(_data = null) -> void:
    if _is_paused:
        _resume()
    else:
        _pause()


func _pause() -> void:
    var result := _app_flow.transition_to(GF_AppFlow.STATE_PAUSE)
    if result.is_fail():
        return
    _is_paused = true

    # 打开暂停面板，阻挡游戏输入
    _ui.open("PauseMenu", {"reason": "user_pause"})

    # 推入输入上下文：暂停时只允许 UI 操作
    var ctx := GF_InputContext.new()
    ctx.name = "pause"
    ctx.allowed_actions = ["ui_accept", "ui_cancel"]
    _input.push_context(ctx)


func _resume() -> void:
    _app_flow.transition_to(GF_AppFlow.STATE_IN_GAME)
    _is_paused = false

    # 关闭暂停面板
    _ui.close("PauseMenu")

    # 恢复游戏输入
    _input.pop_context()


func _on_flow_changed(p_data: Dictionary) -> void:
    var new_state := p_data.get("new_state", &"")
    if new_state == GF_AppFlow.STATE_PAUSE:
        # 其他模块收到暂停通知，自行处理
        pass
    elif new_state == GF_AppFlow.STATE_IN_GAME:
        pass
```

**关键说明：**
- 使用 `GF_AppFlow` 管理状态，其他模块监听 `flow_state_changed` 事件做出响应。
- 暂停时推入 `GF_InputContext` 限制可用动作，防止游戏操作穿透。
- 面板通过 `game_input_block_mode` 声明输入阻挡策略。

---

## 2. 如何实现 WASD 角色移动？

**问题：** 用 WASD 键控制游戏角色在 2D 世界中移动。

**涉及模块：** GF_InputService, GF_EcsWorld, GF_EcsScheduler, GF_EcsSystem

```gdscript
# movement_system.gd
class_name MovementSystem
extends GF_EcsSystem

var _input: GF_InputService = null


func configure(p_input: GF_InputService) -> void:
    _input = p_input


func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    # 读取输入（每帧一次，避免在循环内重复读）
    var dx := _input.read_axis("move_right") - _input.read_axis("move_left")
    var dy := _input.read_axis("move_down") - _input.read_axis("move_up")
    var direction := Vector2(dx, dy).normalized()

    # 查询所有有 Position + Movement 的实体
    var query := GF_EcsQuery.new()
    query.with_component(&"Position")
    query.with_component(&"Movement")

    for row in query.execute(p_world):
        var movement: Dictionary = row.get(&"Movement")
        var speed: float = movement.get("speed", 200.0)

        var new_pos: Dictionary = row.get(&"Position").duplicate()
        new_pos["x"] = new_pos.get("x", 0.0) + direction.x * speed * p_delta
        new_pos["y"] = new_pos.get("y", 0.0) + direction.y * speed * p_delta

        p_ecb.set_component(row.entity, &"Position", new_pos)
```

**注册输入动作（在 `_on_post_boot` 中）：**

```gdscript
func _register_movement_actions(p_input: GF_InputService) -> void:
    for action in [
        {"id": "move_up",    "key": "W"},
        {"id": "move_down",  "key": "S"},
        {"id": "move_left",  "key": "A"},
        {"id": "move_right", "key": "D"},
    ]:
        var def := GF_InputActionDef.new()
        def.action_id = action["id"]
        def.default_key = action["key"]
        p_input.register_action_def(def)
```

**关键说明：**
- 在 System 中只读查询 World，写入通过 ECB（EcsCommandBuffer）。
- 输入读取在循环外部完成一次，避免性能浪费。
- Movement 组件中的 speed 字段允许不同实体有不同的移动速度。

---

## 3. 如何在面板间传递数据？

**问题：** 打开物品详情面板时，需要传入当前选中的物品数据。

**涉及模块：** GF_UIService

```gdscript
# 打开面板时传入数据
func _on_item_clicked(p_item_id: String) -> void:
    var result := _ui.open("ItemDetail", {
        "item_id": p_item_id,
        "source": "inventory",
        "quantity": _get_item_count(p_item_id),
    })
    if result.is_fail():
        _log.error("UI", "打开物品详情失败: %s" % result.error.message)


# 在面板脚本中读取数据
# item_detail_panel.gd
class_name ItemDetailPanel
extends GF_UIPanel


func _on_panel_data(p_data: Dictionary) -> void:
    var item_id: String = p_data.get("item_id", "")
    var source: String = p_data.get("source", "")
    var quantity: int = p_data.get("quantity", 1)

    _display_item(item_id, source, quantity)
```

**关键说明：**
- 数据通过 `ui.open(panel_name, data)` 的第二个参数传入。
- 面板通过覆写 `_on_panel_data(p_data)` 接收数据。
- 数据应是可序列化的基础类型，避免传入 Node 引用。

---

## 4. 如何实现自动存档？

**问题：** 每隔 5 分钟自动保存一次游戏进度。

**涉及模块：** GF_SaveService, GF_Scheduler

```gdscript
# auto_save_manager.gd
class_name AutoSaveManager
extends RefCounted

const AUTO_SAVE_INTERVAL: float = 300.0  # 5 分钟
const AUTO_SAVE_SLOT: int = 0

var _save_service: GF_SaveService = null
var _timer: float = 0.0
var _dirty: bool = false  # 是否有未保存的变更


func configure(p_save: GF_SaveService, p_scheduler: GF_Scheduler) -> void:
    _save_service = p_save
    # 注册每帧回调来驱动定时器
    p_scheduler.register_frame_callback(_on_frame, "auto_save")


func mark_dirty() -> void:
    _dirty = true


func _on_frame(p_delta: float) -> void:
    _timer += p_delta
    if _timer >= AUTO_SAVE_INTERVAL and _dirty:
        _timer = 0.0
        _perform_auto_save()


func _perform_auto_save() -> void:
    var meta := GF_SaveMeta.new()
    meta.label = "auto_save_%s" % Time.get_datetime_string_from_system()

    var result := _save_service.save_all(AUTO_SAVE_SLOT, meta)
    if result.is_ok():
        _dirty = false
        print("自动存档完成")
    else:
        printerr("自动存档失败: %s" % result.error.message)
```

**关键说明：**
- 通过 `mark_dirty()` 避免在没有变更时频繁写盘。
- 自动存档使用独立的 slot 号（通常为 0），不干扰手动存档。
- 考虑在战斗等场景中延迟自动存档。

---

## 5. 如何实现多语言切换？

**问题：** 在设置面板中切换语言，所有 UI 文本自动刷新。

**涉及模块：** GF_LocalizationService, GF_EventBus

```gdscript
# 语言切换
func switch_language(p_lang: String) -> void:
    var result := _loc.set_language(p_lang)
    if result.is_fail():
        _log.error("Loc", "语言切换失败: %s" % result.error.message)
        return
    # 发布语言变更事件，UI 面板自行刷新
    _event_bus.publish("language_changed", {"lang": p_lang})


# 在 UI 面板中响应语言变更
func _ready() -> void:
    _event_bus.subscribe("language_changed", _on_language_changed, panel_name)


func _on_language_changed(_data: Dictionary) -> void:
    _refresh_texts()


func _refresh_texts() -> void:
    title_label.text = _loc.tr("ui.settings.title")
    back_button.text = _loc.tr("ui.common.back")
```

**关键说明：**
- 语言切换通过 EventBus 通知所有 UI 面板。
- 面板自行重新读取本地化文本。
- 文本 key 使用点号分隔的层级结构（如 `ui.settings.title`）。

---

## 6. 如何实现音频设置面板？

**问题：** 主音量、音效、背景音乐独立调节，并持久化设置。

**涉及模块：** GF_AudioService, GF_ISaveable

```gdscript
# audio_settings.gd
class_name AudioSettings
extends GF_ISaveable

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var bgm_volume: float = 1.0
var _audio: GF_AudioService = null


func configure(p_audio: GF_AudioService) -> void:
    _audio = p_audio


func apply() -> void:
    _audio.set_bus_volume("Master", master_volume)
    _audio.set_bus_volume("SFX", sfx_volume)
    _audio.set_bus_volume("BGM", bgm_volume)


func save_key() -> String:
    return "audio_settings"

func on_save() -> Dictionary:
    return {"master": master_volume, "sfx": sfx_volume, "bgm": bgm_volume}

func on_load(p_data: Dictionary) -> void:
    master_volume = p_data.get("master", 1.0)
    sfx_volume = p_data.get("sfx", 1.0)
    bgm_volume = p_data.get("bgm", 1.0)
    apply()  # 恢复后立即生效


# 在设置面板中
func _on_master_slider_changed(p_value: float) -> void:
    _settings.master_volume = p_value
    _settings.apply()
```

**关键说明：**
- AudioSettings 既是配置持有者也是 ISaveable，保存时自动持久化。
- `on_load()` 恢复后立即调用 `apply()` 使其生效。
- 音量使用 `0.0-1.0` 的线性值。

---

## 7. 如何实现物品栏拖拽？

**问题：** 物品栏中的物品可以在 slot 之间拖拽移动。

**涉及模块：** UIDragSlot, UIDropTarget, accept_tags

```gdscript
# 在物品栏 slot 上设置拖拽
func _ready() -> void:
    var drag_slot := GF_UIDragSlot.new()
    drag_slot.accept_tags = ["item"]
    drag_slot.drag_data_provider = _provide_drag_data
    drag_slot.on_receive = _on_receive_item
    add_child(drag_slot)

    # 同时作为放置目标
    var drop_target := GF_UIDropTarget.new()
    drop_target.accept_tags = ["item"]
    add_child(drop_target)


func _provide_drag_data() -> Dictionary:
    return {"type": "item", "item_id": _item.id, "count": _item.count, "slot_index": _index}


func _on_receive_item(p_data: Dictionary) -> bool:
    if p_data.get("type", "") != "item":
        return false

    # 交换物品逻辑
    var src_index: int = p_data.get("slot_index", -1)
    var item_id: String = p_data.get("item_id", "")
    var count: int = p_data.get("count", 0)

    _inventory.swap_items(src_index, _index)
    return true
```

**关键说明：**
- `accept_tags` 确保只有匹配类型的物品可以被放置。
- L2 的 `GF_UIDragSlot` 处理了大部分拖拽视觉。
- 复杂拖拽场景（如拖到世界坐标）请使用 L3 `GF_UIDragHandler`。

---

## 8. 如何实现成就系统？

**问题：** 监听游戏事件，当条件满足时解锁成就，并持久化。

**涉及模块：** GF_EventBus, GF_ISaveable, GF_SaveService

（完整代码见 [advanced/custom-saveable.md](custom-saveable.md) 中的成就系统示例）

```gdscript
# 核心流程
# 1. AchievementData extends GF_ISaveable — 持久化成就状态
# 2. AchievementSystem 监听 EventBus 事件 — 检测解锁条件
# 3. 解锁时更新数据 + 发布 achievement_unlocked 事件 — UI 刷新
```

**关键说明：**
- 成就定义（名称、描述、条件）属于内容数据，不应放在存档中。
- 存档只保存"是否已解锁"和"解锁时间"。
- 通过 EventBus 解耦成就检测和 UI 展示。

---

## 9. 如何实现简单的 AI 巡逻？

**问题：** NPC 在两个巡逻点之间来回移动。

**涉及模块：** GF_EcsWorld, GF_EcsSystem, GF_Pathfinder

```gdscript
# patrol_system.gd
class_name PatrolSystem
extends GF_EcsSystem


func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    var query := GF_EcsQuery.new()
    query.with_component(&"Position")
    query.with_component(&"Patrol")
    query.with_component(&"Movement")

    for row in query.execute(p_world):
        var patrol: Dictionary = row.get(&"Patrol")
        var pos: Dictionary = row.get(&"Position")
        var move: Dictionary = row.get(&"Movement")

        var waypoints: Array = patrol.get("waypoints", [])
        var current_index: int = patrol.get("index", 0)

        if waypoints.is_empty():
            continue

        var target: Vector2 = waypoints[current_index]
        var current: Vector2 = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
        var distance := current.distance_to(target)

        if distance < 4.0:
            # 到达巡逻点，切换下一个
            current_index = (current_index + 1) % waypoints.size()
            p_ecb.set_component(row.entity, &"Patrol", {
                "waypoints": waypoints,
                "index": current_index,
            })
        else:
            # 向目标点移动
            var dir := (target - current).normalized()
            var speed: float = move.get("speed", 100.0)
            var new_pos := {
                "x": pos["x"] + dir.x * speed * p_delta,
                "y": pos["y"] + dir.y * speed * p_delta,
            }
            p_ecb.set_component(row.entity, &"Position", new_pos)
```

**关键说明：**
- `Patrol` 组件包含巡逻路径和目标索引。
- 到达巡逻点时切换下一个目标（循环）。
- 使用简单的方向移动而非寻路，适合开阔场景。

---

## 10. 如何实现场景过渡效果？

**问题：** 从一个场景切换到另一个场景时，显示加载画面和过渡动画。

**涉及模块：** GF_SceneFactory, GF_AppFlow, GF_UIService

```gdscript
# scene_transition.gd
class_name SceneTransition
extends RefCounted

var _scene_factory: GF_SceneFactory = null
var _app_flow: GF_AppFlow = null
var _ui: GF_UIService = null
var _log: GF_LogService = null
var _world_parent: Node = null


func configure(p_context: GF_GameServices, p_world_parent: Node) -> void:
    _scene_factory = p_context.scene_factory
    _app_flow = p_context.app_flow
    _ui = p_context.ui
    _log = p_context.log
    _world_parent = p_world_parent


func transition_to(p_world_id: String, p_entry_point: String = "") -> void:
    # 1. 切换到 LOADING 状态
    var flow_result := _app_flow.transition_to(GF_AppFlow.STATE_LOADING, {
        "world_id": p_world_id,
    })
    if flow_result.is_fail():
        _log.error("Scene", "Flow 切换失败: %s" % flow_result.error.message)
        return

    # 2. 打开加载画面
    var ui_result := _ui.open("LoadingScreen", {
        "message": "正在进入 %s..." % p_world_id,
    })
    if ui_result.is_fail():
        _log.warning("Scene", "加载画面打开失败")

    # 3. 通过 GF_SceneFactory 加载新场景
    var world_path := "res://content/worlds/%s.tscn" % p_world_id
    var result := _scene_factory.create_and_add(world_path, _world_parent, {
        "entry_point": p_entry_point,
    })
    if result.is_fail():
        _log.error("Scene", "场景加载失败: %s" % result.error.message)
        _app_flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)
        return

    # 4. 注入 _bootstrap 并初始化世界
    var world := result.data as Node
    if world is GF_WorldRoot:
        world._bootstrap = _bootstrap
        world._on_world_setup()

    # 5. 加载完成，切换到 IN_GAME
    _ui.close("LoadingScreen")
    _app_flow.transition_to(GF_AppFlow.STATE_IN_GAME)
```

**关键说明：**
- 场景加载前先切换到 `LOADING` 状态，阻塞游戏逻辑。
- 打开 LoadingScreen 面板提供用户反馈。
- 通过 `GF_SceneFactory` 加载场景，Game 层管理世界父节点。
- 加载完成后恢复 `IN_GAME` 状态。
