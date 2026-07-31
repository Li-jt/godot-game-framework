# ECS 世界：GF_EcsWorld

**类比**：把 `GF_EcsWorld` 想象成一个巨大的电子表格：
- 每一行是一个**实体**（Entity），用行号（整数 ID）标识
- 每一列是一种**组件类型**（Component Type），存储该类型的数据
- 每个格子是某个实体的**组件数据**（Component Data），如 `Position = {"x": 100, "y": 200}`
- World 不关心数据是什么意思——它只是存储和检索。**系统**（System）负责理解数据并执行逻辑。

## ECS 三要素

| 概念 | 是什么 | 类比 |
|---|---|---|
| **Entity** | 一个整数 ID（从 1 开始递增） | 电子表格的行号 |
| **Component** | 依附于实体的纯数据 | 电子表格某个格子里的值 |
| **System** | 读取组件数据、执行逻辑的代码 | 一个处理表格数据的函数 |

关键洞察：Entity 本身没有任何数据或行为。它只是一个 ID。实体的所有属性都由它拥有的组件定义。一个拥有 `Position` + `Velocity` 组件的实体就是"会移动的东西"，一个拥有 `Position` + `Sprite` 组件的实体就是"有位置的可视化东西"。

## 创建和销毁实体

### spawn() — 创建实体

```gdscript
var world := GF_EcsWorld.new()
var player := world.spawn()
var enemy := world.spawn()
# player 可能是 1，enemy 是 2
```

`spawn()` 返回新实体的整数 ID。每 spawn 一次，ID 递增 1，世界版本号也递增 1。

### despawn() — 销毁实体

```gdscript
world.despawn(player)
# 返回 true（实体存在并被销毁）
# 该实体的所有组件数据也被清除

world.despawn(999)  # 不存在的实体
# 返回 false（什么都没发生）
```

### has_entity() — 检查实体是否存在

```gdscript
if world.has_entity(player):
    # 实体仍然存活
    pass
```

## 组件操作

### add_component() — 添加组件

```gdscript
var result := world.add_component(player, &"Health", {"current": 100, "max": 100})
if result.is_ok():
    # 添加成功
    pass
```

**注意**：`add_component()` 会在组件已存在时返回 `ERR_CONFLICT`。如果你需要覆盖已有数据，使用 `set_component()`。

### set_component() — 设置组件（覆盖）

```gdscript
# 无论组件是否存在，都写入新数据
world.set_component(player, &"Health", {"current": 80, "max": 100})
```

### get_component() — 获取组件

```gdscript
var health: Dictionary = world.get_component(player, &"Health")
if health != null:
    print("当前血量: %d" % health["current"])
```

当实体不存在或未拥有该组件时，返回 `null`。

### remove_component() — 移除组件

```gdscript
world.remove_component(player, &"TemporaryBuff")
# 如果实体没有该组件，静默忽略
```

### has_component() — 检查是否拥有组件

```gdscript
if world.has_component(player, &"Health"):
    # 实体有血量组件
    pass
```

## 世界级操作

### get_version() — 获取世界版本号

每次 mutation（spawn / despawn / add_component / set_component / remove_component）都会递增版本号：

```gdscript
var v1 := world.get_version()
world.spawn()
var v2 := world.get_version()
# v2 == v1 + 1
```

版本号用于判断"世界是否有变化"，在快照、网络同步、调试等场景中很有用。

### all_entities() — 获取所有存活实体

```gdscript
var all_ids := world.all_entities()
for id in all_ids:
    if world.has_component(id, &"Health"):
        # 处理有血量组件实体
        pass
```

### entity_count() — 实体数量

```gdscript
print("当前共有 %d 个实体" % world.entity_count())
```

### reset() — 重置世界

清空所有实体和组件，重置 ID 分配器。常用于"开始新游戏"或测试清理：

```gdscript
world.reset()
# 所有实体和组件数据被清空，下一个 spawn() 返回 1
```

## 完整错误码

### spawn()

无错误返回——总是成功。

### despawn()

| 返回值 | 含义 |
|---|---|
| `true` | 实体存在，已销毁 |
| `false` | 实体不存在，无操作 |

### add_component()

| 错误码 | 含义 |
|---|---|
| `OK` (200) | 组件添加成功 |
| `ERR_NOT_FOUND` (404) | 实体不存在 |
| `ERR_CONFLICT` (409) | 实体已拥有该组件类型 |

### set_component()

| 错误码 | 含义 |
|---|---|
| `OK` (200) | 组件设置成功 |
| `ERR_NOT_FOUND` (404) | 实体不存在 |

## 代码示例：完整工作流

```gdscript
# 创建世界
var world := GF_EcsWorld.new()

# 创建实体
var player := world.spawn()
var enemy := world.spawn()

# 添加组件
world.add_component(player, &"Position", {"x": 100.0, "y": 200.0})
world.add_component(player, &"Health", {"current": 100, "max": 100})
world.add_component(enemy, &"Position", {"x": 500.0, "y": 200.0})
world.add_component(enemy, &"Health", {"current": 50, "max": 50})

# 查询和修改
var pos: Dictionary = world.get_component(player, &"Position")
pos["x"] += 10.0
world.set_component(player, &"Position", pos)

# 移除组件
world.remove_component(enemy, &"Health")

# 检查
print("玩家有血量: ", world.has_component(player, &"Health"))   # true
print("敌人有血量: ", world.has_component(enemy, &"Health"))    # false
print("总实体数: ", world.entity_count())                        # 2
print("世界版本: ", world.get_version())                         # 若干次 mutation 后的版本号

# 销毁一个实体
world.despawn(enemy)
print("总实体数: ", world.entity_count())                        # 1
```

---

**下一步**: [实体与组件](entity-component.md) — 深入了解组件的两种定义方式和序列化，或 [系统与查询](system-query.md) 学习如何编写处理数据的系统。
