# GF_ISaveable

> 适用版本: 0.3.0 | 继承: GF_ISaveable → RefCounted

## 概述

可存档模块的抽象基类。任何需要持久化的模块继承此类，重写 `save_key()` / `on_save()` / `on_load()` 三个方法。GF_SaveService 通过鸭子类型识别 saveable（`has_method` 检查），因此 **Node 子类也可以实现这三个方法而无需继承 GF_ISaveable**。

注意：GF_ISaveable **不再自动注册**。需通过 `GF_SaveService.collect_from_node()`、`collect_from()` 或 `register_saveable()` 显式注册。这确保了 Mod 的 Saveable 可以在正确的启动时机被收集。

适用场景：地图数据、背包数据、任务状态、设置等需要持久化的数据模块。不应在无需持久化的纯计算模块上使用。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|

此类无公开属性。子类按需添加数据字段。

## 公共方法

### save_key() -> String

返回模块在存档中的唯一键名。基类默认 `push_error` 并返回空字符串，子类必须覆写。

**返回值:** 唯一键名字符串，如 `"map"`、`"inventory"`、`"tasks"`。

**示例:**

```gdscript
class_name MapData
extends GF_ISaveable

func save_key() -> String:
    return "map"
```

### on_save() -> Dictionary

序列化当前状态为字典。字段尽量用基础类型（int / float / String / Array / Dictionary），避免嵌套复杂对象。基类默认 `push_error` 并返回空字典，子类必须覆写。

**返回值:** 表示当前状态的字典。

**示例:**

```gdscript
func on_save() -> Dictionary:
    return {
        "width": _width,
        "height": _height,
        "cells": _cells.duplicate(true),
    }
```

### on_load(p_data: Dictionary) -> void

从字典恢复状态。`p_data` 是 `on_save()` 产出的同构数据。基类默认 `push_error`，子类必须覆写。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_data` | `Dictionary` | on_save() 产出的序列化数据 |

**示例:**

```gdscript
func on_load(p_data: Dictionary) -> void:
    _width = p_data.get("width", 10)
    _height = p_data.get("height", 10)
    _cells = p_data.get("cells", [])
```

### restore_priority() -> int

恢复优先级。数值越小越先恢复。默认返回 `100`。子类可覆写以控制存档恢复顺序。

典型优先级分层：
- **1-20:** 地形、内容定义等底层数据
- **21-50:** 建筑、实体等依赖地形的数据
- **51-100:** 通用模块数据（默认值 100）
- **101-200:** UI 状态等表现层数据
- **110+:** Mod 数据（避免与框架默认值冲突）

**返回值:** 优先级整数，默认 100。

**示例:**

```gdscript
# 地形需要最先恢复（entity 依赖地形）
class_name TerrainData
extends GF_ISaveable

func restore_priority() -> int:
    return 1
```

## 使用示例

```gdscript
class_name MapData
extends GF_ISaveable

var _width: int = 50
var _height: int = 50
var _cells: Array = []

func save_key() -> String:
    return "map"

func on_save() -> Dictionary:
    return {"width": _width, "height": _height, "cells": _cells.duplicate(true)}

func on_load(p_data: Dictionary) -> void:
    _width = p_data.get("width", 50)
    _height = p_data.get("height", 50)
    _cells = p_data.get("cells", [])

func restore_priority() -> int:
    return 1  # 地形最先恢复
```

## 鸭子类型兼容

GF_SaveService 使用 `has_method` 检查而非 `is` 类型检查来识别 saveable。这意味着 **Node 子类无需继承 GF_ISaveable**，只需实现三个方法即可：

```gdscript
# Node 子类直接实现 GF_ISaveable 接口，无需继承
class_name PlayerInventory
extends Node

func save_key() -> String:
    return "world.inventory.%s" % get_path()

func on_save() -> Dictionary:
    return {"items": _items, "gold": _gold}

func on_load(p_data: Dictionary) -> void:
    _items = p_data.get("items", [])
    _gold = p_data.get("gold", 0)

func restore_priority() -> int:
    return 50
```

这解决了 Node 和 RefCounted 并行继承链导致的 `is` 检查不适用问题。

## See Also

- [GF_SaveService](./gf_save_service.md) -- 存档服务（注册和调度 GF_ISaveable）
- [GF_EntityRegistry](#gf_entityregistry) -- 多态实体反序列化注册表

---

# GF_SaveVersionMigrator

> 适用版本: 0.3.0 | 继承: GF_SaveVersionMigrator → RefCounted

## 概述

存档版本迁移器的抽象基类。负责将旧版本存档数据迁移到新版本。每次 `GF_SaveVersion.CURRENT` 递增时，Game 层需创建对应的 Migrator 子类并注册到 GF_SaveService。

适用场景：存档格式变更时的向后兼容迁移。例如 v1 中字段名从 `"hp"` 改为 `"health"` 时，创建 `V1ToV2Migrator` 处理字段重命名。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `from_version` | `int` | `0` | 源版本号。此迁移器处理的存档版本。子类在 `_init()` 中设置 |
| `to_version` | `int` | `0` | 目标版本号。迁移后的存档版本。应等于 `from_version + 1` |

## 公共方法

### migrate(p_data: Dictionary) -> GF_OperationResult

执行迁移。`p_data` 为旧版本数据，返回迁移后的新版本数据。基类默认返回 `fail(ERR_INTERNAL, "未实现")`，子类必须覆写。迁移失败时 GF_SaveService 将拒绝加载该存档。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_data` | `Dictionary` | 旧版本存档数据 |

**返回值:** 返回 `Ok`，其 `data` 为迁移后的 Dictionary。失败返回对应错误。

## 使用示例

```gdscript
# v1 → v2: 字段重命名 hp → health
class_name V1ToV2Migrator
extends GF_SaveVersionMigrator

func _init() -> void:
    from_version = 1
    to_version = 2

func migrate(p_data: Dictionary) -> GF_OperationResult:
    # 处理 player 数据
    if p_data.has("player"):
        var player: Dictionary = p_data["player"]
        if player.has("hp"):
            player["health"] = player["hp"]
            player.erase("hp")
    return GF_OperationResult.ok(p_data)
```

```gdscript
# 注册迁移器到 GF_SaveService
save_service.register_migrator(V1ToV2Migrator.new())
save_service.register_migrator(V2ToV3Migrator.new())
```

## See Also

- [GF_SaveService.register_migrator()](./gf_save_service.md#register_migratorp_migrator-gf_saveversionmigrator---void) -- 注册迁移器
- [GF_SaveVersion](#gf_saveversion) -- 当前存档版本常量

---

# GF_SaveMeta

> 适用版本: 0.3.0 | 继承: GF_SaveMeta → RefCounted

## 概述

存档元数据。持久化时随存档数据一起写入，加载时先读取 meta 以判断版本兼容性。由 GF_SaveService 在调用 `save()` 时自动填充 `save_version`，由 GF_LocalSaveProvider 在写入时自动填充 `save_time`。

适用场景：作为 `save_all()` 和 `save()` 方法的元数据参数，以及在存档列表界面展示存档信息。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `slot_id` | `int` | `0` | 存档槽位编号 |
| `save_time` | `String` | `""` | 保存时间，格式 `"YYYY-MM-DD HH:MM:SS"`。由 GF_LocalSaveProvider.save() 自动填充 |
| `save_version` | `int` | `1` | 存档结构版本号。由 GF_SaveService.save() 自动填充为 `GF_SaveVersion.CURRENT` |
| `game_version` | `String` | `""` | 游戏版本号，由 Game 层设置 |
| `play_time_seconds` | `float` | `0.0` | 游戏时长（秒），由 Game 层设置 |
| `summary` | `String` | `""` | 存档摘要，如 `"第3年 春季"`，由 Game 层设置 |

## 使用示例

```gdscript
var meta := GF_SaveMeta.new()
meta.slot_id = 1
meta.game_version = "1.2.0"
meta.play_time_seconds = 7200.0
meta.summary = "第3年 春季 第15天"
# slot_id 可由 GF_SaveService 获取，通常对应 UI 槽位
# save_time 和 save_version 由框架自动填充，无需手动设置

var result := save_service.save_all(1, meta)
```

## JSON 持久化结构

```json
{
    "slot_id": 1,
    "save_time": "2026-07-31 14:30:00",
    "save_version": 1,
    "game_version": "1.2.0",
    "play_time_seconds": 7200.0,
    "summary": "第3年 春季"
}
```

## See Also

- [GF_SaveService.save_all()](./gf_save_service.md#save_allp_slot-int-p_meta-gf_savemeta---gf_operationresult) -- 保存所有 GF_ISaveable
- [GF_SaveService.save()](./gf_save_service.md#savep_slot-int-p_data-dictionary-p_meta-gf_savemeta---gf_operationresult) -- 保存指定数据
- [GF_SaveVersion](#gf_saveversion) -- 当前版本常量

---

# GF_EntityRegistry

> 适用版本: 0.3.0 | 继承: GF_EntityRegistry → RefCounted

## 概述

静态实体类型注册表。支持多态反序列化：存档中每条实体数据携带 `"type"` 字段标识其具体类型，读档时根据 type 查表调用对应的工厂函数创建正确的实体实例。

所有方法均为静态方法，无需实例化。

适用场景：存档中存在多种实体子类型（如 `"unit"`、`"building"`、`"item"`），需要在反序列化时根据 type 字段动态选择构造器。

## 属性

此类通过静态字典 `_factories` 存储注册信息，无公开实例属性。

## 静态方法

### register(p_type: String, p_factory: Callable) -> void

注册实体类型。`p_type` 对应存档数据中的 `"type"` 字段值。`p_factory` 接收 Dictionary 参数并返回对应类型的实例。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_type` | `String` | 类型标识符，对应存档中的 `"type"` 字段值 |
| `p_factory` | `Callable` | 工厂函数，签名为 `func(p_data: Dictionary) -> Variant` |

**示例:**

```gdscript
# 注册实体类型
GF_EntityRegistry.register("unit", func(d): return Unit.from_dict(d))
GF_EntityRegistry.register("building", func(d): return Building.from_dict(d))
GF_EntityRegistry.register("item", func(d): return Item.from_dict(d))
```

---

### create(p_type: String, p_data: Dictionary) -> Variant

从存档数据创建实体实例。根据 `p_type` 查找已注册的工厂函数并调用。类型未注册时打印 `push_warning` 并返回 `null`。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_type` | `String` | 实体类型标识符 |
| `p_data` | `Dictionary` | 实体的序列化数据字典 |

**返回值:** 工厂函数创建的实例。类型未注册时返回 `null`。

**示例:**

```gdscript
# 从存档数据批量创建实体
for entity_data in save_data["entities"]:
    var type: String = entity_data.get("type", "")
    var entity = GF_EntityRegistry.create(type, entity_data)
    if entity != null:
        world.add_entity(entity)
    else:
        push_warning("未知实体类型: %s，已跳过" % type)
```

---

### has(p_type: String) -> bool

检查指定类型是否已注册。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_type` | `String` | 实体类型标识符 |

**返回值:** 已注册返回 `true`，否则返回 `false`。

**示例:**

```gdscript
if not GF_EntityRegistry.has("unit"):
    push_error("unit 类型未注册，请检查初始化顺序")
    return
```

## 使用示例

```gdscript
# 在 Game 层启动时注册所有实体类型
func _register_entity_types() -> void:
    GF_EntityRegistry.register("unit", _create_unit)
    GF_EntityRegistry.register("building", _create_building)
    GF_EntityRegistry.register("resource_node", _create_resource)

func _create_unit(p_data: Dictionary) -> Unit:
    var unit := Unit.new()
    unit.id = p_data["id"]
    unit.position = Vector2(p_data["x"], p_data["y"])
    unit.hp = p_data.get("hp", 100)
    return unit

# 读档时使用
func on_load(p_data: Dictionary) -> void:
    _entities.clear()
    for entry in p_data.get("entities", []):
        var type: String = entry["type"]
        var entity = GF_EntityRegistry.create(type, entry)
        if entity != null:
            _entities.append(entity)
```

## See Also

- [GF_ISaveable](#gf_isaveable) -- 可存档模块基类
- [GF_SaveService](./gf_save_service.md) -- 存档服务

---

# GF_SaveVersion

> 适用版本: 0.3.0 | 继承: GF_SaveVersion → RefCounted

## 概述

存档版本常量定义类。提供当前存档结构版本号，供 GF_SaveService 在写入时标记 `save_version` 和在读取时判断是否需要迁移。

每次 SaveData 结构发生变化时递增此值，并创建对应的 GF_SaveVersionMigrator 处理迁移。

## 常量

| 常量 | 类型 | 值 | 描述 |
|------|------|-----|------|
| `CURRENT` | `int` | `1` | 当前存档结构版本。增量升级时递增（1 → 2 → 3 ...） |

## 使用示例

```gdscript
# GF_SaveService 内部自动使用，Game 层通常无需直接引用
# 仅当需要判断存档数据版本时使用
if data_version < GF_SaveVersion.CURRENT:
    print("存档需要迁移: v%d → v%d" % [data_version, GF_SaveVersion.CURRENT])
```

## See Also

- [GF_SaveVersionMigrator](#gf_saveversionmigrator) -- 存档版本迁移器
- [GF_SaveService.load_slot()](./gf_save_service.md#load_slotp_slot-int---gf_operationresult) -- 读取存档（自动版本检测和迁移）
