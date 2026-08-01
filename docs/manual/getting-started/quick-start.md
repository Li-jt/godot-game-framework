# 快速开始

本章带你从安装到运行第一个基于 Godot Game Framework 的项目。

## 前置条件

- **Godot 4.7**（或更高版本）
- **GDScript 基础**（了解 `Node`、`RefCounted`、类型标注）

## Step 1：安装框架

框架通过 Godot Asset Library 或 Git Submodule 安装到 `addons/godot-game-framework/`。详见[安装指南](installation.md)。

安装后的项目结构：

```text
your-game/
├── project.godot
├── config/                   # （可选）覆盖默认配置
│   └── app_config.json
├── content/                  # 游戏资源
└── addons/
    └── godot-game-framework/ # 框架
```

## Step 2：配置主场景

在 `project.godot` 中设置框架自带的默认主场景：

```ini
[application]
run/main_scene="res://addons/godot-game-framework/scenes/default_main.tscn"
```

## Step 3：运行

点击运行 —— 控制台输出：

```
[Framework] Godot Game Framework 就绪！
[Framework]   应用: My Game v0.1.0
[Framework]   运行模式: Local
```

框架已经跑起来了。不需要创建配置文件、不需要写代码。

---

## 接下来：搭建你自己的游戏

`scenes/default_main.tscn` 使用的是框架自带的 `GF_DefaultBootstrap`。要搭建你自己的游戏，你需要替换掉它。

### 创建自己的 Bootstrap

```gdscript
# src/application/my_game_bootstrap.gd
class_name MyGameBootstrap
extends GF_AppBootstrap


func _on_post_boot(context: GF_GameServices) -> GF_OperationResult:
    context.log.info("MyGame", "游戏初始化开始")

    # 注册你的 ECS 系统
    var scheduler: GF_EcsScheduler = context.ecs_scheduler
    scheduler.register_system(
        MovementSystem.new(),
        GF_EcsScheduler.GROUP_SIMULATION,
        MovementSystem.descriptor()
    )
    scheduler.start()

    # 创建初始实体
    var world: GF_EcsWorld = context.ecs_world
    var player_id := world.spawn()
    world.set_component(player_id, &"Position", {"x": 100.0, "y": 200.0})
    world.set_component(player_id, &"Velocity", {"x": 0.0, "y": 0.0})

    context.log.info("MyGame", "游戏初始化完成，玩家实体: %d" % player_id)
    return GF_OperationResult.ok()
```

### 创建主场景

新建一个场景，根节点挂载 `MyGameBootstrap` 脚本，保存为 `scenes/main.tscn`。

更新 `project.godot`：

```ini
[application]
run/main_scene="res://scenes/main.tscn"
```

### 可选：覆盖默认配置

如果需要修改配置，在项目根目录创建 `config/app_config.json`：

```json
{
  "app": {
    "name": "My Awesome Game",
    "version": "1.0.0"
  },
  "logging": {
    "level": "Info"
  }
}
```

只需要写你要覆盖的字段，未覆盖的字段使用框架默认值。

---

## 定义 ECS 组件和系统

### 组件（纯数据）

```gdscript
# src/game/components/position.gd
class_name PositionComponent
extends GF_EcsComponentBase


func get_component_type() -> StringName:
    return &"Position"


func serialize() -> Dictionary:
    return {"x": x, "y": y}


func deserialize(p_data: Dictionary) -> void:
    x = p_data.get("x", 0.0)
    y = p_data.get("y", 0.0)


var x: float = 0.0
var y: float = 0.0
```

也可以直接用 Dictionary（更轻量）：

```gdscript
world.add_component(entity_id, &"Position", {"x": 100.0, "y": 200.0})
```

### 系统（纯逻辑）

```gdscript
# src/game/systems/movement_system.gd
class_name MovementSystem
extends GF_EcsSystem


static func descriptor() -> GF_EcsSystemDescriptor:
    var desc := GF_EcsSystemDescriptor.new()
    desc.system_name = "MovementSystem"
    desc.group_name = GF_EcsScheduler.GROUP_SIMULATION
    desc.priority = 0
    return desc


func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    var query := GF_EcsQuery.new()
    query.with_component(&"Position").with_component(&"Velocity")
    var plan := query.build()

    var result := plan.execute(p_world)
    result.for_each(func(row: GF_EcsQueryRow) -> void:
        var pos: Dictionary = row.get_component(&"Position")
        var vel: Dictionary = row.get_component(&"Velocity")

        var new_x: float = pos["x"] + vel["x"] * p_delta
        var new_y: float = pos["y"] + vel["y"] * p_delta

        p_ecb.set_component(row.entity, &"Position", {"x": new_x, "y": new_y})
    )
```

**关键点**：系统永远通过 `p_ecb`（`GF_EcsCommandBuffer`）修改数据，不直接调用 `p_world.set_component()`。

---

## 运行流程

框架每次启动的标准流程：

1. 加载框架自带的默认配置 `default_app_config.json`
2. 合并用户项目 `config/app_config.json`（如果存在）
3. 依次安装 Core → Engine → ECS → Service
4. 调用 `_on_post_boot()`，你可以在这里注册系统和创建实体
5. 进入 `MAIN_MENU` 状态，`_on_app_ready()` 触发
6. 每帧调度器驱动 ECS 系统

---

**下一步**: [核心概念](core-concepts/ecs-world.md) 深入了解 ECS 世界，或 [编辑器工具](installation.md#编辑器工具可选) 安装右键模板。
