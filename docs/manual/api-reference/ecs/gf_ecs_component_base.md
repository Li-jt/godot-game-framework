# GF_EcsComponentBase

> 适用版本: 0.3.0 | 继承: GF_EcsComponentBase -> RefCounted

## 概述

组件序列化基类。所有 Game 层组件继承此类，统一 `serialize` / `deserialize` 契约，为 Save/Snapshot 和 `GF_EcsComponentFactory` 自动发现提供结构化入口。

Game 层组件必须覆写 `get_component_type()`、`serialize()` 和 `deserialize()` 才能被工厂自动注册。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `schema_version` | `int` | `1` | 组件 schema 版本号，数据格式变更时递增 |

## 公共方法

### get_component_type() -> StringName

返回组件类型名（如 `&"Health"`）。子类应覆写此方法以支持工厂自动注册。默认返回空 `StringName`。

### serialize() -> Dictionary

将组件数据序列化为 Dictionary。子类必须覆写。默认实现报错。

```gdscript
# 子类覆写示例
func serialize() -> Dictionary:
    return {
        "current": current,
        "max": max_health,
    }
```

### deserialize(p_data: Dictionary) -> void

从 Dictionary 反序列化填充组件。子类必须覆写。默认实现报错。

```gdscript
# 子类覆写示例
func deserialize(p_data: Dictionary) -> void:
    current = p_data.get("current", 0)
    max_health = p_data.get("max", 100)
```

### from_dict(p_data: Dictionary) -> GF_EcsComponentBase (静态)

从 Dictionary 创建组件实例。默认实现：`new()` + `deserialize()`。子类可覆写为自定义构造逻辑。

## 完整子类示例

```gdscript
class_name HealthComponent
extends GF_EcsComponentBase

var current: int = 100
var max_health: int = 100

func get_component_type() -> StringName:
    return &"Health"

func serialize() -> Dictionary:
    return {
        "current": current,
        "max": max_health,
    }

func deserialize(p_data: Dictionary) -> void:
    current = p_data.get("current", 0)
    max_health = p_data.get("max", 100)
```

## See Also

- [GF_EcsComponentFactory](../save/gf_ecs_save_adapter.md) -- 组件工厂（通过 GF_EcsSaveAdapter 管理）
- [GF_EcsWorldSnapshot](./gf_ecs_snapshot.md) -- 世界快照
