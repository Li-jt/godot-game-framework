# GF_EcsScheduler

> 适用版本: 0.3.0 | 继承: GF_EcsScheduler -> GF_IEcsScheduler -> RefCounted

## 概述

ECS 调度器。驱动 Initialization / Simulation / Presentation 三组系统按序执行。每组使用独立 `GF_EcsCommandBuffer`（通过 `GF_ObjectPool` 池化），组末统一 apply 到世界。

初始化时自动创建三个默认分组，也可动态添加自定义分组。

## 常量

| 常量 | 值 | 描述 |
|------|-----|------|
| `GROUP_INITIALIZATION` | `&"Initialization"` | 初始化分组（仅首帧执行） |
| `GROUP_SIMULATION` | `&"Simulation"` | 模拟分组（每帧执行） |
| `GROUP_PRESENTATION` | `&"Presentation"` | 表现分组（每帧执行，在 Simulation 之后） |
| `FRAMEWORK_BIND_PRIORITY` | `-100` | 绑定到 Framework Scheduler 时的优先级（保证 ECS 先于世界表现同步） |

## 公共方法

### set_world(p_world: GF_EcsWorld) -> void

设置 ECS 世界引用。必须在 `start()` 之前调用。

### add_group(p_group_name: StringName) -> GF_EcsSystemGroup

添加一个系统分组。已存在的分组幂等返回。返回分组实例。

```gdscript
var custom_group := scheduler.add_group(&"Custom")
```

### register_system(p_system: GF_EcsSystem, p_group_name: StringName, p_descriptor: GF_EcsSystemDescriptor = null) -> GF_OperationResult

向指定分组注册系统。分组不存在时自动创建。`p_system` 为 null 时返回 `ERR_BAD_REQUEST`。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_system` | `GF_EcsSystem` | 系统实例 |
| `p_group_name` | `StringName` | 目标分组名称 |
| `p_descriptor` | `GF_EcsSystemDescriptor` | 系统元数据（可选） |

### unregister_system(p_system: GF_EcsSystem, p_call_shutdown: bool = true) -> GF_OperationResult

按系统实例引用注销。在所有分组中搜索并移除。未找到时返回 `ERR_NOT_FOUND`。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_call_shutdown` | `bool` | 是否在移除前调用 `on_shutdown()` |

### unregister_system_by_name(p_name: String, p_group_name: StringName = &"", p_call_shutdown: bool = true) -> GF_OperationResult

按系统名称注销。`p_group_name` 非空时仅在指定分组中搜索；为空时搜索所有分组。

### unregister_by_owner(p_owner: String) -> int

注销指定 owner 的所有系统。Mod 卸载时使用。返回被移除的系统数量。

### start() -> void

启动调度器：按 group_order 顺序初始化所有分组的所有系统。`_world` 为 null 时静默返回。

### tick(p_delta: float) -> void

执行一帧。按分组顺序依次执行：从 ECB 池获取缓冲 -> 组内 tick -> apply 到世界 -> 归还 ECB。`_active` 为 false 或 `_world` 为 null 时静默返回。

```gdscript
# 每帧调用
while game_running:
    var delta = get_process_delta_time()
    ecs_scheduler.tick(delta)
```

### stop() -> void

停止调度器，关闭所有系统（调用各组的 `shutdown_all()`）。

### is_active() -> bool

是否正在运行。

### get_group(p_group_name: StringName) -> GF_EcsSystemGroup

返回指定分组。不存在时返回 `null`。

### get_group_names() -> Array[StringName]

返回所有分组名称（按注册顺序）。

### bind_to_framework_scheduler(p_scheduler: GF_Scheduler) -> GF_OperationResult

将自身注册到 Framework 的 `GF_Scheduler`，确保 ECS tick 在正确的阶段（SIMULATION）执行。绑定后 `tick()` 由 Framework Scheduler 自动驱动，无需手动调用。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_scheduler` | `GF_Scheduler` | Framework 调度器实例 |

## 完整使用示例

```gdscript
# 创建并配置调度器
var world := GF_EcsWorld.new()
var scheduler := GF_EcsScheduler.new()
scheduler.set_world(world)

# 注册系统
var desc := GF_EcsSystemDescriptor.new()
desc.system_name = "MovementSystem"
desc.priority = 10
scheduler.register_system(MovementSystem.new(), &"Simulation", desc)

# 启动
scheduler.start()

# 主循环
func _process(delta: float) -> void:
    scheduler.tick(delta)

# 停止
scheduler.stop()
```

### 绑定到 Framework Scheduler（推荐）

```gdscript
# 在 Application 层装配时
var framework_scheduler: GF_Scheduler = ...
var ecs_scheduler := GF_EcsScheduler.new()
ecs_scheduler.set_world(world)
ecs_scheduler.bind_to_framework_scheduler(framework_scheduler)
# 之后 tick 自动驱动，无需手动调用
```

## See Also

- [GF_EcsSystemGroup](./gf_ecs_system_group.md) -- 系统分组
- [GF_EcsSystem](./gf_ecs_system.md) -- ECS 系统基类
- [GF_EcsWorld](./gf_ecs_world.md) -- ECS 世界
- [GF_EcsCommandBuffer](./gf_ecs_command_buffer.md) -- 命令缓冲
