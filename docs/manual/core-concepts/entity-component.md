# 实体与组件

**类比**：组件就像贴在实体上的标签。一个实体可以贴多个标签——"有位置"、"有血量"、"可移动"。取下标签，实体就失去了那个属性。标签上写什么取决于你——框架只提供"贴标签"和"读标签"的机制。

## 组件是纯数据

框架的核心约束之一：**组件绝不持有 Node 引用**。组件是纯数据，存储在 ECS World 中，可以用 Dictionary 定义，也可以用 `GF_EcsComponentBase` 子类定义。

**为什么不能存 Node 引用？**
- Node 依赖场景树，有生命周期（`_ready`、`_exit_tree`），ECS 实体是纯 ID，二者生命周期不同步
- 存 Node 引用会破坏存档/快照——Node 无法序列化到文件
- 存 Node 引用会破坏测试——单元测试不需要场景树就能测组件
- 存 Node 引用会破坏 ECS 的"数据与表现分离"原则

**正确做法**：表现层（Sprite、动画、碰撞体）通过实体 ID 从 World 读取组件数据，而不是反向依赖。

## 两种组件定义方式

### 方式一：Dictionary 组件（轻量）

适合简单数据，不需要自定义逻辑：

```gdscript
# 定义
world.add_component(entity, &"Position", {"x": 100.0, "y": 200.0})
world.add_component(entity, &"Health", {"current": 100, "max": 100})
world.add_component(entity, &"Velocity", {"x": 1.5, "y": 0.0})

# 使用
var pos: Dictionary = world.get_component(entity, &"Position")
var new_x := pos["x"] + 10.0
world.set_component(entity, &"Position", {"x": new_x, "y": pos["y"]})
```

**优点**：零样板代码，快速迭代。
**缺点**：无类型安全，字典键容易拼错，无内置序列化/校验。

### 方式二：GF_EcsComponentBase 子类组件（结构化）

适合需要类型安全、序列化、工厂注册的组件：

```gdscript
# src/game/components/health_component.gd
class_name HealthComponent
extends GF_EcsComponentBase


var current: int = 100
var max: int = 100


func get_component_type() -> StringName:
    return &"Health"


func serialize() -> Dictionary:
    return {"current": current, "max": max}


func deserialize(p_data: Dictionary) -> void:
    current = p_data.get("current", 100)
    max = p_data.get("max", 100)


static func from_dict(p_data: Dictionary) -> HealthComponent:
    var instance := HealthComponent.new()
    instance.deserialize(p_data)
    return instance


## 造成伤害，返回是否死亡
func take_damage(amount: int) -> bool:
    current = maxi(0, current - amount)
    return current <= 0


## 治疗
func heal(amount: int) -> void:
    current = mini(max, current + amount)


## 是否存活
func is_alive() -> bool:
    return current > 0
```

使用 `GF_EcsComponentBase` 子类时，你仍然把它作为 Variant 存入 World：

```gdscript
var health := HealthComponent.new()
health.current = 100
health.max = 100
world.set_component(entity, &"Health", health)

# 获取后需要转型
var h: HealthComponent = world.get_component(entity, &"Health") as HealthComponent
if h != null:
    if h.take_damage(30):
        world.despawn(entity)  # 死亡销毁
```

## 组件类型注册

`GF_EcsComponentTypeRegistry` 管理所有组件类型的 StringName 到内部 type_id 的映射。你在调用 `add_component()` 或 `set_component()` 时，World 会自动注册组件类型。

你也可以显式预注册（推荐，用于 Mod 管理和冲突检测）：

```gdscript
var registry := world._get_registry()
var result := registry.pre_register(&"Health", 1, "game")
if result.is_ok():
    print("Health 类型已注册, type_id: %d" % result.data)
```

### Registry 的关键方法

| 方法 | 说明 |
|---|---|
| `register_type(type)` | 注册组件类型（幂等） |
| `pre_register(type, version, owner)` | 显式预注册，带版本号和所有者 |
| `type_id_of(type)` | 获取 type_id，未注册返回 0 |
| `type_name_of(id)` | 通过 type_id 获取类型名 |
| `is_registered(type)` | 检查是否已注册 |
| `all_types()` | 返回所有已注册的类型名 |
| `count()` | 已注册类型数量 |
| `unregister_by_owner(owner)` | 注销指定拥有者的所有类型（Mod 卸载用） |

## serialize / deserialize

`GF_EcsComponentBase` 子类必须覆写 `serialize()` 和 `deserialize()`，以支持存档和快照：

```gdscript
class_name InventoryComponent
extends GF_EcsComponentBase


var items: Array[Dictionary] = []
var max_slots: int = 20


func get_component_type() -> StringName:
    return &"Inventory"


func serialize() -> Dictionary:
    return {
        "items": items.duplicate(true),
        "max_slots": max_slots
    }


func deserialize(p_data: Dictionary) -> void:
    items = p_data.get("items", [])
    items = items.duplicate(true)
    max_slots = p_data.get("max_slots", 20)
```

**序列化规则**：
- 返回的 Dictionary 只能包含可 JSON 序列化的基本类型（`String`、`int`、`float`、`bool`、`Array`、`Dictionary`）
- 不能包含 Object 引用、Node 引用、Resource 引用
- `deserialize()` 应该做深拷贝（`duplicate(true)`），避免意外共享引用

## 选择哪种方式

| 场景 | 推荐 |
|---|---|
| 数据量少（< 5 个字段）、逻辑简单 | Dictionary |
| 数据量大、有业务方法 | `GF_EcsComponentBase` 子类 |
| 需要存档/快照 | `GF_EcsComponentBase` 子类（有 `serialize`/`deserialize`） |
| 需要工厂自动发现 | `GF_EcsComponentBase` 子类 + `GF_EcsComponentFactory` |
| 快速原型 | Dictionary |

两种方式可以混合使用——同一个实体可以同时有 Dictionary 组件和 `GF_EcsComponentBase` 子类组件。

---

**下一步**: [系统与查询](system-query.md) — 学习如何编写读取组件数据、执行游戏逻辑的系统，或 [ECS 世界](ecs-world.md) 回顾 World 的 API。
