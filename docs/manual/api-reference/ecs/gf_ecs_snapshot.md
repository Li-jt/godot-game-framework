# GF_EcsSnapshot

> 适用版本: 0.3.0 | 继承: 见各组件类

## 概述

ECS 世界快照系统，由三个组件构成：

- **GF_EcsWorldSnapshot**: 可序列化的世界状态快照（实体、组件数据、版本号、类型注册信息）
- **GF_EcsSnapshotBuilder**: 从 GF_EcsWorld 构建快照
- **GF_EcsSnapshotApplier**: 将快照恢复到 GF_EcsWorld（支持完全覆盖和增量更新）

主要用途：Save（存档序列化）、Rollback（回滚）、Network（状态同步）。

## GF_EcsWorldSnapshot

### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `version` | `int` | `0` | 世界版本号 |
| `timestamp` | `int` | `0` | 快照创建时间戳（Unix 时间） |
| `component_registry` | `Dictionary` | `{}` | 组件类型注册表快照：`{StringName -> {type_id, version}}` |
| `entities` | `Array` | `[]` | 实体数据列表：`[{entity, components: {StringName -> data_dict}}]` |

### 公共方法

#### to_dict() -> Dictionary

将快照序列化为可存储的 Dictionary。

#### from_dict(p_data: Dictionary) -> void

从 Dictionary 反序列化快照（深拷贝）。

#### entity_count() -> int

快照中的实体数量。

## GF_EcsSnapshotBuilder

### build(p_world: GF_EcsWorld) -> GF_EcsWorldSnapshot

从指定世界构建快照。遍历全部实体和组件，调用组件的 `serialize()` 方法序列化组件数据。对不支持 `serialize()` 的基础类型（Dictionary、Array）做降级复制。

```gdscript
var builder := GF_EcsSnapshotBuilder.new()
var snapshot := builder.build(world)
```

**序列化策略:**
- 对象有 `serialize()` 方法 -> 调用 `obj.serialize()`
- Dictionary -> 深度复制
- Array -> 深度复制
- 其他基础类型 -> 转为 `str()`

## GF_EcsSnapshotApplier

### apply(p_world: GF_EcsWorld, p_snapshot: GF_EcsWorldSnapshot, p_factory: Variant = null) -> GF_OperationResult

将快照应用到指定世界（覆盖式恢复）。先 `reset()` 当前世界，再按快照数据重建全部实体和组件。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_world` | `GF_EcsWorld` | 目标世界 |
| `p_snapshot` | `GF_EcsWorldSnapshot` | 快照数据 |
| `p_factory` | `Variant` | 可选组件工厂（`GF_EcsComponentFactory` 实例），为 null 时降级为直接使用原始数据 |

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_BAD_REQUEST` | world 或 snapshot 为 null |

**返回值:** 成功时 `data` 包含 `{"restored_entities": count}`。

```gdscript
var applier := GF_EcsSnapshotApplier.new()
var result := applier.apply(world, snapshot)
if result.is_ok():
    print("恢复了 %d 个实体" % result.data.restored_entities)
```

### apply_delta(p_world: GF_EcsWorld, p_snapshot: GF_EcsWorldSnapshot) -> GF_OperationResult

将快照作为增量应用到世界（仅更新/新增，不删除未在快照中的实体）。适合网络同步场景。

```gdscript
var result := applier.apply_delta(world, delta_snapshot)
```

## 完整使用示例

```gdscript
# 构建快照
var builder := GF_EcsSnapshotBuilder.new()
var snapshot := builder.build(world)

# 序列化为字典（用于存档或网络传输）
var data := snapshot.to_dict()
# 可以 JSON 序列化：JSON.stringify(data)

# 反序列化
var loaded_snapshot := GF_EcsWorldSnapshot.new()
loaded_snapshot.from_dict(data)

# 恢复到世界（覆盖式）
var applier := GF_EcsSnapshotApplier.new()
var result := applier.apply(world, loaded_snapshot)
```

## See Also

- [GF_EcsSaveAdapter](./gf_ecs_save_adapter.md) -- 存档适配器（使用快照进行存档）
- [GF_EcsWorld](./gf_ecs_world.md) -- ECS 世界
- [GF_EcsComponentBase](./gf_ecs_component_base.md) -- 组件序列化基类
