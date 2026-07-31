# 模块间事件通信

## 场景描述

游戏模块之间需要松耦合地通信——成就系统监听击杀事件、UI 更新响应数值变化、存档系统通知保存完成。框架的 `GF_EventBus` 提供发布-订阅模式的事件系统，支持带验证的事件定义、Token 管理和 Scope 批量清理。

本章覆盖：订阅和取消订阅、一次性订阅、Token 管理、Scope 批量清理、EventDef 带验证的事件、完整的成就系统示例。

---

## 最小示例

```gdscript
# 1. 订阅事件
var token := event_bus.subscribe("enemy_killed", _on_enemy_killed)

# 2. 发布事件
event_bus.publish("enemy_killed", {"enemy_type": "goblin", "position": Vector2(100, 200)})

# 3. 处理事件
func _on_enemy_killed(payload: Dictionary) -> void:
    print("击杀了: ", payload["enemy_type"])

# 4. 取消订阅
token.unsubscribe()
```

---

## 逐步解释

### 第一步：订阅事件

```gdscript
# 基本订阅
var token := event_bus.subscribe("score_changed", func(payload: Dictionary):
    _update_score_display(payload["new_score"])
)

# 带 scope 的订阅（用于批量清理）
var token := event_bus.subscribe("player_died", _on_player_died, "gameplay")

# 一次性订阅（触发一次后自动取消）
var token := event_bus.subscribe_once("level_complete", func(payload: Dictionary):
    _show_victory_screen(payload["level_id"])
)
```

`subscribe` 参数：
- `p_event: String` — 事件名称
- `p_callback: Callable` — 回调函数，接收 `Dictionary` 参数
- `p_scope: String = ""` — 可选的作用域标签，用于 `clear_scope` 批量清理

返回值：`GF_EventToken` 对象，用于取消订阅。

### 第二步：发布事件

```gdscript
# 发布事件（payload 为 Dictionary）
event_bus.publish("item_collected", {
    "item_id": "iron_sword",
    "count": 1,
    "source": "chest",
})

# 发布无数据事件
event_bus.publish("game_saved", {})
```

`publish` 的行为：
1. 同步遍历该事件的所有监听器（对副本遍历，安全处理调度期间的修改）
2. 通过 `_safe_dispatch` 检查回调有效性，无效的回调自动清理
3. 延迟移除标记为待删除的监听器

### 第三步：取消订阅

```gdscript
# 方式 A：通过 Token（推荐）
token.unsubscribe()

# 方式 B：通过 event + callback（向后兼容）
event_bus.unsubscribe("score_changed", _on_score_changed)

# 方式 C：通过 Scope 批量清理
event_bus.clear_scope("gameplay")  # 取消所有 scope="gameplay" 的订阅
```

### 第四步：使用 GF_EventDef 带验证的事件

`GF_EventDef` 将事件定义为常量，支持可选的负载验证：

```gdscript
# 定义事件常量（放在 Game 层的事件定义文件中）
const HEALTH_CHANGED := GF_EventDef.new("health_changed",
    func(p): return p.has("current") and p.has("max"))

const ITEM_COLLECTED := GF_EventDef.new("item_collected",
    func(p): return p.has("item_id") and p.has("count"))

const ENEMY_KILLED := GF_EventDef.new("enemy_killed")

# 使用
event_bus.publish(HEALTH_CHANGED, {"current": 80, "max": 100})
# 如果 payload 不满足验证条件，回调不会被调用
```

验证器函数接收 payload Dictionary，返回 `bool`。返回 `false` 时事件不会被分发。

### 第五步：Scope 模式

Scope 是订阅时附加的字符串标签，用于按业务域批量清理：

```gdscript
# UI 相关的订阅使用 "ui" scope
event_bus.subscribe("score_changed", _update_score_ui, "ui")
event_bus.subscribe("health_changed", _update_health_bar, "ui")
event_bus.subscribe("inventory_changed", _refresh_inventory, "ui")

# 面板关闭时批量清理
func _on_close() -> void:
    event_bus.clear_scope("ui")

# 世界切换时清理世界观订阅
event_bus.clear_scope("world")
```

### 第六步：事件命名规范

建议使用 `snake_case`，按领域分层：

```
player_died           — 玩家事件
enemy_killed          — 战斗事件
item_collected        — 物品事件
quest_completed       — 任务事件
ui_panel_opened       — UI 事件
flow_state_changed    — 流程事件（框架内置）
save_completed        — 存档事件
```

---

## 完整示例：成就系统监听击杀事件

```gdscript
# ---- achievement_defs.gd（事件常量定义） ----

class_name GameEvents
extends RefCounted

const ENEMY_KILLED := GF_EventDef.new("enemy_killed",
    func(p): return p.has("enemy_type"))

const ITEM_COLLECTED := GF_EventDef.new("item_collected",
    func(p): return p.has("item_id") and p.has("count"))

const BOSS_DEFEATED := GF_EventDef.new("boss_defeated",
    func(p): return p.has("boss_id"))

const LEVEL_REACHED := GF_EventDef.new("level_reached",
    func(p): return p.has("level"))


# ---- achievement_system.gd ----

class_name AchievementSystem
extends RefCounted

var _event_bus: GF_EventBus = null
var _unlocked: Array[String] = []
var _token: GF_EventToken = null

# 成就定义
const ACHIEVEMENTS := {
    "first_blood": {"desc": "首次击杀", "condition": "enemy_killed_count >= 1"},
    "slayer":      {"desc": "击杀 100 个敌人", "condition": "enemy_killed_count >= 100"},
    "goblin_slayer":{"desc": "击杀 50 个哥布林", "condition": "goblin_killed >= 50"},
    "collector":   {"desc": "收集 10 种不同物品", "condition": "unique_items >= 10"},
    "dragon_slayer":{"desc": "击败巨龙", "condition": "boss_dragon_defeated"},
}

var _stats := {
    "enemy_killed_count": 0,
    "goblin_killed": 0,
    "unique_items": 0,
    "boss_dragon_defeated": false,
}


func configure(p_event_bus: GF_EventBus) -> void:
    _event_bus = p_event_bus


func start_tracking() -> void:
    # 一次性订阅多个事件
    _event_bus.subscribe(GameEvents.ENEMY_KILLED.event_name, _on_enemy_killed, "achievement")
    _event_bus.subscribe(GameEvents.ITEM_COLLECTED.event_name, _on_item_collected, "achievement")
    _event_bus.subscribe(GameEvents.BOSS_DEFEATED.event_name, _on_boss_defeated, "achievement")


func stop_tracking() -> void:
    _event_bus.clear_scope("achievement")


func _on_enemy_killed(payload: Dictionary) -> void:
    _stats["enemy_killed_count"] += 1
    if payload["enemy_type"] == "goblin":
        _stats["goblin_killed"] += 1
    _check_achievements()


func _on_item_collected(payload: Dictionary) -> void:
    # 此处可追踪唯一物品数量
    _check_achievements()


func _on_boss_defeated(payload: Dictionary) -> void:
    if payload["boss_id"] == "dragon":
        _stats["boss_dragon_defeated"] = true
    _check_achievements()


func _check_achievements() -> void:
    for ach_id in ACHIEVEMENTS.keys():
        if ach_id in _unlocked:
            continue
        if _evaluate_condition(ACHIEVEMENTS[ach_id]["condition"]):
            _unlock_achievement(ach_id)


func _evaluate_condition(p_condition: String) -> bool:
    match p_condition:
        "enemy_killed_count >= 1":  return _stats["enemy_killed_count"] >= 1
        "enemy_killed_count >= 100": return _stats["enemy_killed_count"] >= 100
        "goblin_killed >= 50":       return _stats["goblin_killed"] >= 50
        "unique_items >= 10":        return _stats["unique_items"] >= 10
        "boss_dragon_defeated":      return _stats["boss_dragon_defeated"]
    return false


func _unlock_achievement(p_ach_id: String) -> void:
    _unlocked.append(p_ach_id)
    print("解锁成就: %s — %s" % [p_ach_id, ACHIEVEMENTS[p_ach_id]["desc"]])
    # 通过事件广播成就（UI 层可监听以显示通知）
    _event_bus.publish("achievement_unlocked", {
        "ach_id": p_ach_id,
        "desc": ACHIEVEMENTS[p_ach_id]["desc"],
    })


# ---- 在游戏模块中发布事件 ----

func _on_enemy_died(enemy_type: String, position: Vector2) -> void:
    # 战斗系统在处理完击杀逻辑后发布事件
    event_bus.publish(GameEvents.ENEMY_KILLED, {
        "enemy_type": enemy_type,
        "position": position,
    })
```

---

## 常见变体

### 变体 1：UI 层监听事件更新显示

```gdscript
func _on_open(_p_data: Dictionary) -> void:
    # 用 "ui" scope 订阅，面板关闭时自动清理
    ctx.event.subscribe("score_changed", _update_score, "ui")
    ctx.event.subscribe("health_changed", _update_health, "ui")


func _on_close() -> void:
    ctx.event.clear_scope("ui")
```

### 变体 2：一次性订阅（等待某个条件）

```gdscript
# 等待存档完成的通知
event_bus.subscribe_once("save_completed", func(payload: Dictionary):
    if payload.get("success", false):
        _show_notification("存档成功")
    else:
        _show_notification("存档失败")
)
```

### 变体 3：事件发布同步特性

`publish` 是同步的——所有监听器在 `publish` 调用期间依次执行，`publish` 返回后所有监听器都已执行完毕。这意味着：
- 监听器中的代码执行顺序可预测
- 不要在监听器中发布可能触发递归的事件

---

## 错误码

`GF_EventBus` 的方法不返回 `GF_OperationResult`。以下是行为说明：

| 方法 | 行为 |
|------|------|
| `subscribe(event, callback, scope)` | 总是返回有效的 `GF_EventToken` |
| `subscribe_once(event, callback, scope)` | 同上，触发后自动取消 |
| `unsubscribe_token(token)` | 静默处理无效 token |
| `unsubscribe(event, callback)` | 静默处理不存在的订阅 |
| `clear_scope(scope)` | 静默处理不存在的 scope |
| `publish(event, payload)` | 事件无监听器时静默跳过 |

---

## See Also

- [应用状态机](./app-state-flow.md) -- `flow_state_changed` 框架内置事件
- [实现游戏存档](./save-game-progress.md) -- 存档事件通信
- [创建和管理 UI 面板](./create-ui-panels.md) -- UI 层通过事件更新
