# GF_EcsSystem

> 适用版本: 0.3.0 | 继承: GF_EcsSystem -> RefCounted

## 概述

ECS 系统基类。所有 ECS 系统必须继承此类。`on_tick` 中只写 `GF_EcsCommandBuffer`，不直接修改 world storage。

相关类型：`GF_EcsSystemDescriptor` -- 系统元数据，描述系统名称、分组、tick 频率、依赖关系、优先级和 owner。

## GF_EcsSystem 虚方法

### on_init(p_world: GF_EcsWorld) -> void

系统初始化回调，在调度器注册后、首次 tick 前调用。适合在此构建查询计划、注册事件监听等一次性操作。

```gdscript
func on_init(p_world: GF_EcsWorld) -> void:
    _move_plan = GF_EcsQuery.new() \
        .with_component(&"Position") \
        .with_component(&"Velocity") \
        .build()
```

### on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void

每帧逻辑回调。通过 `p_ecb` 写入变更，由调度器在组末统一 apply。禁止在此方法中直接调用 `p_world.add_component()` 等方法。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_world` | `GF_EcsWorld` | ECS 世界（只读查询） |
| `p_ecb` | `GF_EcsCommandBuffer` | 本组命令缓冲（写入） |
| `p_delta` | `float` | 帧间隔时间（秒） |

```gdscript
func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    for row in _move_plan.execute(p_world):
        var pos = row.get_component(&"Position")
        var vel = row.get_component(&"Velocity")
        var new_pos = {"x": pos.x + vel.x * p_delta, "y": pos.y + vel.y * p_delta}
        p_ecb.set_component(row.entity, &"Position", new_pos)
```

### on_shutdown() -> void

系统关闭回调，调度器停止时调用。适合释放资源、取消事件监听等。

## GF_EcsSystemDescriptor 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `system_name` | `String` | `""` | 系统显示名称（用于调试和性能统计） |
| `group_name` | `String` | `""` | 所属分组名称 |
| `tick_interval` | `float` | `0.0` | tick 间隔（秒），0 表示每帧执行 |
| `before_systems` | `Array[String]` | `[]` | 必须在哪些系统之前执行 |
| `after_systems` | `Array[String]` | `[]` | 必须在哪些系统之后执行 |
| `priority` | `int` | `0` | 优先级，越小越先执行 |
| `owner` | `String` | `""` | 系统注册者（如 `"game"` 或 `"mod:fishing"`），用于卸载时批量清理 |

## 完整系统示例

```gdscript
class_name MovementSystem
extends GF_EcsSystem

var _move_plan: GF_EcsQueryPlan

func on_init(p_world: GF_EcsWorld) -> void:
    _move_plan = GF_EcsQuery.new() \
        .with_component(&"Position") \
        .with_component(&"Velocity") \
        .build()

func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    for row in _move_plan.execute(p_world):
        var pos = row.get_component(&"Position")
        var vel = row.get_component(&"Velocity")
        p_ecb.set_component(row.entity, &"Position", {
            "x": pos.x + vel.x * p_delta,
            "y": pos.y + vel.y * p_delta,
        })

func on_shutdown() -> void:
    _move_plan = null
```

```gdscript
# 注册到调度器
var desc := GF_EcsSystemDescriptor.new()
desc.system_name = "MovementSystem"
desc.group_name = "Simulation"
desc.priority = 10

var movement := MovementSystem.new()
ecs_scheduler.register_system(movement, &"Simulation", desc)
```

## See Also

- [GF_EcsSystemGroup](./gf_ecs_system_group.md) -- 系统分组
- [GF_EcsScheduler](./gf_ecs_scheduler.md) -- ECS 调度器
- [GF_EcsCommandBuffer](./gf_ecs_command_buffer.md) -- 命令缓冲
- [GF_EcsQuery](./gf_ecs_query.md) -- 查询系统
