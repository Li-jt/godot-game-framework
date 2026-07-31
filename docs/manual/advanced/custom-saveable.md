# 自定义非 Node 存档

## 概述

GF_SaveService 的存档系统默认通过 `collect_from_node(root)` 自动扫描场景树中的 Node 子类 ISaveable。但在很多场景下，你需要存档的数据并不绑定到某个 Node 实例上。这时需要手动实现非 Node 的 ISaveable 并显式注册。

## 什么时候需要非 Node 的 ISaveable

| 场景 | 说明 | 示例 |
|------|------|------|
| 纯数据对象 | 不挂场景树，只存逻辑状态 | 成就系统、统计数据、全局设置 |
| ECS 数据 | ECS 实体和组件不通过 Node 管理 | GF_EcsSaveAdapter 本身就是非 Node saveable |
| Service 状态 | 框架服务自身的持久化状态 | 音频音量设置、输入按键绑定 |
| Mod 数据 | 第三方 Mod 注入的数据 | Mod 专属的玩法和配置状态 |

## RefCounted ISaveable 的实现

### 基本模板

```gdscript
class_name AchievementData
extends GF_ISaveable

var unlocked: Dictionary = {}  # {String achievement_id: bool}

func save_key() -> String:
    return "achievements"

func on_save() -> Dictionary:
    return {
        "unlocked": unlocked.duplicate(true),
    }

func on_load(p_data: Dictionary) -> void:
    unlocked = p_data.get("unlocked", {}).duplicate(true)

## 成就数据依赖内容定义先恢复
func restore_priority() -> int:
    return 20
```

### 使用方式

```gdscript
# 在 Game 层的 _on_post_boot 或 _on_app_ready 中注册
func _on_app_ready(p_context: GF_GameServices) -> void:
    var achievements := AchievementData.new()
    p_context.save_service.register_saveable(achievements)
```

## 注册路径对比

框架提供三种 ISaveable 注册路径：

| 路径 | 适用场景 | 调用方 |
|------|---------|--------|
| `collect_from_node(root)` | 场景树中的 Node ISaveable | SceneHost / on_world_switch |
| `child_entering_tree` 信号 | collect 之后的增量注册 | 框架自动 |
| `register_saveable(obj)` | 纯数据、Service、Mod ISaveable | Game 层手动调用 |

**关键：** 非 Node ISaveable 只能通过 `register_saveable()` 手动注册，框架不会自动发现它们。

## restore_priority 的正确设置

`restore_priority()` 返回的数值控制存档恢复顺序，数值越小越先恢复。默认值为 100。

| 优先级 | 典型模块 | 原因 |
|--------|---------|------|
| 1-9 | 地形/地图数据 | 其他实体依赖地形 |
| 10-19 | 内容定义 | 建筑、物品等需要先加载 Def |
| 20-29 | ECS 实体 | 依赖内容定义 |
| 50-99 | 建筑/放置物 | 依赖地形和定义 |
| 100-149 | 服务状态 | 依赖实体数据 |
| 150+ | UI 状态 | 最后恢复，依赖所有数据 |

```gdscript
# 地形最先恢复
class_name MapData extends GF_ISaveable
func restore_priority() -> int: return 1

# Mod 数据通常较高优先级，避免覆盖框架数据
class_name ModSaveData extends GF_ISaveable
func restore_priority() -> int: return 110
```

## 多实例存档（Array/Dictionary 中的 ISaveable）

当需要存档同一类型的多个实例时（如多个成就组、多个 Mod 的数据），使用不同的 `save_key` 前缀：

```gdscript
# 注册多个 Mod 的独立存档数据
func _register_mod_saveables(p_context: GF_GameServices) -> void:
    for mod_id in enabled_mods:
        var data := ModSaveData.new_for(mod_id)
        # save_key 返回 "mod:fishing:v1"
        p_context.save_service.register_saveable(data)
```

存档数据的 key 结构设计建议：

| 前缀 | 用途 | 示例 |
|------|------|------|
| `world.` | 世界级数据，世界切换时注销 | `world.entities`, `world.map` |
| `profile.` | 玩家档案级，跨世界持久 | `profile.stats`, `profile.settings` |
| `mod:<name>:` | Mod 数据，按 owner 批量管理 | `mod:fishing:catches` |
| `svc.` | 服务状态 | `svc.audio`, `svc.input` |

## 完整示例：成就系统纯数据存档

```gdscript
# achievement_system.gd
class_name AchievementSystem
extends RefCounted

var _achievements: Dictionary = {}     # {id: {name, desc, unlocked, unlocked_at}}
var _event_bus: GF_EventBus = null
var _save_service: GF_SaveService = null
var _log: GF_LogService = null


func configure(p_event_bus: GF_EventBus, p_save: GF_SaveService, p_log: GF_LogService) -> void:
    _event_bus = p_event_bus
    _save_service = p_save
    _log = p_log

    # 注册存档
    var saveable := _AchievementSaveable.new(self)
    _save_service.register_saveable(saveable)

    # 监听游戏事件
    _event_bus.subscribe("enemy_killed", _on_enemy_killed, "achievement")
    _event_bus.subscribe("item_collected", _on_item_collected, "achievement")


func register_achievement(p_id: String, p_name: String, p_desc: String) -> void:
    _achievements[p_id] = {
        "name": p_name, "desc": p_desc,
        "unlocked": false, "unlocked_at": 0,
    }


func unlock(p_id: String) -> bool:
    if not _achievements.has(p_id):
        return false
    var ach: Dictionary = _achievements[p_id]
    if ach["unlocked"]:
        return false
    ach["unlocked"] = true
    ach["unlocked_at"] = Time.get_unix_time_from_system()
    _log.info("Achievement", "成就解锁: %s" % ach["name"])
    _event_bus.publish("achievement_unlocked", {"id": p_id, "name": ach["name"]})
    return true


func _on_enemy_killed(p_data: Dictionary) -> void:
    var count: int = p_data.get("total_kills", 0)
    if count >= 100:
        unlock("kill_100")


func _on_item_collected(p_data: Dictionary) -> void:
    var item_id: String = p_data.get("item_id", "")
    if item_id == "golden_apple":
        unlock("collect_golden_apple")
```

```gdscript
# _achievement_saveable.gd (内部类或独立文件)
class _AchievementSaveable extends GF_ISaveable:
    var _system: AchievementSystem

    func _init(p_system: AchievementSystem) -> void:
        _system = p_system

    func save_key() -> String:
        return "achievements"

    func on_save() -> Dictionary:
        # 只存成就状态，不存定义
        var data := {}
        for id in _system._achievements:
            var ach: Dictionary = _system._achievements[id]
            data[id] = {
                "unlocked": ach["unlocked"],
                "unlocked_at": ach["unlocked_at"],
            }
        return {"achievements": data}

    func on_load(p_data: Dictionary) -> void:
        var saved: Dictionary = p_data.get("achievements", {})
        for id in saved:
            if _system._achievements.has(id):
                var src: Dictionary = saved[id]
                var ach: Dictionary = _system._achievements[id]
                ach["unlocked"] = src.get("unlocked", false)
                ach["unlocked_at"] = src.get("unlocked_at", 0)

    func restore_priority() -> int:
        return 120  # 在游戏数据之后恢复
```

## 关键注意事项

1. **`on_save()` 返回的数据必须是可序列化的基础类型**（int、float、String、Dictionary、Array），不要包含 Node、Object、Resource 引用。
2. **`on_load()` 必须处理数据缺失的降级**。存档可能来自旧版本，缺少某些字段。
3. **世界切换时注意注册/注销时机**。世界级数据应在 `on_world_switch` 时通过前缀注销。
4. **`restore_priority()` 控制恢复顺序**。确保被依赖的数据先恢复。
5. **使用 `unregister_by_prefix()` 批量管理**。切换世界或卸载 Mod 时清理相关数据。
6. **不要忘记在 `_on_dispose` 中注销**。避免死引用导致存档膨胀。
