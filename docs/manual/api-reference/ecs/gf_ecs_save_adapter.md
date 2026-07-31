# GF_EcsSaveAdapter

> 适用版本: 0.3.0 | 继承: GF_EcsSaveAdapter -> RefCounted

## 概述

ECS 存档适配器。将 `GF_EcsWorldSnapshot` 桥接到 Framework `GF_SaveService`，支持组件级序列化/反序列化与存档版本管理。

相关类型：
- **GF_EcsComponentFactory**: 组件工厂注册表，Game 层注册组件类的脚本引用，存档恢复时自动按类型重建组件实例。
- **GF_EcsSaveVersionMigrator**: 存档版本迁移链，按版本号顺序执行迁移步骤。

## GF_EcsSaveAdapter

### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `component_factory` | `Variant` | `null` | 组件工厂注册表（实际传入 `GF_EcsComponentFactory` 实例）。设置后 load 时自动通过工厂重建组件实例 |

### 构造方法

```gdscript
func _init(p_current_save_version: int = 1)
```

### save(p_world: GF_EcsWorld) -> Dictionary

从世界构建存档数据。返回包含 `save_version` 和 `snapshot` 的字典。

```gdscript
var save_data := adapter.save(world)
# {"save_version": 1, "snapshot": {...}}
```

### load(p_world: GF_EcsWorld, p_save_data: Dictionary) -> GF_OperationResult

从存档数据恢复到世界。如果存档版本低于当前版本，自动执行迁移链；如果设置了 `component_factory`，会通过工厂回调将序列化数据重建为组件实例。

```gdscript
var result := adapter.load(world, save_data)
if result.is_fail():
    push_error("存档加载失败: %s" % result.error.message)
```

### set_save_version(p_version: int) -> void

设置当前存档版本号。

### get_save_version() -> int

获取当前存档版本号。

### get_current_save_version() -> int

获取当前存档版本号（别名，同 `get_save_version()`）。

### register_migration(p_from: int, p_to: int, p_fn: Callable, p_owner: String = "") -> GF_OperationResult

向 ECS 存档迁移链注册一个迁移步骤。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_from` | `int` | 迁移前的存档版本号 |
| `p_to` | `int` | 迁移后的存档版本号 |
| `p_fn` | `Callable` | 迁移回调，签名 `func(p_data: Dictionary) -> Dictionary` |
| `p_owner` | `String` | 注册者标识（用于 Mod 卸载时清理） |

### unregister_migrations_by_owner(p_owner: String) -> int

注销指定 owner 的所有迁移步骤。Mod 卸载时使用。返回移除的迁移步骤数量。

## GF_EcsComponentFactory

### register(p_type_name: StringName, p_factory: Callable) -> void

手动注册组件工厂回调（灵活模式）。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_type_name` | `StringName` | 组件类型名（如 `&"Health"`） |
| `p_factory` | `Callable` | 工厂回调，签名 `func(p_data: Dictionary) -> Variant` |

### register_script(p_script: GDScript) -> bool

从 GDScript 脚本引用自动注册组件工厂（推荐方式）。脚本类必须继承 `GF_EcsComponentBase` 并覆写 `get_component_type()` 和 `deserialize()`。

**返回值:** 注册成功返回 `true`，脚本未继承 `GF_EcsComponentBase` 或未覆写 `get_component_type()` 时返回 `false`。

### discover_from(p_scripts: Array) -> int

批量注册：从脚本引用数组中自动发现并注册所有组件。调用 `register_script()` 对每个脚本。返回成功注册的数量。

### create(p_type_name: StringName, p_data: Dictionary) -> Variant

从序列化数据创建组件实例。有注册的工厂回调则调用它；否则返回原始数据（向后兼容）。

### has_factory(p_type_name: StringName) -> bool

检查是否注册了指定类型的工厂。

### registered_types() -> Array[StringName]

返回所有已注册的组件类型名。

### unregister(p_type_name: StringName) -> void

注销指定类型的工厂回调。

### clear() -> void

清空全部工厂注册。

## GF_EcsSaveVersionMigrator

### register_migration(p_from: int, p_to: int, p_fn: Callable, p_owner: String = "") -> void

注册一个迁移步骤。

### migrate(p_data: Dictionary, p_from_version: int, p_to_version: int) -> GF_OperationResult

从 `p_from_version` 迁移到 `p_to_version`。按版本号顺序执行所有匹配的迁移步骤。如果某个版本无迁移步骤，输出警告并停止。

**返回值:** 成功时 `data` 为迁移后的数据。

### unregister_by_owner(p_owner: String) -> int

注销指定 owner 的所有迁移步骤。返回移除的步骤数量。

## 完整使用示例

```gdscript
# 创建存档适配器
var adapter := GF_EcsSaveAdapter.new(2)  # 当前存档版本 2

# 注册组件工厂
var factory := GF_EcsComponentFactory.new()
factory.register_script(HealthComponent)     # 继承 GF_EcsComponentBase
factory.register_script(PositionComponent)
adapter.component_factory = factory

# 注册版本迁移
adapter.register_migration(1, 2, func(data: Dictionary) -> Dictionary:
    # 版本 1 -> 2 的迁移逻辑
    var snapshot = data.get("snapshot", {})
    for entity_data in snapshot.get("entities", []):
        for type_name in entity_data.get("components", {}):
            var comp = entity_data.components[type_name]
            # 迁移逻辑...
    return data
)

# 保存
var save_data := adapter.save(world)

# 加载
var result := adapter.load(world, save_data)
```

## See Also

- [GF_EcsSnapshot](./gf_ecs_snapshot.md) -- 世界快照系统
- [GF_EcsComponentBase](./gf_ecs_component_base.md) -- 组件序列化基类
- [GF_EcsWorld](./gf_ecs_world.md) -- ECS 世界
