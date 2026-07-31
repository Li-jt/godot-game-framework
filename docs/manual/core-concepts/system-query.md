# 系统与查询

**类比**：如果 ECS World 是一个数据库，**系统**就是遍历表、执行计算的批处理脚本，**查询**就是 SQL 语句——它定义了"处理哪些行"和"需要哪些列"。

## System 生命周期

每个 ECS 系统继承 `GF_EcsSystem`，拥有三个生命周期钩子：

```gdscript
class_name MyGameSystem
extends GF_EcsSystem


## 系统注册后、首次 tick 前调用一次。在此做一次性初始化。
func on_init(p_world: GF_EcsWorld) -> void:
    pass


## 每帧调用（或按 tick_interval 节流）。在此实现核心逻辑。
## p_ecb 是本帧的命令缓冲，写入的数据会在本组结束后统一 apply。
func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    pass


## 调度器停止时调用。在此做清理。
func on_shutdown() -> void:
    pass
```

| 钩子 | 何时调用 | 用途 |
|---|---|---|
| `on_init(world)` | 调度器 `start()` 时，所有系统的 `on_init` 按优先级顺序执行一次 | 创建持久数据、预计算、预热缓存 |
| `on_tick(world, ecb, delta)` | 每帧（或按 `tick_interval` 节流），按分组顺序执行 | 核心游戏逻辑 |
| `on_shutdown()` | 调度器 `stop()` 时 | 释放资源、持久化数据 |

## SystemDescriptor — 系统元数据

`GF_EcsSystemDescriptor` 描述了系统的执行参数：

```gdscript
static func descriptor() -> GF_EcsSystemDescriptor:
    var desc := GF_EcsSystemDescriptor.new()
    desc.system_name = "MovementSystem"           # 调试名称
    desc.group_name = GF_EcsScheduler.GROUP_SIMULATION  # 所属分组
    desc.priority = 0                             # 优先级（越小越先执行）
    desc.tick_interval = 0.0                      # 0 = 每帧，> 0 = 节流（秒）
    desc.before_systems = ["RenderSystem"]        # 必须在这些系统之前
    desc.after_systems = ["InputSystem"]          # 必须在这些系统之后
    desc.owner = "game"                           # 所有者（Mod 卸载用）
    return desc
```

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `system_name` | `String` | `""` | 系统名称，用于调试和性能统计 |
| `group_name` | `String` | `""` | 所属分组名称 |
| `priority` | `int` | `0` | 组内优先级，数值越小越先执行 |
| `tick_interval` | `float` | `0.0` | Tick 间隔（秒），`0.0` 表示每帧执行 |
| `before_systems` | `Array[String]` | `[]` | 必须在这些系统之前执行（声明依赖顺序） |
| `after_systems` | `Array[String]` | `[]` | 必须在这些系统之后执行 |
| `owner` | `String` | `""` | 系统注册者，Mod 卸载时按 owner 批量清理 |

## Fluent Query API — 构建查询

查询通过 `GF_EcsQuery` 流式构建：

```gdscript
var query := GF_EcsQuery.new()
query.with_component(&"Position")
     .with_component(&"Velocity")
     .without_component(&"Dead")
     .optional_component(&"Sprite")
var plan := query.build()
```

### with_component(type)

要求实体**必须**拥有指定组件。可以链式添加多个，实体必须全部满足。

### without_component(type)

要求实体**不得**拥有指定组件。用于排除特定状态（如排除已死亡的实体）。

### optional_component(type)

实体**可选**拥有此组件。不影响匹配与否，但如果拥有，数据会包含在查询结果中。

### build() — 构建查询计划

调用 `build()` 返回 `GF_EcsQueryPlan`。Query 是构建器（一次性使用），Plan 是预编译的查询对象（可重复使用，性能更好）。

**最佳实践**：在 `on_init()` 中构建 Plan 并缓存，在 `on_tick()` 中重用：

```gdscript
class_name MovementSystem
extends GF_EcsSystem


var _query_plan: GF_EcsQueryPlan = null


func on_init(p_world: GF_EcsWorld) -> void:
    _query_plan = GF_EcsQuery.new() \
        .with_component(&"Position") \
        .with_component(&"Velocity") \
        .build()


func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    var result := _query_plan.execute(p_world)
    # ... 处理结果
```

## QueryResult — 遍历结果

`GF_EcsQueryPlan.execute(world)` 返回 `GF_EcsQueryResult`，提供多种遍历方式。

### for_each() — 回调遍历

```gdscript
result.for_each(func(row: GF_EcsQueryRow) -> void:
    var pos: Dictionary = row.get_component(&"Position")
    var vel: Dictionary = row.get_component(&"Velocity")
    var sprite: Sprite2D = row.get_component(&"Sprite")  # optional

    # 修改数据
    var new_x := pos["x"] + vel["x"] * p_delta
    var new_y := pos["y"] + vel["y"] * p_delta
    p_ecb.set_component(row.entity, &"Position", {"x": new_x, "y": new_y})
)
```

### 索引遍历

```gdscript
for i in range(result.count()):
    var row := result.get_row(i)
    if row != null:
        var entity := row.entity
        var pos := row.get_component(&"Position")
        # ...
```

### 辅助方法

| 方法 | 返回值 | 说明 |
|---|---|---|
| `count()` | `int` | 结果行数 |
| `is_empty()` | `bool` | 是否空结果 |
| `entities()` | `PackedInt64Array` | 所有匹配实体的 ID 列表 |
| `get_row(index)` | `GF_EcsQueryRow` | 获取指定行，越界返回 `null` |

### QueryRow — 单行数据

| 方法 | 返回值 | 说明 |
|---|---|---|
| `row.entity` | `int` | 实体 ID |
| `row.get_component(type)` | `Variant` | 获取该实体的指定组件数据 |

## ECS 调度器分组

`GF_EcsScheduler` 预定义了三个标准分组，按顺序执行：

```text
Initialization  →  Simulation  →  Presentation
（每帧先执行）     （核心逻辑）     （每帧最后执行）
```

| 分组 | 常量 | 用途 |
|---|---|---|
| Initialization | `GF_EcsScheduler.GROUP_INITIALIZATION` | 生成实体、初始化组件、处理输入映射 |
| Simulation | `GF_EcsScheduler.GROUP_SIMULATION` | 游戏逻辑：移动、AI、物理、经济 |
| Presentation | `GF_EcsScheduler.GROUP_PRESENTATION` | 同步表现：更新 Sprite、播放动画、更新 UI |

分组之间使用独立的 `GF_EcsCommandBuffer`，组末统一 apply。这意味着：
- Initialization 的修改对 Simulation 可见
- Simulation 的修改对 Presentation 可见
- 但 Simulation 内的系统之间的修改，在当前组执行期间**不可见**（因为 ECB 在组末才 apply）

### 注册系统

```gdscript
var scheduler: GF_EcsScheduler = context.ecs_scheduler

scheduler.register_system(
    MovementSystem.new(),
    GF_EcsScheduler.GROUP_SIMULATION,
    MovementSystem.descriptor()
)

scheduler.register_system(
    RenderSystem.new(),
    GF_EcsScheduler.GROUP_PRESENTATION,
    RenderSystem.descriptor()
)
```

### 添加自定义分组

```gdscript
# 在默认三个分组之外添加自定义分组
scheduler.add_group(&"AI")
scheduler.register_system(
    AISystem.new(),
    &"AI",
    AISystem.descriptor()
)
```

自定义分组会追加在默认分组之后按添加顺序执行。

## 完整示例：MovementSystem

```gdscript
class_name MovementSystem
extends GF_EcsSystem


var _plan: GF_EcsQueryPlan = null


func on_init(p_world: GF_EcsWorld) -> void:
    # 预编译查询计划（只需构建一次）
    _plan = GF_EcsQuery.new() \
        .with_component(&"Position") \
        .with_component(&"Velocity") \
        .with_component(&"Movement") \
        .without_component(&"Stunned") \
        .build()


func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    var result := _plan.execute(p_world)

    if result.is_empty():
        return

    result.for_each(func(row: GF_EcsQueryRow) -> void:
        var pos: Dictionary = row.get_component(&"Position")
        var vel: Dictionary = row.get_component(&"Velocity")
        var mov: Dictionary = row.get_component(&"Movement")

        var speed: float = mov.get("speed", 100.0)

        # 计算新位置
        var new_x := pos["x"] + vel["x"] * speed * p_delta
        var new_y := pos["y"] + vel["y"] * speed * p_delta

        # 边界限制
        var world_size := mov.get("world_size", {"x": 1920.0, "y": 1080.0})
        new_x = clampf(new_x, 0.0, world_size["x"])
        new_y = clampf(new_y, 0.0, world_size["y"])

        # 通过 ECB 写入（不直接修改 World）
        p_ecb.set_component(row.entity, &"Position", {"x": new_x, "y": new_y})
    )


static func descriptor() -> GF_EcsSystemDescriptor:
    var desc := GF_EcsSystemDescriptor.new()
    desc.system_name = "MovementSystem"
    desc.group_name = GF_EcsScheduler.GROUP_SIMULATION
    desc.priority = 100  # 在 AI 之前、在物理之后
    desc.after_systems = ["PhysicsSystem"]
    desc.before_systems = ["AISystem"]
    return desc
```

---

**下一步**: [命令缓冲](command-buffer.md) — 深入理解 ECB 的必要性和工作机制，或 [ECS 世界](ecs-world.md) 回顾基础概念。
