# 命令缓冲：GF_EcsCommandBuffer

**类比**：在办公室里，你不会每写一个字就跑去主管办公室汇报——你会在备忘录上写完整段内容，然后一次性提交。`GF_EcsCommandBuffer` 就是你的备忘录：收集所有修改意图，在合适的时机一次性应用到 World。

## 为什么不能直接在 System 中改 World

如果你在 `on_tick()` 中直接调用 `world.set_component()`，会遇到一系列问题：

### 问题 1：迭代期间的数据不一致

```gdscript
# ❌ 危险：在遍历结果的同时修改 World
result.for_each(func(row: GF_EcsQueryRow) -> void:
    world.set_component(row.entity, &"Position", new_pos)

    # 如果下一个系统也在查询 Position，它看到的是部分更新后的数据
    # 如果这个修改导致实体不再匹配某个正在运行的查询，结果是未定义的
)
```

### 问题 2：无法回滚

如果一部分操作成功了，另一部分失败了，你没法撤销已经写入的数据：

```gdscript
# ❌ 三个操作中有两个成功、一个失败，数据处于不一致状态
world.spawn()                    # 成功
world.add_component(id, ...)     # 失败！但 spawn 已生效
world.spawn()                    # 成功
```

### 问题 3：同一帧内多个系统看不到彼此的新实体

系统 A 创建了一个实体，系统 B 想引用它——但 B 比 A 先执行。

## ECB 解决方案

`GF_EcsCommandBuffer` 将修改收集为命令列表，帧末一次性提交：

```text
System A:  ECB.spawn() → ECB.add_component() → ECB.set_component()
System B:  ECB.set_component() → ECB.despawn()
                ↓
          ECB.apply_to(world)    ← 全部提交，World 瞬间更新
                ↓
          下一组开始，所有修改可见
```

## ECB 方法

### spawn() — 创建实体

```gdscript
var temp_id := p_ecb.spawn()
p_ecb.add_component(temp_id, &"Position", {"x": 0.0, "y": 0.0})
# temp_id 是一个负数，仅在当前 ECB 中有效
# apply 之后，负数 ID 会被替换为真实 ID
```

### add_component() — 添加组件

```gdscript
p_ecb.add_component(entity, &"Health", {"current": 100, "max": 100})
```

### set_component() — 设置/覆盖组件

```gdscript
p_ecb.set_component(entity, &"Position", {"x": new_x, "y": new_y})
```

### remove_component() — 移除组件

```gdscript
p_ecb.remove_component(entity, &"TemporaryBuff")
```

### despawn() — 销毁实体

```gdscript
p_ecb.despawn(entity)
```

### apply_to(world) — 提交到世界

```gdscript
var result := ecb.apply_to(world)
if result.is_fail():
    print("命令提交失败: ", result.error.message)
```

`apply_to()` 先执行预校验，校验失败则清空所有命令不执行。

### clear() — 丢弃所有命令

```gdscript
ecb.clear()
# 所有命令被丢弃，temp 计数器重置
```

## Temp Entity ID 机制

当你在 ECB 中 `spawn()` 时，创建的是一个**临时实体 ID**（负数，从 -1000000 开始递减）。同一个 ECB 中后续操作可以引用这个临时 ID：

```gdscript
# 在同一帧中创建实体并添加组件
var temp_id := p_ecb.spawn()                                # temp_id = -1000000
p_ecb.add_component(temp_id, &"Position", {"x": 0, "y": 0}) # 引用临时 ID
p_ecb.add_component(temp_id, &"Health", {"current": 100})   # 引用临时 ID

# apply 时，框架自动将临时 ID 替换为 World 分配的真实 ID
```

**约束**：不能在 `spawn()` 之前引用一个临时 ID——预校验会检测到并返回 `ERR_PRECONDITION`。

## ECB 分组模式

`GF_EcsScheduler` 为每个分组分配独立的 ECB：

```text
┌─ Initialization 组 ──────────────────────┐
│  System A: ECB1.write(...)               │
│  System B: ECB1.write(...)               │
│  组末: ECB1.apply_to(world) → 原子提交    │
└──────────────────────────────────────────┘
┌─ Simulation 组 ──────────────────────────┐
│  System C: ECB2.write(...)               │  ← 可以看到 Initialization 的修改
│  System D: ECB2.write(...)               │
│  组末: ECB2.apply_to(world) → 原子提交    │
└──────────────────────────────────────────┘
┌─ Presentation 组 ────────────────────────┐
│  System E: ECB3.write(...)               │  ← 可以看到 Simulation 的修改
│  组末: ECB3.apply_to(world) → 原子提交    │
└──────────────────────────────────────────┘
```

**同一分组内的系统共享一个 ECB**：系统 A 可以用 ECB `spawn()` 一个实体然后 `add_component()`，系统 B 可以立即 `set_component()` 更新同一个实体——因为 ECB 只是收集命令，还没有提交。

**不同分组之间通过 World 同步**：Simulation 组的系统可以查询到 Initialization 组已经 apply 的实体和组件。

## 完整错误码

### apply_to()

| 错误码 | 含义 |
|---|---|
| `OK` (200) | 所有命令成功提交，返回 `temp_to_real` 映射字典 |
| `ERR_PRECONDITION` (428) | 预校验失败：临时实体在 spawn 之前被引用 |

## 代码示例：完整的创建 + 修改 + 销毁流程

```gdscript
class_name SpawnSystem
extends GF_EcsSystem


func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    # 1. 创建实体并添加组件
    var enemy_id := p_ecb.spawn()
    p_ecb.add_component(enemy_id, &"Position", {"x": 500.0, "y": 300.0})
    p_ecb.add_component(enemy_id, &"Velocity", {"x": -50.0, "y": 0.0})
    p_ecb.add_component(enemy_id, &"Health", {"current": 50, "max": 50})
    p_ecb.add_component(enemy_id, &"Enemy", {"type": "skeleton"})

    # 2. 查询并修改已有实体
    var plan := GF_EcsQuery.new() \
        .with_component(&"Health") \
        .with_component(&"Position") \
        .build()

    var result := plan.execute(p_world)
    result.for_each(func(row: GF_EcsQueryRow) -> void:
        var health: Dictionary = row.get_component(&"Health")
        var pos: Dictionary = row.get_component(&"Position")

        # 边界外实体：标记死亡
        if pos["x"] < -100.0 or pos["x"] > 2000.0:
            p_ecb.remove_component(row.entity, &"Health")
            p_ecb.add_component(row.entity, &"Dead", {})

        # 血量归零：销毁
        if health["current"] <= 0:
            p_ecb.despawn(row.entity)
    )
```

**关键规则**：`on_tick()` 中永远通过 `p_ecb` 修改世界，永远不直接调用 `p_world.set_component()` 等方法。`p_world` 只用于读取（`get_component()`、Query 执行）。

---

**下一步**: [服务依赖注入](service-dependency.md) — 学习如何组装和管理服务依赖，或 [系统与查询](system-query.md) 回顾查询模式。
