# GF_EcsCommandBuffer

> 适用版本: 0.3.0 | 继承: GF_EcsCommandBuffer -> GF_IEcsCommandBuffer -> RefCounted

## 概述

ECS 命令缓冲。收集本帧内的 ECS 写操作，`apply_to()` 前预校验，帧末统一应用到 `GF_EcsWorld`。系统 `on_tick()` 中只写 ECB，不直接修改 world storage，避免迭代冲突。

相关类型：`GF_EcsCommand` -- 命令记录，定义 5 种操作类型常量和临时实体 ID 机制。

## GF_EcsCommand 常量

| 常量 | 值 | 描述 |
|------|-----|------|
| `SPAWN` | 1 | 创建实体 |
| `DESPAWN` | 2 | 销毁实体 |
| `ADD_COMPONENT` | 3 | 添加组件 |
| `SET_COMPONENT` | 4 | 设置组件 |
| `REMOVE_COMPONENT` | 5 | 移除组件 |
| `TEMP_ENTITY_START` | -1000000 | 临时实体 ID 起始值 |

## Temp Entity ID 机制

ECB 中的 `spawn()` 不会立即在 World 中创建实体，而是分配一个临时负 ID。后续在同一 ECB 中对这个临时 ID 的 `add_component` / `set_component` 等操作，会在 `apply_to()` 时自动映射到 World 分配的真实 ID。

预校验阶段会检查：如果某命令引用了临时负 ID 但该 ID 尚未通过 `spawn()` 在当前 ECB 中创建，则返回 `ERR_PRECONDITION` 错误。

## 公共方法

### spawn() -> int

在 ECB 中预约创建实体。返回临时负 ID（如 -1000001、-1000002）。实际实体在 `apply_to()` 时创建。

```gdscript
var temp_id := ecb.spawn()
ecb.add_component(temp_id, &"Position", {"x": 0.0, "y": 0.0})
# apply_to 时 temp_id 会被映射为真实 entity ID
```

### add_component(p_entity: int, p_type: StringName, p_data: Variant) -> void

预约添加组件。`p_entity` 可以是真实 ID 或临时负 ID。

### set_component(p_entity: int, p_type: StringName, p_data: Variant) -> void

预约设置组件（覆盖已有值或新增）。

### remove_component(p_entity: int, p_type: StringName) -> void

预约移除组件。

### despawn(p_entity: int) -> void

预约销毁实体。

### apply_to(p_world: GF_EcsWorld) -> GF_OperationResult

预校验 + 应用全部命令到世界。预校验失败时（如临时实体引用异常）不执行任何操作，返回错误。成功时返回 `GF_OperationResult.ok(temp_to_real)`，其中 `temp_to_real` 是临时 ID 到真实 ID 的映射 Dictionary。

**应用顺序:**
1. 预校验所有命令
2. 按顺序执行：SPAWN（分配真实 ID）-> ADD_COMPONENT -> SET_COMPONENT -> REMOVE_COMPONENT -> DESPAWN
3. 清空命令列表和临时 ID 缓存

```gdscript
var result := ecb.apply_to(world)
if result.is_fail():
    push_error("ECB 应用失败: %s" % result.error.message)
else:
    var mapping: Dictionary = result.data
    print("临时 -> 真实映射: ", mapping)
```

### count() -> int

返回当前缓冲中的命令数量。

### clear() -> void

清空所有命令并重置临时 ID 计数器。

### debug_get_commands() -> Array

返回当前缓冲中所有命令的调试信息（只读，供外部调试工具使用）。

## 使用示例

```gdscript
# 在 ECS 系统 on_tick 中使用
func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    # 创建新实体
    var temp := p_ecb.spawn()
    p_ecb.add_component(temp, &"Position", {"x": 100.0, "y": 200.0})
    p_ecb.add_component(temp, &"Projectile", {"speed": 500.0})

    # 销毁实体
    for row in _dead_query.execute(p_world):
        p_ecb.despawn(row.entity)
```

## See Also

- [GF_EcsWorld](./gf_ecs_world.md) -- ECS 世界
- [GF_EcsSystem](./gf_ecs_system.md) -- ECS 系统基类
- [GF_EcsScheduler](./gf_ecs_scheduler.md) -- ECS 调度器（管理 ECB 池和 apply 调度）
