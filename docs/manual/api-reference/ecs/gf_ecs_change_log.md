# GF_EcsChangeLog

> 适用版本: 0.3.0 | 继承: GF_EcsChangeLog -> RefCounted

## 概述

世界级变更日志（单帧生命周期）。记录一帧内的所有 ECS mutation：实体增删、组件增改删。
`GF_EcsWorld` 的每次 mutation（spawn / despawn / add_component / set_component / remove_component，
含 `GF_EcsCommandBuffer` apply 路径）自动追加日志条目。

框架**不定义消费时序**——消费方在 tick 边界读取后调用 `clear()`，消费语义由使用方决定。

## 属性

| 属性 | 类型 | 描述 |
|------|------|------|
| `added_entities` | `PackedInt64Array` | 本帧新增实体 ID |
| `removed_entities` | `PackedInt64Array` | 本帧销毁实体 ID |
| `component_changes` | `Array[Dictionary]` | 组件变更条目：`{entity, type_id, kind, component}` |
| `overflowed` | `bool` | 容量耗尽标记，消费方应降级为全量处理 |
| `max_entries` | `int` | 容量上限（默认 100000），超限丢弃后续记录 |

## 枚举

`ChangeKind`：`COMPONENT_ADDED` / `COMPONENT_CHANGED` / `COMPONENT_REMOVED`

## 公共方法

### has_changes() -> bool

本帧是否有任何变更。

### clear() -> void

清空全部记录（下一帧开始）。消费方在读取后调用。

## 三种消费模式

### 1. 增量索引维护

```gdscript
# 每帧 tick 末尾：消费实体增删，维护空间索引等外部结构
func on_post_tick(world: GF_EcsWorld) -> void:
    var log := world.change_log
    for entity in log.removed_entities:
        _spatial_index.remove(entity)
    for entity in log.added_entities:
        _spatial_index.insert(entity)
    log.clear()
```

### 2. 脏标记收集

```gdscript
# 渲染器：只处理本帧变更过的组件，替代周期性全量扫描
func collect_dirty(world: GF_EcsWorld) -> Dictionary:
    var dirty := {}
    for change in world.change_log.component_changes:
        dirty[change.entity] = true
    return dirty
```

### 3. 存档 delta 累计

```gdscript
# 变更日志累计到 delta 缓冲（配合 §3.1 GF_EcsDeltaBuilder）
for change in world.change_log.component_changes:
    if change.kind == GF_EcsChangeLog.ChangeKind.COMPONENT_REMOVED:
        delta.removes.append([change.entity, change.type_id])
    else:
        delta.upserts[change.entity] = change.component
```

## 注意

- `component` 字段是**单帧内有效的引用**（add/set 时有值，remove 时为 null）——不要存留越过下一次 `clear()`
- `overflowed` 为 true 时日志已不完整，消费方应全量重建，不可增量处理

## See Also

- [GF_EcsWorld](./gf_ecs_world.md) -- ECS 世界
- [GF_EcsCommandBuffer](./gf_ecs_command_buffer.md) -- 命令缓冲
