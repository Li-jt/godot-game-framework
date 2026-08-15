# GF_EcsWorld

> 适用版本: 0.3.0 | 继承: GF_EcsWorld -> GF_IEcsWorld -> RefCounted

## 概述

ECS 世界核心。管理实体生命周期、组件存储、ID 分配和世界版本号。所有 ECS 操作均通过此对象完成，不直接操作存储层。

内部通过 `GF_EcsComponentTypeRegistry` 管理组件类型注册，通过 `GF_EcsStorageIndex` 管理多类型存储。

## 属性

无公开属性。全局共享数据通过 `set_resource` / `get_resource` 存取，不暴露内部字段。

## 公共方法

### 资源操作

世界级单例资源。与 Component 不同，Resource 全局只有一份，不需要通过 Entity 访问。等价于 Bevy 的 `Resource<T>`。

#### set_resource(p_key: Variant, p_data: Variant) -> void

设置世界级单例资源。使用 class_name 引用作为键，类型安全且支持 IDE 补全。

```gdscript
world.set_resource(GF_ContentDefRegistry, content_def_registry)
world.set_resource(GF_InputService, input_service)
```

#### get_resource(p_key: Variant) -> Variant

获取世界级单例资源。返回 `null` 表示未注册。

```gdscript
var content_def := world.get_resource(GF_ContentDefRegistry) as GF_ContentDefRegistry
if content_def != null:
    var terrain := content_def.module(&"terrain")
```

#### has_resource(p_key: Variant) -> bool

是否已注册指定资源。

### 实体生命周期

#### spawn() -> int

创建新实体，返回自增的实体 ID。每次调用同时递增世界版本号。

```gdscript
var entity := world.spawn()
```

#### despawn(p_entity: int) -> bool

销毁实体，同时从所有组件存储中移除该实体的数据。实体不存在时返回 `false`，成功返回 `true`。递增世界版本号。

```gdscript
if world.despawn(entity):
    print("实体 %d 已销毁" % entity)
```

#### has_entity(p_entity: int) -> bool

检查实体是否存活。

#### entity_count() -> int

返回当前存活的实体数量。

#### max_entity_id() -> int

已分配的最大实体 ID（实体 ID 单调递增不复用）。供「发现新实体」的消费方做分帧增量扫描：记录游标 `cursor`，每帧扫描 `(cursor, max_entity_id()]` 区间的新实体，避免周期性全量查询的规模级尖峰。

**热路径指引**：高频遍历用 `GF_EcsQueryPlan.execute_entities()`（零分配）或本方法 + 游标；`GF_EcsQueryPlan.execute()` 会分配行对象与组件字典，留给冷路径。

```gdscript
# 增量发现新实体（每帧或按需扫描，替代周期性全量查询）
for id in range(cursor + 1, world.max_entity_id() + 1):
    if world.has_entity(id):
        _on_new_entity(id)
cursor = world.max_entity_id()
```

#### all_entities() -> PackedInt64Array

返回所有存活实体 ID 列表。

### 组件操作

#### add_component(p_entity: int, p_type: StringName, p_data: Variant) -> GF_OperationResult

为实体添加组件。实体必须存在，且不能已拥有同类型组件。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_entity` | `int` | 实体 ID |
| `p_type` | `StringName` | 组件类型名（如 `&"Position"`） |
| `p_data` | `Variant` | 组件数据（Dictionary 或 GF_EcsComponentBase 子类实例） |

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 实体不存在 |
| `ERR_CONFLICT` | 实体已拥有该类型组件 |

```gdscript
var result := world.add_component(entity, &"Position", {"x": 10.0, "y": 20.0})
if result.is_fail():
    push_error("添加组件失败: %s" % result.error.message)
```

#### set_component(p_entity: int, p_type: StringName, p_data: Variant) -> GF_OperationResult

设置实体的组件数据（覆盖已有值或新增）。与 `add_component` 的区别是不检查组件是否已存在。

```gdscript
world.set_component(entity, &"Position", {"x": 15.0, "y": 25.0})
```

#### get_component(p_entity: int, p_type: StringName) -> Variant

获取实体的组件数据。实体不存在或未拥有该组件时返回 `null`。

```gdscript
var pos = world.get_component(entity, &"Position")
if pos != null:
    print("位置: (%f, %f)" % [pos.x, pos.y])
```

#### remove_component(p_entity: int, p_type: StringName) -> void

移除实体的指定组件。实体不存在或未拥有该组件时静默忽略。递增世界版本号。

#### has_component(p_entity: int, p_type: StringName) -> bool

检查实体是否拥有指定组件。

### 世界级操作

#### get_version() -> int

获取当前世界版本号。每次 spawn / despawn / add_component / set_component / remove_component 都会递增此值。可用于脏标记检测和缓存失效。

#### change_log

世界级变更日志（[GF_EcsChangeLog](./gf_ecs_change_log.md)）。每次 mutation 自动追加，单帧生命周期——消费方在 tick 边界读取后调用 `change_log.clear()`。三种消费模式（增量索引维护、脏标记收集、存档 delta 累计）见变更日志文档。

```gdscript
# 每帧消费实体增删
var log := world.change_log
for entity in log.removed_entities:
    _on_entity_removed(entity)
log.clear()
```

#### reset() -> void

重置世界：清空所有实体、组件数据、资源字典，重置 ID 分配器和版本号，并清空变更日志。

## 接口规范 (GF_IEcsWorld)

`GF_IEcsWorld` 定义 ECS 世界的接口契约，便于替换存储实现与 mock 测试。所有公开方法均在此接口中声明：

- `spawn() -> int`
- `despawn(p_entity: int) -> bool`
- `has_entity(p_entity: int) -> bool`
- `entity_count() -> int`
- `add_component(p_entity: int, p_type: StringName, p_data: Variant) -> GF_OperationResult`
- `set_component(p_entity: int, p_type: StringName, p_data: Variant) -> GF_OperationResult`
- `get_component(p_entity: int, p_type: StringName) -> Variant`
- `remove_component(p_entity: int, p_type: StringName) -> void`
- `has_component(p_entity: int, p_type: StringName) -> bool`
- `get_version() -> int`
- `all_entities() -> PackedInt64Array`

## 使用示例

```gdscript
# 创建世界
var world := GF_EcsWorld.new()

# 创建实体并添加组件
var player := world.spawn()
world.add_component(player, &"Position", {"x": 0.0, "y": 0.0})
world.add_component(player, &"Health", {"current": 100, "max": 100})

# 查询
if world.has_component(player, &"Health"):
    var health = world.get_component(player, &"Health")
    print("血量: %d/%d" % [health.current, health.max])

# 销毁
world.despawn(player)
```

## See Also

- [GF_EcsQuery](./gf_ecs_query.md) -- 查询系统
- [GF_EcsChangeLog](./gf_ecs_change_log.md) -- 变更日志
- [GF_EcsCommandBuffer](./gf_ecs_command_buffer.md) -- 命令缓冲
- [GF_EcsComponentTypeRegistry](./gf_ecs_component_type_registry.md) -- 组件类型注册
- [GF_EcsStorage](./gf_ecs_storage.md) -- 组件存储实现
