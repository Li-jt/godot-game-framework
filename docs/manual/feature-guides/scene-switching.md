# 场景切换

## 场景描述

游戏需要在不同场景之间切换——从主菜单进入游戏世界，切换地图，或返回主菜单。框架的 `GF_SceneHost` 管理持久的挂载点结构，包括 6 层 UI Canvas、世界挂载点和独立相机。

本章覆盖：SceneHost 结构、加载/替换/卸载世界、WorldRoot 生命周期、加载 UI 面板到指定层、世界切换时的资源清理。

---

## 最小示例

```gdscript
# 1. 加载世界（通过 SceneHost）
var result := scene_host.load_world("res://content/worlds/forest_world.tscn")
if result.is_fail():
    _log.error("Scene", "加载世界失败: %s" % result.error.message)

# 2. 替换世界（带存档清理）
var result := scene_host.replace_world("res://content/worlds/dungeon_world.tscn", {"entrance": "north"})
```

---

## 逐步解释

### 第一步：理解 SceneHost 的节点树

```
Main (GameBootstrap)
└── GF_SceneHost
    ├── GF_WorldRoot (Node2D)   — 游戏世界挂载点，受 GameCamera 影响
    ├── GameCamera (Camera2D)   — 游戏世界相机（用户可拖拽/缩放）
    └── UiCanvas (CanvasLayer)  — UI 层（独立于相机，固定屏幕渲染）
        └── UIRoot (Control)
            ├── HudLayer        — HUD
            ├── ScreenLayer     — 全屏面板
            ├── PopupLayer      — 弹窗
            ├── TooltipLayer    — 提示框
            ├── SystemLayer     — 系统通知/拖拽 Ghost
            └── DebugLayer      — 调试面板
```

关键架构原则：
- **World** 和 **UI** 分离：World 受相机移动/缩放影响，UI 独立渲染
- **持久结构**：GF_SceneHost 和 6 层 UI 在应用生命周期内始终存在
- **可变内容**：只有 WorldRoot 下的子节点和 UI 层内的面板在变化

### 第二步：编写 WorldRoot 子类

每个游戏世界场景的根节点必须继承 `GF_WorldRoot`：

```gdscript
# ---- forest_world.gd ----
class_name ForestWorld
extends GF_WorldRoot


func _on_world_setup() -> void:
    # ctx 已由 GF_SceneHost 注入，可在此使用所有服务
    ctx.log.info("ForestWorld", "世界初始化")

    # 从节点树收集 ISaveable
    ctx.save.collect_from_node(self)

    # 注册世界特定的输入上下文
    var world_ctx := GF_InputContext.new()
    world_ctx.name = "world"
    world_ctx.blocked_action_ids = ["ui_cancel"]
    ctx.input.push_context(world_ctx)

    # 生成地图、敌人等
    _spawn_entities()


func _on_world_exit() -> void:
    ctx.log.info("ForestWorld", "世界退出")
    # 清理订阅、取消 tick 注册、释放资源
    ctx.input.pop_context()
    ctx.event.clear_scope("forest_world")
```

### 第三步：加载世界

```gdscript
# 加载世界场景到 WorldRoot 下
var result := scene_host.load_world("res://content/worlds/town.tscn")
if result.is_fail():
    _log.error("Scene", "加载失败: %s" % result.error.message)
    return

# 可选传入数据
var result := scene_host.load_world("res://content/worlds/town.tscn", {
    "entrance": "south_gate",
    "time_of_day": "morning",
})
```

`load_world` 内部流程：
1. 清空 WorldRoot 下所有旧子节点（`clear_world()`）
2. 通过 SceneFactory 实例化新场景
3. 将实例添加为 WorldRoot 的子节点
4. 如果实例是 `GF_WorldRoot` 子类，注入 `ctx` 并调用 `_on_world_setup()`

### 第四步：替换世界

```gdscript
# replace_world 会正确处理存档切换
var result := scene_host.replace_world("res://content/worlds/battle.tscn", {
    "enemy_group": "goblins",
})
```

`replace_world` 与 `load_world` 的区别：
1. 先调用旧世界每个子节点的 `_on_world_exit()`
2. 调用 `save_service.on_world_switch(old_root, null, "world.")` 注销旧世界 ISaveable
3. 清除旧世界子节点
4. 加载新场景
5. 调用 `save_service.on_world_switch(null, new_root, "world.")` 收集新世界 ISaveable

### 第五步：卸载世界

```gdscript
# 卸载但不加载新世界（返回主菜单时）
scene_host.unload_world()
```

`unload_world` 调用每个子节点的 `_on_world_exit()` 然后释放。

### 第六步：加载 UI 面板到指定层

```gdscript
# 直接加载（不经过 UIService）
var result := scene_host.load_ui_panel(
    GF_UIPanelDef.KIND_SCREEN,
    "res://content/ui/inventory.tscn",
    {"owner": player_entity}
)

# 清空指定 UI 层
scene_host.clear_layer(GF_UIPanelDef.KIND_POPUP)
```

然而，绝大多数情况下应通过 `GF_UIService` 来管理面板，`load_ui_panel` 主要供框架内部使用。

### 第七步：访问场景结构

```gdscript
# 获取各种挂载点
var world_root: Node2D = scene_host.get_world_root()
var camera: Camera2D = scene_host.get_camera()
var ui_root: Control = scene_host.get_ui_root()
var ui_canvas: CanvasLayer = scene_host.get_ui_canvas()

# 获取指定 UI 层
var hud_layer: Control = scene_host.get_ui_layer(GF_UIPanelDef.KIND_HUD)
var screen_layer: Control = scene_host.get_ui_layer(GF_UIPanelDef.KIND_SCREEN)

# 检查运行时是否就绪
if scene_host.is_runtime_ready():
    pass
```

---

## 完整示例：主菜单 → 游戏世界 → 返回主菜单

```gdscript
# ---- game_bootstrap.gd ----

class_name GameBootstrap
extends Node


func _ready() -> void:
    # 配置 SceneHost
    var result := scene_host.configure(scene_factory, log_service)
    if result.is_fail():
        _log.error("Bootstrap", "SceneHost 配置失败")
        return

    # 设置世界上下文
    scene_host.set_world_context(game_services)

    # 加载主菜单面板
    ui_service.open("main_menu")

    # 设置应用状态为 BOOT → MAIN_MENU
    app_flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)


# ---- main_menu_panel.gd ----

class_name MainMenuPanel
extends GF_UIPanel


func _on_open(_p_data: Dictionary) -> void:
    $NewGameButton.pressed.connect(_on_new_game)
    $ContinueButton.pressed.connect(_on_continue)
    $QuitButton.pressed.connect(_on_quit)

    # 检查是否有存档
    var slots := ctx.save.list_slots()
    $ContinueButton.disabled = slots.is_fail() or (slots.data as Array).is_empty()


func _on_new_game() -> void:
    _start_game("res://content/worlds/tutorial_world.tscn")


func _on_continue() -> void:
    # 加载最新存档
    var slots := ctx.save.list_slots()
    var latest_meta = (slots.data as Array).back()
    var result := ctx.save.load_and_restore(latest_meta.slot_id)
    if result.is_fail():
        ctx.log.error("MainMenu", "加载存档失败")
        return
    _start_game("res://content/worlds/overworld.tscn")


func _start_game(p_world_path: String) -> void:
    # 1. 隐藏主菜单
    ctx.ui.close_all()

    # 2. 切换到加载状态
    ctx.flow.transition_to(GF_AppFlow.STATE_LOADING)

    # 3. 加载世界
    var result := ctx.scene_host.load_world(p_world_path)
    if result.is_fail():
        ctx.log.error("MainMenu", "加载世界失败")
        ctx.flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)
        return

    # 4. 显示游戏内 HUD
    ctx.ui.show_hud()

    # 5. 切换到游戏中状态
    ctx.flow.transition_to(GF_AppFlow.STATE_IN_GAME)


# ---- town_world.gd ----

class_name TownWorld
extends GF_WorldRoot

var _enemies: Array[Node] = []


func _on_world_setup() -> void:
    ctx.log.info("TownWorld", "城镇世界加载完成")

    # 收集存档
    ctx.save.collect_from_node(self)

    # 监听状态变化
    ctx.event.subscribe("portal_entered", _on_portal_entered, "town_world")

    # 注册输入上下文
    var town_ctx := GF_InputContext.new()
    town_ctx.name = "town"
    town_ctx.priority = 10
    ctx.input.push_context(town_ctx)

    # 初始化世界内容
    _spawn_npcs()
    _load_buildings()


func _on_world_exit() -> void:
    ctx.event.clear_scope("town_world")
    ctx.input.pop_context()
    _enemies.clear()


func _on_portal_entered(payload: Dictionary) -> void:
    var target_world := payload.get("target_world", "")
    var entrance := payload.get("entrance", "")

    if target_world.is_empty():
        return

    # 替换世界
    ctx.scene_host.replace_world("res://content/worlds/%s.tscn" % target_world, {
        "entrance": entrance,
    })


func _spawn_npcs() -> void:
    pass


func _load_buildings() -> void:
    pass


# ---- 返回主菜单 ----

func _on_return_to_main_menu() -> void:
    # 1. 隐藏 HUD
    ctx.ui.hide_hud()

    # 2. 关闭所有游戏面板
    ctx.ui.clear_gameplay_ui()

    # 3. 卸载世界
    ctx.scene_host.unload_world()

    # 4. 切回菜单状态
    ctx.flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)

    # 5. 打开主菜单
    ctx.ui.open("main_menu")
```

---

## 常见变体

### 变体 1：加载世界时传入入口数据

```gdscript
# 通过入口点指定玩家出生位置
scene_host.load_world("res://content/worlds/dungeon.tscn", {
    "entrance": "east_door",
    "floor": 3,
    "seed": 12345,
})

# 在 _on_world_setup 中使用
func _on_world_setup() -> void:
    # ctx.scene_host 的 load_world 会将 data 传给 _on_world_setup
    # 但实际流程中 data 是通过 factory 的 init_data 传入的
    pass
```

### 变体 2：切换世界时保留 UI

```gdscript
# 世界切换时只清理世界，不关 UI
ctx.scene_host.replace_world(new_world_path)
# HUD 和游戏面板不受影响
```

### 变体 3：手动控制相机

```gdscript
var camera: Camera2D = scene_host.get_camera()
camera.position = Vector2(500, 300)
camera.zoom = Vector2(2.0, 2.0)
```

---

## 错误码

SceneHost 的方法错误码取决于底层的 `GF_SceneFactory`。典型错误：

| 方法 | 可能的错误码 | 说明 |
|------|------------|------|
| `configure(factory, log)` | `ERR_BAD_REQUEST` | 任一参数为 null |
| `load_world(path, data)` | 取决于 SceneFactory | 场景文件不存在或加载失败 |
| `replace_world(path, data)` | 取决于 SceneFactory | 同上 |
| `load_ui_panel(kind, path, data)` | 取决于 SceneFactory | 场景文件加载失败 |

---

## See Also

- [创建和管理 UI 面板](./create-ui-panels.md) -- UI 面板的创建和分层
- [应用状态机](./app-state-flow.md) -- 状态驱动的场景切换
- [实现游戏存档](./save-game-progress.md) -- 世界切换时的存档管理
