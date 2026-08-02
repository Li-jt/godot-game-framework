# 实现游戏存档

## 场景描述

游戏需要保存和恢复玩家进度——角色数据、世界状态、物品栏、任务进度等。框架的存档系统通过 `GF_ISaveable` 接口将游戏状态抽象为独立的"存档模块"，由 `GF_SaveService` 统一管理序列化、存储和恢复。

本章覆盖：ISaveable 接口、三种注册路径、保存/加载/列表/删除槽位、恢复优先级、世界切换时的存档管理。

---

## 最小示例

```gdscript
# 1. 定义存档模块
class_name PlayerStats
extends GF_ISaveable

var health: int = 100
var mana: int = 50


func save_key() -> String:
    return "player_stats"


func on_save() -> Dictionary:
    return {"health": health, "mana": mana}


func on_load(p_data: Dictionary) -> void:
    health = p_data["health"]
    mana = p_data["mana"]


# 2. 注册
save_service.register_saveable(player_stats)

# 3. 保存
var meta := GF_SaveMeta.new()
meta.slot_id = 0
meta.summary = "第3年 春季"
var result := save_service.save_all(0, meta)

# 4. 加载
var result := save_service.load_and_restore(0)
if result.is_fail():
    _log.error("Save", "加载失败: %s" % result.error.message)
```

---

## 逐步解释

### 第一步：实现 GF_ISaveable 接口

`GF_ISaveable` 是存档模块的抽象基类。每个需要持久化的模块继承它，重写四个方法：

```gdscript
class_name MapData
extends GF_ISaveable


## 模块在存档中的唯一键名。不能为空，不能与其他模块冲突。
func save_key() -> String:
    return "world.map"


## 序列化当前状态为字典。字段尽量用基础类型。
func on_save() -> Dictionary:
    return {
        "seed": world_seed,
        "width": map_width,
        "cells": _serialize_cells(),
    }


## 从字典恢复状态。p_data 是 on_save() 产出的同构数据。
func on_load(p_data: Dictionary) -> void:
    world_seed = p_data["seed"]
    map_width = p_data["width"]
    _deserialize_cells(p_data["cells"])


## 恢复优先级。数值越小越先恢复。默认 100。
func restore_priority() -> int:
    return 10  # 地图数据先于大多数模块恢复
```

四个方法的职责：

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `save_key()` | `String` | 唯一键名。不能为空。建议用命名空间如 `"world.map"` |
| `on_save()` | `Dictionary` | 序列化为字典。值应为 int/float/String/Array/Dict |
| `on_load(data)` | `void` | 从字典恢复。假设数据格式与 on_save 一致 |
| `restore_priority()` | `int` | 数值越小越先恢复。默认 100 |

### 第二步：三种注册路径

`GF_SaveService` 支持三种注册路径，各司其职：

#### 路径 1：手动注册（RefCounted 子类、Service 层）

```gdscript
var player_stats := PlayerStats.new()
save_service.register_saveable(player_stats)

var inventory := InventoryData.new()
save_service.register_saveable(inventory)
```

适用场景：GF_ISaveable 子类（RefCounted）、游戏 Service 的数据模块、Mod 注册的附加数据。

#### 路径 2：从节点树扫描（Node 上的 ISaveable）

```gdscript
# 在 GF_WorldRoot._on_world_setup() 中调用
func _on_world_setup() -> void:
    ctx.save.collect_from_node(self)
```

`collect_from_node(root)` 会递归扫描 `root` 的所有后代节点，自动注册实现了 `save_key`/`on_save`/`on_load` 方法的节点。

#### 路径 3：信号增量注册（collect 之后的动态变化）

`collect_from_node` 调用后，框架会自动连接 `root.child_entering_tree` 和 `root.child_exiting_tree` 信号。之后新挂入的节点如果实现了 ISaveable 方法，会自动注册；节点移出时自动注销。

```gdscript
# 框架内部自动完成，无需手动调用
# - child_entering_tree → register_saveable(node)
# - child_exiting_tree → unregister_saveable(save_key)
```

#### 鸭子类型检查

框架使用鸭子类型而非 `is` 检查：

```gdscript
func _is_saveable(p_obj) -> bool:
    return p_obj.has_method("save_key") and p_obj.has_method("on_save") and p_obj.has_method("on_load")
```

原因：Node 和 RefCounted 是两条并行继承链，`is GF_ISaveable` 无法同时覆盖两者。

### 第三步：保存存档

```gdscript
# 方式 A：保存所有已注册模块（推荐）
var meta := GF_SaveMeta.new()
meta.slot_id = 0
meta.summary = "城镇 — 第10天"
var result := save_service.save_all(0, meta)
if result.is_fail():
    _log.error("Save", "保存失败: %s" % result.error.message)

# 方式 B：保存自定义数据（不通过 ISaveable）
var custom_data := {"score": 999, "unlocked_levels": [1, 2, 3]}
var result := save_service.save(0, custom_data, meta)
```

`save_all` 内部流程：
1. 遍历所有已注册的 `_saveables`
2. 对每个 saveable 调用 `on_save()` 收集数据
3. 组装成 `{save_key: data_dict, ...}` 的字典
4. 写入 `save_version = GF_SaveVersion.CURRENT`
5. 通过 Provider 写入存储（本地文件、远程服务器等）

`GF_SaveMeta` 字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `slot_id` | `int` | 槽位编号 |
| `save_time` | `String` | 保存时间，由 Provider 写入 |
| `save_version` | `int` | 存档结构版本，框架自动写入 |
| `game_version` | `String` | 游戏版本号 |
| `play_time_seconds` | `float` | 累计游戏时间 |
| `summary` | `String` | 摘要，如"第3年 春季" |

### 第四步：加载存档

```gdscript
# 方式 A：加载并自动恢复（推荐）
var result := save_service.load_and_restore(0)
if result.is_fail():
    _log.error("Save", "加载失败: %s" % result.error.message)

# 方式 B：只读取数据不恢复（用于预览）
var result := save_service.load_slot(0)
if result.is_ok():
    var data := result.data as Dictionary
    print("存档包含 %d 个模块" % data.size())
```

`load_and_restore` 内部流程：
1. 通过 Provider 读取完整存档
2. 检测版本号并执行迁移链（如有需要）
3. 按 `restore_priority()` 对 saveable 排序
4. 按优先级顺序调用每个 saveable 的 `on_load(data)`
5. 对于存档中存在但未注册的 key，记录 warning 并跳过

### 第五步：恢复优先级

```gdscript
# 内容定义数据 → 最先恢复
func restore_priority() -> int: return 10

# 建筑数据 → 依赖地形，在 Map 之后
func restore_priority() -> int: return 50

# 单位数据 → 依赖建筑，在 Building 之后
func restore_priority() -> int: return 100  # 默认值

# UI 状态 → 最后恢复
func restore_priority() -> int: return 200
```

恢复时，`GF_SaveService._restore_save_data` 将所有 saveable 按 `restore_priority()` 升序排列后依次调用 `on_load`。

### 第六步：列表和删除

```gdscript
# 列出所有存档
var result := save_service.list_slots()
if result.is_ok():
    var slots: Array = result.data
    for meta in slots:
        print("槽位 %d: %s (%s)" % [meta.slot_id, meta.summary, meta.save_time])

# 删除存档
var result := save_service.delete_slot(3)
```

### 第七步：世界切换

```gdscript
# 在 Game 层世界切换流程中调用
save_service.on_world_switch(old_root, new_root, "world.")
```

`on_world_switch` 的行为：
1. 从旧世界的节点树断开 `child_entering_tree`/`child_exiting_tree` 信号连接
2. 按前缀 `"world."` 注销所有旧世界的 saveable（通过 `unregister_by_prefix`）
3. 在新世界的节点树上调用 `collect_from_node(new_root)`

这确保了世界切换后，旧世界的 ISaveable 被清理，新世界的 ISaveable 自动注册。

### 第八步：注销

```gdscript
# 按 key 注销单个
save_service.unregister_saveable("player_stats")

# 按前缀批量注销（Mod 卸载时）
save_service.unregister_by_prefix("mod.mymod.")

# 按 owner 注销
save_service.unregister_saveables_by_owner("mod:combat:")
```

---

## 完整示例：保存和加载玩家数据 + 世界状态

```gdscript
# ---- player_data.gd ----
class_name PlayerData
extends GF_ISaveable

var gold: int = 0
var level: int = 1
var position: Vector2 = Vector2.ZERO


func save_key() -> String:
    return "player"


func on_save() -> Dictionary:
    return {
        "gold": gold, "level": level,
        "pos_x": position.x, "pos_y": position.y,
    }


func on_load(p_data: Dictionary) -> void:
    gold = p_data.get("gold", 0)
    level = p_data.get("level", 1)
    position = Vector2(p_data.get("pos_x", 0.0), p_data.get("pos_y", 0.0))


# ---- inventory_data.gd ----
class_name InventoryData
extends GF_ISaveable

var items: Array[Dictionary] = []


func save_key() -> String:
    return "world.inventory"


func on_save() -> Dictionary:
    return {"items": items.duplicate(true)}


func on_load(p_data: Dictionary) -> void:
    items = (p_data.get("items", []) as Array).duplicate(true)


func restore_priority() -> int:
    return 150  # 在玩家数据之后恢复


# ---- world_root.gd ----
class_name GameWorld
extends GF_WorldRoot


func _on_world_setup() -> void:
    # 从节点树收集 ISaveable（建筑、NPC 等场景对象）
    ctx.save.collect_from_node(self)


# ---- 引导脚本中的注册 ----

func _setup_save_system(save_service: GF_SaveService) -> void:
    # 注册纯数据模块
    var player := PlayerData.new()
    var inventory := InventoryData.new()
    save_service.collect_from([player, inventory])

    # 注册版本迁移器
    save_service.register_migrator(V1ToV2Migrator.new())
    save_service.register_migrator(V2ToV3Migrator.new())


# ---- 保存流程 ----

func _on_save_game(slot_id: int) -> void:
    var meta := GF_SaveMeta.new()
    meta.slot_id = slot_id
    meta.game_version = "1.0.0"
    meta.play_time_seconds = _total_play_time
    meta.summary = "第 %d 天 — %s" % [_current_day, _current_location]

    var result := save_service.save_all(slot_id, meta)
    if result.is_fail():
        _log.error("Save", "存档失败: %s" % result.error.message)
        _show_save_error(result.error.message)
    else:
        _log.info("Save", "存档成功: 槽位 %d" % slot_id)
        _show_save_success()


# ---- 加载流程 ----

func _on_load_game(slot_id: int) -> void:
    # 切换到加载画面
    app_flow.transition_to(STATE_LOADING)

    var result := save_service.load_and_restore(slot_id)
    if result.is_fail():
        _log.error("Save", "加载失败: %s" % result.error.message)
        _show_load_error(result.error.message)
        return

    _log.info("Save", "加载成功: 槽位 %d" % slot_id)

    # 加载成功后重建游戏世界
    _rebuild_game_world()

    app_flow.transition_to(STATE_IN_GAME)


# ---- 存档选择界面 ----

func _build_save_slots_ui() -> void:
    var result := save_service.list_slots()
    if result.is_fail():
        return

    var slots: Array = result.data
    for meta in slots:
        var slot_ui := _create_slot_entry(
            meta.slot_id, meta.summary, meta.save_time, meta.play_time_seconds
        )
        $SaveList.add_child(slot_ui)
```

---

## 常见变体

### 变体 1：使用 key 前缀管理不同作用域的存档

```gdscript
# 世界数据使用 "world." 前缀
class_name WorldMap extends GF_ISaveable
func save_key() -> String: return "world.map"

# Profile 数据使用 "profile." 前缀
class_name PlayerProfile extends GF_ISaveable
func save_key() -> String: return "profile.settings"

# Mod 数据使用 "mod:" 前缀
class_name ModExtraData extends GF_ISaveable
func save_key() -> String: return "mod:combat:extra"

# 世界切换时只清理 "world." 前缀的模块
save_service.on_world_switch(old_root, new_root, "world.")
# profile 和 mod 数据不受影响
```

### 变体 2：Node 上的 ISaveable（不需要继承 GF_ISaveable）

```gdscript
# 直接在 Node 上实现鸭子类型方法
class_name SaveableBuilding
extends Node2D

var building_id: String = ""
var level: int = 1


func save_key() -> String:
    return "world.building.%s" % building_id


func on_save() -> Dictionary:
    return {"id": building_id, "level": level}


func on_load(p_data: Dictionary) -> void:
    building_id = p_data["id"]
    level = p_data["level"]
```

不需要 `extends GF_ISaveable`，只要实现了三个方法就能被 `collect_from_node` 自动识别。

### 变体 3：配合 EntityRegistry 实现多态实体

```gdscript
# 注册实体工厂
GF_EntityRegistry.register("unit", func(d): return Unit.from_dict(d))
GF_EntityRegistry.register("building", func(d): return Building.from_dict(d))

# 存档中带 type 字段
func on_save() -> Dictionary:
    return {
        "type": "unit",
        "id": 1, "health": 80,
    }

# 读档时根据 type 创建正确的子类
func on_load(p_data: Dictionary) -> void:
    var entity = GF_EntityRegistry.create(p_data["type"], p_data)
```

---

## 错误码

| 方法 | 可能的错误码 | 说明 |
|------|------------|------|
| `configure(provider, resolver, log)` | `ERR_BAD_REQUEST` | 任一参数为 null |
| `save_all(slot, meta)` | 取决于 Provider | Provider 的 save 方法错误 |
| `save(slot, data, meta)` | 取决于 Provider | Provider 的 save 方法错误 |
| `load_slot(slot)` | `ERR_MIGRATION` | 存档版本高于当前版本 |
| | `ERR_MIGRATION` | 缺少迁移器 |
| | 取决于 Provider | Provider 的 load_full 方法错误 |
| `load_and_restore(slot)` | 同上 | 继承自 load_slot |
| `list_slots()` | 取决于 Provider | Provider 的 list_slots 方法错误 |
| `delete_slot(slot)` | 取决于 Provider | Provider 的 delete 方法错误 |
| `collect_from(saveables)` | `ERR_BAD_REQUEST` | 有 saveable 的 save_key() 返回空 |

---

## See Also

- [存档版本迁移](./save-version-migration.md) -- 存档格式变更时的版本迁移
- [场景切换](./scene-switching.md) -- 世界切换与存档管理
- [模块间事件通信](./event-communication.md) -- 存档事件的通知
