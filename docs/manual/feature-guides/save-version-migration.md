# 存档版本迁移

## 场景描述

游戏更新后，存档格式可能发生变化——新增字段、重命名字段、改变数据结构。如果不做处理，旧存档将无法加载。框架通过 `GF_SaveVersionMigrator` 机制，将旧版本存档数据逐级迁移到最新格式。

本章覆盖：为什么需要版本迁移、编写 Migrator 子类、注册迁移链、v1 到 v3 的完整示例。

---

## 最小示例

```gdscript
# 1. 递增版本号（在 GF_SaveVersion 的子类或直接引用处）
# GF_SaveVersion.CURRENT = 2  # 从 1 改为 2

# 2. 创建迁移器
class_name V1ToV2Migrator
extends GF_SaveVersionMigrator


func _init() -> void:
    from_version = 1
    to_version = 2


func migrate(p_data: Dictionary) -> GF_OperationResult:
    # v1 → v2：将 "hp" 重命名为 "health"
    if p_data.has("player_stats"):
        var ps: Dictionary = p_data["player_stats"]
        if ps.has("hp"):
            ps["health"] = ps["hp"]
            ps.erase("hp")
    return GF_OperationResult.ok(p_data)


# 3. 注册迁移器
save_service.register_migrator(V1ToV2Migrator.new())
```

`GF_SaveService.load_slot()` 会自动检测存档版本并执行迁移链。开发者不需要手动调用 `migrate()`。

---

## 逐步解释

### 第一步：理解版本迁移机制

框架的存档版本管理由三个组件协同工作：

| 组件 | 职责 |
|------|------|
| `GF_SaveVersion.CURRENT` | 当前存档结构版本号（常量） |
| `GF_SaveVersionMigrator` | 执行单步迁移（from_version → to_version） |
| `GF_SaveService._migrators` | 以 `from_version` 为 key 的迁移器字典 |

加载流程中的版本处理：

```gdscript
# 框架内部逻辑（GF_SaveService.load_slot 简化版）
func load_slot(slot):
    data = provider.load_full(slot)
    data_version = meta["save_version"]

    if data_version == CURRENT:
        return data  # 版本一致，直接返回

    if data_version > CURRENT:
        return fail("存档版本高于当前版本，请升级游戏")

    # 逐级迁移
    v = data_version
    while v < CURRENT:
        migrator = _migrators[v]
        data = migrator.migrate(data)
        v = migrator.to_version

    return data
```

关键行为：
- 版本相等 → 直接返回，不执行迁移
- 存档版本 > 当前版本 → 返回 `ERR_MIGRATION` 错误（玩家需要升级游戏）
- 存档版本 < 当前版本 → 逐个调用迁移器，链式升级
- 缺少迁移器 → 返回 `ERR_MIGRATION` 错误（开发遗漏）

### 第二步：编写 Migrator 子类

```gdscript
class_name V2ToV3Migrator
extends GF_SaveVersionMigrator


func _init() -> void:
    from_version = 2   # 此迁移器处理的源版本
    to_version = 3     # 迁移后的目标版本


func migrate(p_data: Dictionary) -> GF_OperationResult:
    # p_data 是完整的存档数据字典（包含所有 save_key 的模块数据）

    # 例：v2 中 inventory 是物品 ID 列表，v3 改为含数量的字典数组
    if p_data.has("world.inventory"):
        var old_items: Array = p_data["world.inventory"]["items"]
        if typeof(old_items[0]) == TYPE_STRING:
            # v2 格式：["sword", "potion"]
            # v3 格式：[{"id": "sword", "count": 1}, {"id": "potion", "count": 1}]
            var new_items: Array[Dictionary] = []
            for item_id in old_items:
                new_items.append({"id": str(item_id), "count": 1})
            p_data["world.inventory"]["items"] = new_items

    return GF_OperationResult.ok(p_data)
    # 迁移失败时返回 fail，框架将拒绝加载该存档
```

迁移方法的关键规则：
- 入参 `p_data` 是整个存档数据字典（`{save_key: module_data_dict, ...}`）
- 直接修改 `p_data` 是安全的（此方法运行在加载流程中，不会影响源文件）
- 返回 `GF_OperationResult.ok(modified_data)`
- 迁移失败时返回 `GF_OperationResult.fail(...)`，框架将阻止加载并记录错误

### 第三步：注册迁移链

```gdscript
# 在引导阶段注册所有迁移器
save_service.register_migrator(V1ToV2Migrator.new())
save_service.register_migrator(V2ToV3Migrator.new())
save_service.register_migrator(V3ToV4Migrator.new())
```

按 `from_version` 为 key 注册，框架在加载时自动查找对应版本的迁移器。

### 第四步：递增 CURRENT 版本

```gdscript
# 在 GF_SaveVersion 中递增（或在 Game 层覆盖）
# 例如：从常量 1 改为 3
const CURRENT: int = 3
```

每次修改存档数据结构时，必须同步做三件事：
1. 递增 `GF_SaveVersion.CURRENT`
2. 创建新版本的 Migrator 子类
3. 在引导阶段注册新 Migrator

---

## 完整示例：v1 → v2 → v3 三段迁移

假设一个游戏的存档数据经历了三次格式变更：

```gdscript
# ============================================================
# v1 存档格式（初始发布）
# ============================================================
# {
#   "player": {"hp": 100, "mp": 50, "x": 10.0, "y": 20.0},
#   "inventory": {"slots": ["sword", "shield", "potion"]},
#   "quests": {"completed": [1, 3, 5]}
# }

# ============================================================
# v2 变更：重命名字段，拆分 player 数据
# ============================================================

class_name V1ToV2Migrator
extends GF_SaveVersionMigrator


func _init() -> void:
    from_version = 1
    to_version = 2


func migrate(p_data: Dictionary) -> GF_OperationResult:
    # 1. player: hp/mp → health/mana；位置独立为 position 模块
    if p_data.has("player"):
        var player: Dictionary = p_data["player"]
        if player.has("hp"):
            player["health"] = player["hp"]
            player.erase("hp")
        if player.has("mp"):
            player["mana"] = player["mp"]
            player.erase("mp")

        # 拆分位置到独立模块
        var pos_data := {
            "x": player.get("x", 0.0),
            "y": player.get("y", 0.0),
        }
        player.erase("x")
        player.erase("y")
        p_data["world.player_position"] = pos_data

    return GF_OperationResult.ok(p_data)


# ============================================================
# v3 变更：物品栏从 ID 列表改为含数量的结构体数组
# ============================================================

class_name V2ToV3Migrator
extends GF_SaveVersionMigrator


func _init() -> void:
    from_version = 2
    to_version = 3


func migrate(p_data: Dictionary) -> GF_OperationResult:
    if p_data.has("inventory"):
        var inv: Dictionary = p_data["inventory"]
        var old_slots: Array = inv.get("slots", [])
        var new_slots: Array[Dictionary] = []

        for item in old_slots:
            if item is String:
                # v2 格式：纯字符串
                new_slots.append({"id": item, "count": 1, "durability": 100})
            elif item is Dictionary:
                # 已迁移过（幂等）
                new_slots.append(item)

        inv["slots"] = new_slots

    # 2. quests 增加时间戳
    if p_data.has("quests"):
        var quests: Dictionary = p_data["quests"]
        var old_completed: Array = quests.get("completed", [])
        var new_completed: Array[Dictionary] = []
        for quest_id in old_completed:
            if quest_id is int:
                new_completed.append({
                    "id": quest_id,
                    "completed_at": "",  # 旧存档没有时间戳，留空
                })
            elif quest_id is Dictionary:
                new_completed.append(quest_id)
        quests["completed"] = new_completed

    return GF_OperationResult.ok(p_data)


# ============================================================
# 引导阶段注册
# ============================================================

func _register_migrators(save_service: GF_SaveService) -> void:
    save_service.register_migrator(V1ToV2Migrator.new())
    save_service.register_migrator(V2ToV3Migrator.new())
    _log.info("Save", "存档迁移器注册完成，CURRENT = v%d" % GF_SaveVersion.CURRENT)
```

---

## 常见变体

### 变体 1：幂等迁移（安全重复执行）

```gdscript
func migrate(p_data: Dictionary) -> GF_OperationResult:
    # 检查数据是否已经是新格式，避免重复迁移
    if p_data.has("player_stats"):
        var ps: Dictionary = p_data["player_stats"]
        if ps.has("health") and not ps.has("hp"):
            return GF_OperationResult.ok(p_data)  # 已迁移
        if ps.has("hp"):
            ps["health"] = ps["hp"]
            ps.erase("hp")
    return GF_OperationResult.ok(p_data)
```

### 变体 2：添加默认值

```gdscript
func migrate(p_data: Dictionary) -> GF_OperationResult:
    # v2 → v3：新增 "difficulty" 字段，旧存档默认 "normal"
    if p_data.has("player"):
        var player: Dictionary = p_data["player"]
        if not player.has("difficulty"):
            player["difficulty"] = "normal"
    return GF_OperationResult.ok(p_data)
```

### 变体 3：删除废弃字段

```gdscript
func migrate(p_data: Dictionary) -> GF_OperationResult:
    # v3 → v4：移除旧的 deprecated_field
    if p_data.has("settings"):
        var settings: Dictionary = p_data["settings"]
        settings.erase("deprecated_volume")
        settings.erase("old_rendering_mode")
    return GF_OperationResult.ok(p_data)
```

### 变体 4：条件迁移

```gdscript
func migrate(p_data: Dictionary) -> GF_OperationResult:
    # 只在特定条件下执行迁移
    if not p_data.has("world.map"):
        return GF_OperationResult.ok(p_data)  # 旧存档没有地图数据，无需迁移

    var map: Dictionary = p_data["world.map"]
    if map.get("version", 1) >= 3:
        return GF_OperationResult.ok(p_data)  # 地图数据本身已经是最新

    # 执行地图数据迁移...
    return GF_OperationResult.ok(p_data)
```

---

## 错误码

| 场景 | 错误码 | 说明 |
|------|--------|------|
| 存档版本高于当前版本 | `ERR_MIGRATION` | `"存档版本(vX)高于当前版本(vY)，请升级游戏"` |
| 缺少迁移器 | `ERR_MIGRATION` | `"缺少迁移器: vX → vX+1"` |
| `migrate()` 返回 fail | `ERR_MIGRATION` | 传递 migrator 的 fail result |

---

## See Also

- [实现游戏存档](./save-game-progress.md) -- 存档系统基础
- [场景切换](./scene-switching.md) -- 世界切换与存档
