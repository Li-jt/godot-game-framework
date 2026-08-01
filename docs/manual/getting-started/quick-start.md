# 快速开始

本章带你从安装到运行第一个基于 Godot Game Framework 的项目。

## 前置条件

- **Godot 4.7**（或更高版本）
- **GDScript 基础**（了解 `Node`、`RefCounted`、类型标注）

## Step 1：安装框架

```bash
# 方式一：Git Submodule（推荐）
git submodule add https://github.com/Li-jt/godot-game-framework.git addons/godot-game-framework

# 方式二：直接复制
cp -r godot-game-framework addons/godot-game-framework
```

安装后的项目结构：

```text
your-game/
├── project.godot
├── content/                  # 你的游戏资源
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

点击运行 — 控制台输出：

```
[Framework] Godot Game Framework 就绪！
```

框架已经跑起来了。不需要创建配置文件、不需要写代码。

---

## 接下来：搭建你自己的游戏

`default_main.tscn` 使用的是框架自带的 `GF_DefaultBootstrap`，它不注册任何可选模块。要搭建你自己的游戏，创建自己的 Bootstrap。

### 创建自己的 Bootstrap

```gdscript
# src/application/my_game.gd
class_name MyGame
extends GF_AppBootstrap

func _assemble() -> void:
    # 框架内置了 6 个基础服务（自动就绪，不需要手动注册）：
    # Log、EventBus、PathResolver、Scheduler、FileSystem、RuntimeService

    # 按需注册你需要的模块 — 不注册就不存在
    register(GF_EcsWorld.new())
    register(GF_EcsScheduler.new())
    register(GF_SaveService.new())       # LocalSaveProvider 自动级联注册
    register(GF_InputService.new())       # InputAdapter 自动级联注册

    # 不想要 UI 系统？不注册就行。不想要 Audio？不注册就行


func _on_ready() -> void:
    var log := service(GF_LogService) as GF_LogService
    var world := service(GF_EcsWorld) as GF_EcsWorld
    var ecs_scheduler := service(GF_EcsScheduler) as GF_EcsScheduler

    log.info("MyGame", "游戏初始化开始")

    # 注册 ECS 系统
    ecs_scheduler.register_system(
        MovementSystem.new(),
        GF_EcsScheduler.GROUP_SIMULATION,
        MovementSystem.descriptor()
    )

    # 创建初始实体
    var player_id := world.spawn()
    world.set_component(player_id, &"Position", {"x": 100.0, "y": 200.0})
    world.set_component(player_id, &"Velocity", {"x": 0.0, "y": 0.0})

    log.info("MyGame", "游戏初始化完成，玩家实体: %d" % player_id)
```

### 创建主场景

新建一个场景，根节点挂载 `MyGame` 脚本，保存为 `scenes/main.tscn`。

更新 `project.godot`：

```ini
[application]
run/main_scene="res://scenes/main.tscn"
```

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

## 核心 API 速查

```gdscript
# 注册服务（单个或数组）
register(GF_EcsWorld.new())
register([GF_EcsWorld.new(), GF_EcsScheduler.new()])

# 获取服务（class_name 引用，类型安全）
var log := service(GF_LogService) as GF_LogService
var world := service(GF_EcsWorld) as GF_EcsWorld

# 发送命令（Command 是一等公民）
send_command(MyCommand.new())
```

## Service 统一写法

```gdscript
class_name MyService
extends GF_ModuleLifecycle

# 声明依赖 — 返回 class_name 引用数组，禁止字符串
func dependencies() -> Array:
    return [GF_LogService, GF_PathResolver]

# 配置 — 依赖已就绪，从 bootstrap 获取
func configure() -> GF_OperationResult:
    var log: GF_LogService = _bootstrap.service(GF_LogService) as GF_LogService
    return GF_OperationResult.ok()

# 可选：自注册默认依赖（用户无需手动注册）
func _set_bootstrap(p_bs) -> void:
    _bootstrap = p_bs
    if _bootstrap.service(GF_XxxProvider) == null:
        _bootstrap.register(GF_DefaultXxxProvider.new())
```

---

## 运行流程

框架每次启动的标准流程：

1. 内置服务安装（Log、EventBus、PathResolver、Scheduler、FileSystem、RuntimeService）
2. 调用 `_assemble()` — 你注册需要的模块
3. `_init_all()` — 拓扑排序，按依赖顺序 init → configure → ready
4. 调用 `_on_ready()` — 所有服务就绪，你在这里注册 ECS 系统、创建实体

---

**下一步**: [核心概念](../core-concepts/ecs-world.md) 深入了解 ECS 世界，或 [编辑器工具](installation.md#编辑器工具可选) 安装右键模板。
