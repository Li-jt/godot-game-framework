# 场景切换

## 场景描述

游戏需要在不同场景之间切换——从主菜单进入游戏世界，切换地图，或返回主菜单。框架的 `GF_SceneFactory` 负责场景实例化，`GF_WorldRoot` 作为游戏世界场景基类，6 层 UI Canvas 由 `GF_UIService` 在 `configure()` 中自动创建。

本章覆盖：UI 层结构、GF_WorldRoot 生命周期、加载/替换/卸载世界、加载 UI 面板到指定层、世界切换时的资源清理。

---

## 最小示例

```gdscript
# 1. 通过 GF_SceneFactory 加载世界场景
var result := scene_factory.create_and_add("res://content/worlds/forest_world.tscn", world_parent)
if result.is_fail():
    _log.error("Scene", "加载世界失败: %s" % result.error.message)

# 2. 替换世界（需要先清理旧世界、加载新世界）
_replace_world("res://content/worlds/dungeon_world.tscn", {"entrance": "north"})
```

---

## 逐步解释

### 第一步：理解 UI 层结构

GF_UIService 在 `configure()` 时自动创建以下节点树并挂到场景树：

```
Main (GameBootstrap)
├── UiCanvas (CanvasLayer) — UI 层（独立于相机，固定屏幕渲染）
│   └── UIRoot (Control)
│       ├── HudLayer        — HUD
│       ├── ScreenLayer     — 全屏面板
│       ├── PopupLayer      — 弹窗
│       ├── TooltipLayer    — 提示框
│       ├── SystemLayer     — 系统通知/拖拽 Ghost
│       └── DebugLayer      — 调试面板
└── ... (游戏世界节点由 Game 层自行管理)
```

关键架构原则：
- **World** 和 **UI** 分离：World 受相机移动/缩放影响，UI 独立渲染
- **UI 层持久**：6 层 UI 在应用生命周期内始终存在，由 GF_UIService 管理
- **可变内容**：只有 UI 层内的面板和世界场景节点在变化

### 第二步：编写 WorldRoot 子类

每个游戏世界场景的根节点必须继承 `GF_WorldRoot`（位于 `modules/world_root/`）：

```gdscript
# ---- forest_world.gd ----
class_name ForestWorld
extends GF_WorldRoot


func _on_world_setup() -> void:
    # _bootstrap 已注入，可在此使用所有服务
    var log := _bootstrap.service(GF_LogService) as GF_LogService
    log.info("ForestWorld", "世界初始化")

    # 从节点树收集 ISaveable
    var save_service := _bootstrap.service(GF_SaveService) as GF_SaveService
    save_service.collect_from_node(self)

    # 注册世界特定的输入上下文
    var world_ctx := GF_InputContext.new()
    world_ctx.name = "world"
    world_ctx.blocked_action_ids = ["ui_cancel"]
    var input := _bootstrap.service(GF_InputService) as GF_InputService
    input.push_context(world_ctx)

    # 生成地图、敌人等
    _spawn_entities()


func _on_world_exit() -> void:
    var log := _bootstrap.service(GF_LogService) as GF_LogService
    log.info("ForestWorld", "世界退出")
    # 清理订阅、取消 tick 注册、释放资源
    var input := _bootstrap.service(GF_InputService) as GF_InputService
    input.pop_context()
    var event_bus := _bootstrap.service(GF_EventBus) as GF_EventBus
    event_bus.clear_scope("forest_world")
```

### 第三步：加载世界

通过 `GF_SceneFactory` 加载世界场景，Game 层负责将实例添加到场景树：

```gdscript
# 加载世界场景文件
var result := scene_factory.create("res://content/worlds/town.tscn", {"entrance": "south_gate"})
if result.is_fail():
    _log.error("Scene", "加载失败: %s" % result.error.message)
    return

var world: Node = result.data
_world_parent.add_child(world)

# 如果根节点是 GF_WorldRoot 子类，注入 _bootstrap 并调用 _on_world_setup()
if world is GF_WorldRoot:
    world._bootstrap = _bootstrap
    world._on_world_setup()
```

### 第四步：替换世界

```gdscript
func _replace_world(p_path: String, p_data: Dictionary = {}) -> void:
    # 1. 退出旧世界
    for child in _world_parent.get_children():
        if child.has_method("_on_world_exit"):
            child._on_world_exit()

    # 2. 通知 SaveService 世界切换
    var save_service := _bootstrap.service(GF_SaveService) as GF_SaveService
    save_service.on_world_switch(_world_parent, null, "world.")

    # 3. 清空旧世界
    for child in _world_parent.get_children():
        child.queue_free()

    # 4. 加载新世界
    var result := scene_factory.create_and_add(p_path, _world_parent, p_data)
    if result.is_fail():
        _log.error("Scene", "加载失败: %s" % result.error.message)
        return

    var new_world := result.data as Node

    # 5. 通知 SaveService 新世界就绪
    save_service.on_world_switch(null, _world_parent, "world.")

    # 6. 初始化新世界
    if new_world is GF_WorldRoot:
        new_world._bootstrap = _bootstrap
        new_world._on_world_setup()
```

### 第五步：卸载世界

```gdscript
# 卸载但不加载新世界（返回主菜单时）
func _unload_world() -> void:
    for child in _world_parent.get_children():
        if child.has_method("_on_world_exit"):
            child._on_world_exit()
        child.queue_free()
```

### 第六步：加载 UI 面板到指定层

```gdscript
# 通过 GF_SceneFactory 加载 UI 场景到指定层
var result := scene_factory.create_and_add(
    "res://content/ui/inventory.tscn",
    ui_service.get_ui_layer(GF_UIPanelDef.KIND_SCREEN),
    {"owner": player_entity}
)

# 清空指定 UI 层
ui_service.clear_layer(GF_UIPanelDef.KIND_POPUP)
```

然而，绝大多数情况下应通过 `GF_UIService` 来管理面板，直接加载场景主要供框架内部使用。

### 第七步：访问 UI 结构

```gdscript
# 获取各种挂载点（通过 GF_UIService）
var ui_canvas: CanvasLayer = ui_service.get_ui_canvas()
var ui_root: Control = ui_service.get_ui_root()

# 获取指定 UI 层
var hud_layer: Control = ui_service.get_ui_layer(GF_UIPanelDef.KIND_HUD)
var screen_layer: Control = ui_service.get_ui_layer(GF_UIPanelDef.KIND_SCREEN)
```

---

## 完整示例：主菜单 → 游戏世界 → 返回主菜单

```gdscript
# ---- game_bootstrap.gd ----

class_name GameBootstrap
extends Node

var _world_parent: Node = null
var _scene_factory: GF_SceneFactory = null
var _ui_service: GF_UIService = null


func _ready() -> void:
    _world_parent = Node.new()
    _world_parent.name = "WorldParent"
    add_child(_world_parent)

    # GF_UIService 已通过 AppBootstrap 注册，UI 节点树已自动创建
    _ui_service = _bootstrap.service(GF_UIService) as GF_UIService
    _scene_factory = _bootstrap.service(GF_SceneFactory) as GF_SceneFactory

    # 加载主菜单面板
    _ui_service.open("main_menu")

    # 设置应用状态为 BOOT → MAIN_MENU
    var app_flow := _bootstrap.service(GF_AppFlow) as GF_AppFlow
    app_flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)


# ---- main_menu_panel.gd ----

class_name MainMenuPanel
extends GF_UIPanel


func _on_open(_p_data: Dictionary) -> void:
    $NewGameButton.pressed.connect(_on_new_game)
    $ContinueButton.pressed.connect(_on_continue)
    $QuitButton.pressed.connect(_on_quit)

    # 检查是否有存档
    var save_service := ctx.save_service
    var slots := save_service.list_slots()
    $ContinueButton.disabled = slots.is_fail() or (slots.data as Array).is_empty()


func _on_new_game() -> void:
    _start_game("res://content/worlds/tutorial_world.tscn")


func _on_continue() -> void:
    # 加载最新存档
    var save_service := ctx.save_service
    var slots := save_service.list_slots()
    var latest_meta = (slots.data as Array).back()
    var result := save_service.load_and_restore(latest_meta.slot_id)
    if result.is_fail():
        ctx.log.error("MainMenu", "加载存档失败")
        return
    _start_game("res://content/worlds/overworld.tscn")


func _start_game(p_world_path: String) -> void:
    # 1. 隐藏主菜单
    ctx.ui.close_all()

    # 2. 切换到加载状态
    ctx.flow.transition_to(GF_AppFlow.STATE_LOADING)

    # 3. 加载世界（Game 层通过 SceneFactory 加载并管理挂载）
    var scene_factory: GF_SceneFactory = ctx.scene_factory
    var result := scene_factory.create_and_add(p_world_path, _world_parent)
    if result.is_fail():
        ctx.log.error("MainMenu", "加载世界失败")
        ctx.flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)
        return

    var world := result.data as Node
    if world is GF_WorldRoot:
        world._bootstrap = _bootstrap
        world._on_world_setup()

    # 4. 显示游戏内 HUD
    ctx.ui.show_hud()

    # 5. 切换到游戏中状态
    ctx.flow.transition_to(GF_AppFlow.STATE_IN_GAME)


# ---- town_world.gd ----

class_name TownWorld
extends GF_WorldRoot

var _enemies: Array[Node] = []


func _on_world_setup() -> void:
    var log := _bootstrap.service(GF_LogService) as GF_LogService
    log.info("TownWorld", "城镇世界加载完成")

    # 收集存档
    var save_service := _bootstrap.service(GF_SaveService) as GF_SaveService
    save_service.collect_from_node(self)

    # 监听状态变化
    var event_bus := _bootstrap.service(GF_EventBus) as GF_EventBus
    event_bus.subscribe("portal_entered", _on_portal_entered, "town_world")

    # 注册输入上下文
    var town_ctx := GF_InputContext.new()
    town_ctx.name = "town"
    town_ctx.priority = 10
    var input := _bootstrap.service(GF_InputService) as GF_InputService
    input.push_context(town_ctx)

    # 初始化世界内容
    _spawn_npcs()
    _load_buildings()


func _on_world_exit() -> void:
    var event_bus := _bootstrap.service(GF_EventBus) as GF_EventBus
    event_bus.clear_scope("town_world")
    var input := _bootstrap.service(GF_InputService) as GF_InputService
    input.pop_context()
    _enemies.clear()


func _on_portal_entered(payload: Dictionary) -> void:
    var target_world := payload.get("target_world", "")
    var entrance := payload.get("entrance", "")

    if target_world.is_empty():
        return

    # 替换世界逻辑由 Game 层管理
    # _replace_world("res://content/worlds/%s.tscn" % target_world, {"entrance": entrance})


func _spawn_npcs() -> void:
    pass


func _load_buildings() -> void:
    pass


# ---- 返回主菜单 ----

func _on_return_to_main_menu() -> void:
    var ui_service := _bootstrap.service(GF_UIService) as GF_UIService
    var app_flow := _bootstrap.service(GF_AppFlow) as GF_AppFlow

    # 1. 隐藏 HUD
    ui_service.hide_hud()

    # 2. 关闭所有游戏面板
    ui_service.clear_gameplay_ui()

    # 3. 卸载世界
    _unload_world()

    # 4. 切回菜单状态
    app_flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)

    # 5. 打开主菜单
    ui_service.open("main_menu")
```

---

## 常见变体

### 变体 1：加载世界时传入入口数据

```gdscript
# 通过 SceneFactory 的 init_data 传入
scene_factory.create_and_add("res://content/worlds/dungeon.tscn", _world_parent, {
    "entrance": "east_door",
    "floor": 3,
    "seed": 12345,
})

# 在 _on_world_setup 中无法直接获取 init_data，可通过 _bootstrap 间接获取
```

### 变体 2：切换世界时保留 UI

```gdscript
# 世界切换时只清理世界，不关 UI
_replace_world(new_world_path)
# HUD 和游戏面板不受影响
```

### 变体 3：手动控制相机

```gdscript
# 相机由 Game 层自行管理（如通过 Camera2D 节点）
var camera: Camera2D = $GameCamera
camera.position = Vector2(500, 300)
camera.zoom = Vector2(2.0, 2.0)
```

---

## 错误码

GF_SceneFactory 的典型错误：

| 方法 | 可能的错误码 | 说明 |
|------|------------|------|
| `create(path, data)` | `ERR_IO` | 场景文件不存在或实例化失败 |
| `create_and_add(path, parent, data)` | `ERR_IO` | 同上 |

---

## See Also

- [创建和管理 UI 面板](./create-ui-panels.md) -- UI 面板的创建和分层
- [应用状态机](./app-state-flow.md) -- 状态驱动的场景切换
- [实现游戏存档](./save-game-progress.md) -- 世界切换时的存档管理
