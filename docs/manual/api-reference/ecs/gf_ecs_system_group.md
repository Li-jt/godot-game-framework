# GF_EcsSystemGroup

> 适用版本: 0.3.0 | 继承: GF_EcsSystemGroup -> GF_IEcsSystemGroup -> RefCounted

## 概述

ECS 系统分组。管理组内系统列表和执行顺序，按 descriptor.priority 升序排列（越小越先执行），按 descriptor.tick_interval 做节流（tick_interval > 0 时使用累加器控制执行频率）。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `group_name` | `String` | `""` | 分组名称 |

## 公共方法

### add_system(p_system: GF_EcsSystem, p_descriptor: GF_EcsSystemDescriptor = null) -> void

向组内添加系统。重复添加同一系统实例会被幂等忽略。`p_descriptor` 为 `null` 时使用默认空 descriptor。

### init_all(p_world: GF_EcsWorld) -> void

按优先级排序后，依次调用所有系统的 `on_init()`。设置 `_initialized` 标志。

### tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void

按优先级顺序执行所有系统的 `on_tick()`。对 `tick_interval > 0` 的系统使用累加器节流，到达间隔后才执行，并将累计时间作为 delta 传入。

```gdscript
# tick_interval = 0.5 的系统：每 0.5 秒执行一次，传入的 delta 为 0.5（非 0.016）
```

### shutdown_all() -> void

依次调用所有系统的 `on_shutdown()`。

### system_count() -> int

返回组内系统数量。

### is_initialized() -> bool

检查组是否已初始化。

### has_system(p_system: GF_EcsSystem) -> bool

检查系统是否在组内（按实例引用）。

### remove_system(p_system: GF_EcsSystem) -> void

按实例引用移除系统。

### remove_by_name(p_name: String) -> GF_OperationResult

按系统名称移除（匹配 descriptor.system_name）。未找到时返回 `ERR_NOT_FOUND`。

### remove_by_owner(p_owner: String) -> Array[String]

按 owner 移除所有系统。移除前会调用每个系统的 `on_shutdown()`。返回被移除的系统名称列表。Mod 卸载时使用。

## 接口规范 (GF_IEcsSystemGroup)

`GF_IEcsSystemGroup` 定义系统分组的接口契约：

- `add_system(p_system: GF_EcsSystem, p_descriptor: GF_EcsSystemDescriptor = null) -> void`
- `init_all(p_world: GF_EcsWorld) -> void`
- `tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void`
- `shutdown_all() -> void`
- `system_count() -> int`
- `is_initialized() -> bool`

## 使用示例

```gdscript
var group := GF_EcsSystemGroup.new("Simulation")

var desc1 := GF_EcsSystemDescriptor.new()
desc1.system_name = "Movement"
desc1.priority = 10

var desc2 := GF_EcsSystemDescriptor.new()
desc2.system_name = "Collision"
desc2.priority = 20
desc2.tick_interval = 0.1  # 每 0.1 秒执行一次

group.add_system(MovementSystem.new(), desc1)
group.add_system(CollisionSystem.new(), desc2)

group.init_all(world)   # 按 priority 排序后初始化
group.tick(world, ecb, 0.016)  # 每帧执行，Collision 可能被节流
group.shutdown_all()
```

## See Also

- [GF_EcsSystem](./gf_ecs_system.md) -- ECS 系统基类
- [GF_EcsScheduler](./gf_ecs_scheduler.md) -- ECS 调度器
