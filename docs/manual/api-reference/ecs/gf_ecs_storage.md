# GF_EcsStorage

> 适用版本: 0.3.0 | 继承: 见各实现类

## 概述

ECS 组件存储层。定义组件数据的 CRUD 和实体遍历契约，提供两种实现 -- SparseSet 和 Archetype，均通过 `GF_IEcsStorage` 接口可互换。

- **GF_EcsSparseSetStorage**: 基于 SparseSet，提供 O(1) 的增删改查，使用 swap-remove 保持 dense 数组紧凑。第一版实现，适合组件类型少、实体数量中等的场景。
- **GF_EcsArchetypeStorage**: 基于 Archetype 模式，将相同组件组合的实体分组存储在同一个 Archetype 中。组件数据按列对齐，支持批量遍历优化。适合大量实体、复杂组件组合的场景。

## 定位：代码组织工具

本文档中的 O(1)/O(n) 复杂度描述的是**算法复杂度**，不代表整体性能优势。

当前存储层是 GDScript 实现，组件数据是 `Dictionary` / `RefCounted`，存取经过 `Variant` 装箱和 GDScript 解释器。与 C++/Rust 的连续内存 + SoA 布局相比，常量因子差异显著（通常 10-100 倍）。

当前存储的价值在于**结构约束**：统一了组件数据的生命周期、实体遍历方式和存储后端切换。若需性能工具级别的数据布局（PackedArray 列式存储、GDExtension 热循环），存储层是 `GF_IEcsStorage` 接口可插拔的，可替换实现而不改 Game 层 API。详见 [README](../../../README.md#ecs-的定位代码组织工具不是性能工具)。

## 接口规范 (GF_IEcsStorage)

所有存储实现必须实现以下方法：

| 方法 | 返回值 | 描述 |
|------|--------|------|
| `insert(p_entity: int, p_data: Variant)` | `void` | 插入或更新实体的组件数据 |
| `erase(p_entity: int)` | `void` | 移除实体的组件数据。实体不存在时静默忽略 |
| `contains(p_entity: int)` | `bool` | 检查实体是否拥有此组件 |
| `get_data(p_entity: int)` | `Variant` | 获取实体的组件数据，不存在返回 `null` |
| `entities()` | `PackedInt64Array` | 返回所有拥有此组件的实体 ID |
| `count()` | `int` | 返回当前存储的实体数量 |
| `clear()` | `void` | 清空全部数据 |
| `get_backend_name()` | `String` | 返回存储后端名称（`"SparseSet"` 或 `"Archetype"`） |

## GF_EcsSparseSetStorage

### 内部结构

```text
_sparse: {entity_id -> dense_index}    # 稀疏映射
_dense:  [data_0, data_1, ...]         # 稠密数据数组
_entities: [entity_0, entity_1, ...]   # 稠密实体 ID 数组
```

### 性能特征

- `insert`: O(1) -- 存在时直接更新，不存在时追加
- `erase`: O(1) -- swap-remove，用末尾元素填充删除位置
- `contains`: O(1) -- 字典查找
- `get_data`: O(1)
- `entities()`: O(n)，n 为拥有该组件的实体数

## GF_EcsArchetypeStorage

### 核心概念

**Archetype** 是拥有完全相同组件组合的一组实体。每个 Archetype 内部组件数据按列（column）存储：

```text
Archetype [Position, Health]:
  entities: [e1, e2, e3]
  columns[0] (Position): [{x:0,y:0}, {x:10,y:20}, {x:5,y:5}]
  columns[1] (Health):  [{hp:100},   {hp:80},      {hp:50}]
```

当实体添加/移除组件导致组件组合变化时，实体会迁移到新的 Archetype（收集数据 -> 从旧 Archetype 移除 -> 追加到新 Archetype）。

### 共享管理器

所有 `GF_EcsArchetypeStorage` 实例共享一个静态的 `_ArchetypeManager`。在 GDScript 中 Godot 进程只有一个 ECS World，因此静态共享是安全的。

### 性能特征

- `insert`: O(1) 或 O(n)（需要迁移到新 archetype 时）
- `erase`: O(1) 或 O(n)
- `contains`: O(1)
- `get_data`: O(1)
- `entities()`: 遍历所有包含该类型的 archetype

## 使用示例

框架内部使用存储，Game 层通常不直接操作：

```gdscript
# 存储由 GF_EcsStorageIndex 管理，World 通过它访问
# 可通过 world._get_storage_index() 获取（内部使用）

# SparseSet
var storage := GF_EcsSparseSetStorage.new()
storage.insert(42, {"x": 10.0, "y": 20.0})
var data = storage.get_data(42)  # {"x": 10.0, "y": 20.0}

# Archetype
var arch_storage := GF_EcsArchetypeStorage.new(type_id)
arch_storage.insert(42, {"x": 10.0, "y": 20.0})
```

## See Also

- [GF_EcsWorld](./gf_ecs_world.md) -- ECS 世界
- [GF_EcsComponentTypeRegistry](./gf_ecs_component_type_registry.md) -- 组件类型注册
