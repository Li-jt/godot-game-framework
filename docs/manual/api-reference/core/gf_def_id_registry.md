# GF_DefIdRegistry

> 适用版本: 0.3.0 | 继承: GF_DefIdRegistry -> RefCounted

## 概述

游戏内容定义的 ID 注册表。所有游戏 ID（Economy/Resource/Building/WorkJob 等）统一在此注册和查询。支持 xlsx 导出的 JSON 批量加载，以及 Mod 运行时动态追加。

内部维护双向映射（id <-> key）和分类（category）段管理，所有查询均为 O(1) 字典查找。

## 公共方法

### load_ids_json(p_path: String, p_owner: String = "game") -> GF_OperationResult

加载一个 `*_ids.json` 文件，批量注册所有 ID。JSON 格式：

```json
{
    "category": "resource",
    "id_start": 1001,
    "id_end": 1999,
    "entries": [
        {"id": 1001, "key": "wood", "display_name": "木材"},
        {"id": 1002, "key": "stone", "display_name": "石材"}
    ]
}
```

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | JSON 文件路径 |
| `p_owner` | `String` | 注册者标识（默认 `"game"`） |

**返回值:** `GF_OperationResult`。失败时错误码为 `ERR_NOT_FOUND`（文件不存在）或 `ERR_IO`（JSON 解析失败）。

### register_category(p_name: String, p_id_start: int, p_id_end: int = 0) -> void

注册一个 category 段（ID 范围）。重复注册同名 category 幂等忽略。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_name` | `String` | 分类名称（如 `"resource"`、`"building"`） |
| `p_id_start` | `int` | ID 起始值 |
| `p_id_end` | `int` | ID 结束值（可选） |

### register_id(p_category: String, p_key: StringName, p_preferred_id: int = 0, p_owner: String = "") -> int

注册一个 ID。同 category + 同 key 幂等返回已有 ID。如果 preferred_id 已被占用则自动分配。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_category` | `String` | 所属分类 |
| `p_key` | `StringName` | 键名 |
| `p_preferred_id` | `int` | 首选 ID（0 表示自动分配） |
| `p_owner` | `String` | 注册者标识 |

**返回值:** 实际分配的 ID。

### get_id(p_category: String, p_key: StringName) -> int

按分类和键名查询 ID。不存在时返回 0。O(1)。

### get_key(p_id: int) -> StringName

按 ID 查询键名。不存在时返回空 `StringName`。O(1)。

### get_display_name(p_id: int) -> String

获取 ID 对应的显示名称。不存在时返回空字符串。

### owner_of(p_id: int) -> String

获取 ID 的注册者标识。不存在时返回空字符串。

### to_id(p_category: String) -> Dictionary

获取指定分类的 key -> id 映射（返回副本，避免外部修改）。

### from_id(p_category: String) -> Dictionary

获取指定分类的 id -> key 映射（返回副本）。

### unregister_category(p_category: String) -> void

注销指定 category 的所有 ID。

### unregister_by_owner(p_owner: String) -> int

注销指定 owner 的所有 ID。Mod 卸载时使用。返回移除的 ID 数量。

### category_names() -> Array[String]

获取所有已注册 category 名称。

## 使用示例

```gdscript
# 加载 ID 定义 JSON
var def_id := GF_DefIdRegistry.new()
var result := def_id.load_ids_json("res://content/defs/resource_ids.json")
if result.is_fail():
    push_error("ID 加载失败: %s" % result.error.message)

# 注册单个 ID
var wood_id := def_id.register_id("resource", &"wood", 1001)
var stone_id := def_id.register_id("resource", &"stone", 1002)

# 查询
var id := def_id.get_id("resource", &"wood")      # 1001
var key := def_id.get_key(1001)                    # &"wood"
var name := def_id.get_display_name(1001)          # "木材"
```

## See Also

- [GF_ContentDefRegistry](./gf_content_def_registry.md) -- 内容定义注册表
- [GF_DefJsonLoader](./gf_def_json_loader.md) -- JSON 定义加载工具
