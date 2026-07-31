# 快速开始

本章带你从零创建第一个基于 Godot Game Framework 的项目。你将定义数据组件、编写逻辑系统、注册服务并启动应用。

## 前置条件

- **Godot 4.7**（或更高版本）
- **GDScript 基础**（了解 `Node`、`RefCounted`、类型标注）
- 框架已安装到项目的 `src/framework/` 目录下（参见[安装指南](installation.md)）

## 关于主场景

框架提供了一个预配置好的主场景文件 `engine/scene_host/scene_host.tscn`，包含以下预设节点结构：

```
SceneHost (GF_SceneHost)
├── WorldMount   (Node2D)   — 游戏世界挂载点
├── GameCamera   (Camera2D) — 游戏相机（默认 640×360，zoom 1.5）
└── UiCanvas     (CanvasLayer)
    └── UIRoot   (Control)
        ├── HudLayer       — HUD 面板层（始终在最前）
        ├── ScreenLayer    — 全屏面板层
        ├── PopupLayer     — 弹窗层
        ├── TooltipLayer   — 提示层
        ├── SystemLayer    — 系统弹窗层（最高优先级）
        └── DebugLayer     — 调试面板层
```

框架启动时会自动从 `src/framework/engine/scene_host/scene_host.tscn` 加载此场景，**大多数情况下你不需要手动操作**。

如果你需要自定义 SceneHost 的节点结构（比如调整相机参数、增减 UI 层）：

1. 将 `src/framework/engine/scene_host/scene_host.tscn` 复制到你的 `scenes/` 目录
2. 在 Godot 编辑器中打开副本，按需调整
3. 在 `config/app_config.json` 中通过 `path_resolver` 覆盖场景路径：

```json
{
  "path_resolver": {
    "scene_host": "res://scenes/scene_host.tscn"
  }
}
```

如果你不使用框架预设，则需要自己创建主场景，根节点挂载 `GF_AppBootstrap` 子类脚本，并确保场景中包含框架所需的世界挂载点、相机和 UI 层级。

## Step 1：创建 Application 入口

首先创建一个继承 `GF_AppBootstrap` 的启动类。这是整个应用的入口，负责装配所有服务。

```gdscript
# src/application/my_game_bootstrap.gd
extends GF_AppBootstrap
class_name MyGameBootstrap


## 所有服务装配完成后调用，在这里初始化你的游戏数据。
func _on_post_boot(context: GF_GameServices) -> GF_OperationResult:
    context.log.info("MyGame", "游戏初始化开始")

    # 注册你的 ECS 系统
    var scheduler: GF_EcsScheduler = context.ecs_scheduler
    var register_result := scheduler.register_system(
        MovementSystem.new(),
        GF_EcsScheduler.GROUP_SIMULATION,
        MovementSystem.descriptor()
    )
    if register_result.is_fail():
        return register_result

    # 启动 ECS
    scheduler.start()

    # 创建初始实体
    var world: GF_EcsWorld = context.ecs_world
    var player_id := world.spawn()
    world.set_component(player_id, &"Position", {"x": 100.0, "y": 200.0})
    world.set_component(player_id, &"Velocity", {"x": 0.0, "y": 0.0})

    context.log.info("MyGame", "游戏初始化完成，玩家实体: %d" % player_id)
    return GF_OperationResult.ok()
```

然后在 Godot 的主场景中挂载这个脚本。创建一个节点，把 `MyGameBootstrap` 脚本挂上去。当场景的 `_ready()` 触发时，框架会自动执行完整的启动流程。

## Step 2：定义第一个 ECS 组件

组件是纯数据，用普通的 GDScript `Dictionary` 即可。对于复杂组件，可以继承 `GF_EcsComponentBase`。

```gdscript
# src/game/components/position.gd
class_name PositionComponent
extends GF_EcsComponentBase


## 位置数据（像素坐标）
var x: float = 0.0
var y: float = 0.0


func get_component_type() -> StringName:
    return &"Position"


func serialize() -> Dictionary:
    return {"x": x, "y": y}


func deserialize(p_data: Dictionary) -> void:
    x = p_data.get("x", 0.0)
    y = p_data.get("y", 0.0)


static func from_dict(p_data: Dictionary) -> PositionComponent:
    var instance := PositionComponent.new()
    instance.deserialize(p_data)
    return instance


func get_pos() -> Vector2:
    return Vector2(x, y)
```

更简单的做法是直接使用 Dictionary：

```gdscript
# 添加一个位置组件（纯字典，不需要定义类）
world.add_component(entity_id, &"Position", {"x": 100.0, "y": 200.0})

# 添加一个速度组件
world.add_component(entity_id, &"Velocity", {"x": 0.0, "y": 0.0})

# 添加一个血量组件
world.add_component(entity_id, &"Health", {"current": 100, "max": 100})
```

使用 Dictionary 组件更轻量，适合简单数据。使用 `GF_EcsComponentBase` 子类适合需要序列化、验证逻辑或工厂注册的组件。

## Step 3：写第一个 ECS 系统

系统是纯逻辑，通过查询找到拥有特定组件的实体，通过命令缓冲修改数据。

```gdscript
# src/game/systems/movement_system.gd
class_name MovementSystem
extends GF_EcsSystem


## 构建此系统的描述元数据（供调度器排序用）
static func descriptor() -> GF_EcsSystemDescriptor:
    var desc := GF_EcsSystemDescriptor.new()
    desc.system_name = "MovementSystem"
    desc.group_name = GF_EcsScheduler.GROUP_SIMULATION
    desc.priority = 0
    return desc


func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    # 构建查询：找到同时有 Position 和 Velocity 的实体
    var query := GF_EcsQuery.new()
    query.with_component(&"Position").with_component(&"Velocity")
    var plan := query.build()

    var result := plan.execute(p_world)
    result.for_each(func(row: GF_EcsQueryRow) -> void:
        var pos: Dictionary = row.get_component(&"Position")
        var vel: Dictionary = row.get_component(&"Velocity")

        # 计算新位置
        var new_x: float = pos["x"] + vel["x"] * p_delta
        var new_y: float = pos["y"] + vel["y"] * p_delta

        # 通过 ECB 写回（不直接修改 World）
        p_ecb.set_component(row.entity, &"Position", {"x": new_x, "y": new_y})
    )
```

**关键点**：系统永远通过 `p_ecb`（`GF_EcsCommandBuffer`）修改数据，不直接调用 `p_world.set_component()`。这样调度器可以在系统执行完毕后统一提交，避免迭代中的不一致。

## Step 4：注册服务和启动

回到 `MyGameBootstrap._on_post_boot()`，把系统注册到调度器并初始化世界：

```gdscript
func _on_post_boot(context: GF_GameServices) -> GF_OperationResult:
    var log: GF_LogService = context.log
    var world: GF_EcsWorld = context.ecs_world
    var scheduler: GF_EcsScheduler = context.ecs_scheduler

    # 1. 注册系统
    scheduler.register_system(
        MovementSystem.new(),
        GF_EcsScheduler.GROUP_SIMULATION,
        MovementSystem.descriptor()
    )

    # 2. 注册更多系统（可选的 AI 系统）
    # scheduler.register_system(AISystem.new(), GF_EcsScheduler.GROUP_SIMULATION, AISystem.descriptor())

    # 3. 启动 ECS 调度器（初始化所有系统的 on_init()）
    scheduler.start()

    # 4. 创建初始实体
    var player_id := world.spawn()
    world.set_component(player_id, &"Position", {"x": 100.0, "y": 100.0})
    world.set_component(player_id, &"Velocity", {"x": 50.0, "y": 0.0})

    log.info("MyGame", "ECS 就绪，玩家实体: %d" % player_id)
    return GF_OperationResult.ok()
```

你的主场景节点挂载 `MyGameBootstrap` 脚本，运行后：
1. 框架自动加载 `config/app_config.json`
2. 依次安装 Core → Engine → ECS → Service
3. 调用 `_on_post_boot()`，你在此注册系统和创建实体
4. 每帧调度器驱动 `MovementSystem.on_tick()`，实体位置自动更新

## 查看运行效果

要验证 MovementSystem 确实在工作，你可以添加一个简单的调试脚本：

```gdscript
# 在 _on_post_boot 最后添加一个 tick 回调来打印位置
context.scheduler.register(
    GF_Scheduler.TickGroup.PRESENTATION,
    "DebugPrinter",
    func(p_delta: float) -> void:
        var pos = world.get_component(player_id, &"Position")
        if pos != null:
            log.debug("Debug", "玩家位置: (%.1f, %.1f)" % [pos.x, pos.y])
)
```

运行后你应该在日志中看到位置每帧递增。

## 完整项目示例

```text
my-game/
├── project.godot
├── config/
│   └── app_config.json
├── src/
│   ├── framework/              # 框架代码（submodule 或复制）
│   └── game/
│       └── systems/
│           └── movement_system.gd
└── scenes/
    └── main.tscn               # 根节点挂载 MyGameBootstrap 脚本
```

---

**下一步**: [安装指南](installation.md) — 详细安装步骤，或 [ECS 世界](core-concepts/ecs-world.md) 深入了解 ECS。
