# GF_EcsComponentTypeRegistry

> 适用版本: 0.3.0 | 继承: GF_EcsComponentTypeRegistry -> RefCounted

## 概述

组件类型注册中心。管理 `StringName` -> `type_id` 的映射，并记录每种类型的版本号、注册者，为 Save/Debug/Inspector 提供结构化信息。支持 Mod 冲突检测和卸载。

## 公共方法

### register_type(p_type: StringName, p_version: int = 1) -> GF_OperationResult

注册组件类型。首次注册返回 `GF_OperationResult.created(type_id)`，重复注册同一类型返回已有 type_id 而不报错（`GF_OperationResult.ok(type_id)`）。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_type` | `StringName` | 组件类型名 |
| `p_version` | `int` | 组件版本号（默认 1） |

### pre_register(p_type: StringName, p_version: int = 1, p_owner: String = "") -> GF_OperationResult

显式预注册一个组件类型。带 owner 标识，支持冲突检测。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_type` | `StringName` | 组件类型名 |
| `p_version` | `int` | 版本号 |
| `p_owner` | `String` | 注册者标识（如 `"game"` 或 `"mod:fishing"`） |

**冲突规则:**
- 同 owner 重复注册 -> 幂等返回已有 ID
- 不同 owner 尝试注册 -> 输出错误日志但返回已有 ID（不阻塞）

### type_id_of(p_type: StringName) -> int

根据类型名获取 type_id。未注册时返回 0。O(1)。

### type_name_of(p_id: int) -> StringName

根据 type_id 获取类型名。未注册时返回空 StringName。O(1)。

### type_version(p_id: int) -> int

获取指定类型的版本号。

### type_owner(p_type_or_id: Variant) -> String

获取组件的注册者。参数可以是 `StringName`（类型名）或 `int`（type_id）。

### is_registered(p_type: StringName) -> bool

检查组件类型是否已注册。

### all_types() -> Array[StringName]

返回所有已注册类型名的数组。

### count() -> int

返回当前注册类型数量。

### unregister_by_owner(p_owner: String) -> Array[StringName]

注销指定 owner 的所有组件类型。Mod 卸载时使用。返回被移除的类型名数组。

## 使用示例

```gdscript
var registry := GF_EcsComponentTypeRegistry.new()

# 首次注册
var result := registry.register_type(&"Position")
print(result.data)  # type_id，如 1

# 重复注册（幂等）
var result2 := registry.register_type(&"Position")
print(result2.data)  # 还是 1

# 查询
var tid := registry.type_id_of(&"Position")    # 1
var name := registry.type_name_of(1)           # &"Position"
var ver := registry.type_version(1)             # 1
```

## See Also

- [GF_EcsWorld](./gf_ecs_world.md) -- ECS 世界
- [GF_EcsStorage](./gf_ecs_storage.md) -- 组件存储
