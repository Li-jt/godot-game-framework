# GF_EcsQuery

> 适用版本: 0.3.0 | 继承: GF_EcsQuery -> GF_IEcsQuery -> RefCounted

## 概述

ECS 查询条件构建器。支持链式调用，通过 `with_component` / `without_component` / `optional_component` 组合过滤条件。调用 `build()` 返回预编译的 `GF_EcsQueryPlan`，同一 plan 可跨帧复用。

相关类型：
- `GF_EcsQueryPlan` -- 预编译查询计划，缓存查询条件
- `GF_EcsQueryResult` -- 查询结果集，包含匹配的行列表
- `GF_EcsQueryRow` -- 单行结果，包含实体 ID 和组件数据

## GF_EcsQuery 公共方法

### with_component(p_type: StringName) -> GF_EcsQuery

要求实体必须拥有指定组件。返回自身以支持链式调用。

```gdscript
var query := GF_EcsQuery.new()
query.with_component(&"Position").with_component(&"Health")
```

### without_component(p_type: StringName) -> GF_EcsQuery

要求实体不得拥有指定组件。返回自身以支持链式调用。

```gdscript
query.without_component(&"Dead")
```

### optional_component(p_type: StringName) -> GF_EcsQuery

实体可选拥有此组件（不影响匹配判定，但结果中会附带数据）。返回自身以支持链式调用。

```gdscript
query.optional_component(&"NameTag")
```

### build() -> GF_EcsQueryPlan

构建预编译查询计划。计划可缓存复用。

```gdscript
var plan := query.build()
```

### reset() -> void

重置所有查询条件。

## GF_EcsQueryPlan 公共方法

### execute(p_world: GF_EcsWorld) -> GF_EcsQueryResult

对指定世界执行查询，返回匹配的实体和组件数据。

**执行逻辑:**
1. 无 `with` 条件时，候选集为全部存活实体
2. 有 `with` 条件时，取第一个 `with` 组件的实体集作为候选，然后取交集
3. 排除 `without` 条件的实体
4. 收集每个匹配实体的 required 和 optional 组件数据

### execute_entities(p_world: GF_EcsWorld) -> PackedInt64Array

轻量查询：只返回匹配实体的 ID 列表，不构建行对象与组件字典（零分配）。供只需实体 ID 的高频消费方使用（系统缓存重建、增量索引维护等）——数千实体规模下，每帧调用 `execute()` 的行对象与组件字典分配是周期性 GC 尖峰的主要来源。

与 `execute()` 的过滤语义相同（with/without 参与判定）；`optional` 不影响匹配判定，对 entities-only 查询是 no-op，结果中也不附带 optional 数据。

**热路径指引**：每帧高频遍历用 `execute_entities()`（或 `GF_EcsWorld.max_entity_id()` + 游标），`execute()` 留给冷路径（事件响应、存档等低频场景）。

```gdscript
var _growth_entities: PackedInt64Array

func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    # 高频路径：零分配遍历，组件读取走 get_component 或本地缓存
    _growth_entities = _plan.execute_entities(p_world)
    for entity in _growth_entities:
        var data = p_world.get_component(entity, &"Growth")
        # ...
```

## GF_EcsQueryResult 公共方法

| 方法 | 返回值 | 描述 |
|------|--------|------|
| `for_each(p_fn: Callable)` | `void` | 对每行结果调用回调，签名 `func(row: GF_EcsQueryRow) -> void` |
| `entities()` | `PackedInt64Array` | 返回结果集中所有实体 ID |
| `count()` | `int` | 返回结果行数 |
| `get_row(p_index: int)` | `GF_EcsQueryRow` | 获取指定索引的行，越界返回 `null` |
| `is_empty()` | `bool` | 是否为空结果集 |

## GF_EcsQueryRow 公共方法

| 方法 | 返回值 | 描述 |
|------|--------|------|
| `get_component(p_type: StringName)` | `Variant` | 获取指定类型的组件数据，不存在返回 `null` |

**属性:** `entity: int` -- 实体 ID

## 使用示例

### 基本查询

```gdscript
# 一次性查询
var query := GF_EcsQuery.new()
var result := query.with_component(&"Position").with_component(&"Health").build().execute(world)

for row in result:
    var pos = row.get_component(&"Position")
    var hp = row.get_component(&"Health")
    print("实体 %d: 位置(%f, %f), 血量 %d" % [row.entity, pos.x, pos.y, hp.current])
```

### 预编译复用（推荐）

```gdscript
# 系统初始化时构建一次
var _move_plan: GF_EcsQueryPlan

func on_init(p_world: GF_EcsWorld) -> void:
    _move_plan = GF_EcsQuery.new() \
        .with_component(&"Position") \
        .with_component(&"Velocity") \
        .optional_component(&"SpeedMultiplier") \
        .build()

# 每帧执行
func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    var result := _move_plan.execute(p_world)
    result.for_each(func(row: GF_EcsQueryRow):
        var pos = row.get_component(&"Position")
        var vel = row.get_component(&"Velocity")
        var mult = row.get_component(&"SpeedMultiplier")
        var speed = mult.current if mult != null else 1.0
        var new_pos = {"x": pos.x + vel.x * p_delta * speed, "y": pos.y + vel.y * p_delta * speed}
        p_ecb.set_component(row.entity, &"Position", new_pos)
    )
```

## See Also

- [GF_EcsWorld](./gf_ecs_world.md) -- ECS 世界
- [GF_EcsSystem](./gf_ecs_system.md) -- ECS 系统基类
