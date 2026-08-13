# 模块间事件通信

## 场景描述

游戏模块之间需要松耦合地通信——成就系统监听击杀事件、UI 更新响应数值变化、存档系统通知保存完成。框架的 `GF_EventBus` 提供发布-订阅模式的事件系统，所有事件通过 `GF_EventDef` 标识（不接受裸字符串），支持 payload 校验、Token 管理和 Scope 批量清理。

本章覆盖：事件定义、订阅和取消订阅、一次性订阅、Token 管理、Scope 批量清理、带验证的事件、完整的成就系统示例。

---

## 最小示例

```gdscript
# 1. 定义事件（集中在事件定义文件中）
class_name GameEvents
extends RefCounted

static var ENEMY_KILLED := GF_EventDef.new("enemy_killed")

# 2. 订阅事件
var token := event_bus.subscribe(GameEvents.ENEMY_KILLED, _on_enemy_killed)

# 3. 发布事件
event_bus.publish(GameEvents.ENEMY_KILLED, {"enemy_type": "goblin", "position": Vector2(100, 200)})

# 4. 处理事件
func _on_enemy_killed(payload: Dictionary) -> void:
    print("击杀了: ", payload["enemy_type"])

# 5. 取消订阅
token.unsubscribe()
```

---

## 第一步：定义事件

事件定义集中在专用的常量类中。框架内置事件在 `GF_Events`，Game 层照此模式建自己的集合：

```gdscript
# game_events.gd
class_name GameEvents
extends RefCounted

## 击杀敌人。payload: {enemy_type: String, position: Vector2}
static var ENEMY_KILLED := GF_EventDef.new("enemy_killed")

## 分数变化。payload: {new_score: int}
static var SCORE_CHANGED := GF_EventDef.new("score_changed",
    func(p): return p is Dictionary and p.has("new_score"))

## 玩家死亡
static var PLAYER_DIED := GF_EventDef.new("player_died")

## 关卡完成
static var LEVEL_COMPLETE := GF_EventDef.new("level_complete",
    func(p): return p is Dictionary and p.has("level_id"))
```

**注意：** GDScript 的 `const` 不能存 `GF_EventDef.new()`（非编译期常量表达式），必须使用 `static var`——类首次加载时初始化一次，行为与 const 等价。

## 第二步：订阅事件

```gdscript
# 基本订阅
var token := event_bus.subscribe(GameEvents.SCORE_CHANGED, func(payload: Dictionary):
    _update_score_display(payload["new_score"])
)

# 带 scope 的订阅（用于批量清理）
var token := event_bus.subscribe(GameEvents.PLAYER_DIED, _on_player_died, "gameplay")

# 一次性订阅（触发一次后自动取消）
var token := event_bus.subscribe_once(GameEvents.LEVEL_COMPLETE, func(payload: Dictionary):
    _show_victory_screen(payload["level_id"])
)
```

`subscribe` 参数：
- `p_event: GF_EventDef` — 事件定义
- `p_callback: Callable` — 回调函数，接收 payload
- `p_scope: String = "global"` — 可选的作用域标签，用于 `clear_scope` 批量清理

返回值：`GF_EventToken` 对象，用于取消订阅。

## 第三步：发布事件

```gdscript
# 发布事件（payload 为 Dictionary）
event_bus.publish(GameEvents.ENEMY_KILLED, {
    "enemy_type": "goblin",
    "position": Vector2(100, 200),
})

# payload 校验失败时派发中止，控制台输出错误
event_bus.publish(GameEvents.SCORE_CHANGED, {})  # 缺少 new_score → push_error
```

`publish` 的行为：
1. 执行 `GF_EventDef` 的 payload 校验，失败 `push_error` 并中止（fail fast）
2. 同步遍历该事件的所有监听器（对副本遍历，安全处理调度期间的修改）
3. 无效的回调自动清理，单个 listener 异常不阻断后续派发
4. 一次性订阅派发后自动移除

## 第四步：取消订阅

```gdscript
# 方式 A：通过 Token（推荐）
token.unsubscribe()

# 方式 B：通过 event + callback
event_bus.unsubscribe(GameEvents.SCORE_CHANGED, _on_score_changed)

# 方式 C：通过 Scope 批量清理
event_bus.clear_scope("gameplay")  # 取消所有 scope="gameplay" 的订阅
```

## 第五步：Scope 模式

Scope 是订阅时附加的字符串标签，用于按业务域批量清理：

```gdscript
# UI 相关的订阅使用 "ui" scope
event_bus.subscribe(GameEvents.SCORE_CHANGED, _update_score_ui, "ui")
event_bus.subscribe(GameEvents.ENEMY_KILLED, _update_kill_counter, "ui")

# 面板关闭时批量清理
func _on_close() -> void:
    event_bus.clear_scope("ui")
```

## 第六步：事件命名规范

`event_name` 建议使用 `snake_case`，按领域分层：

```
player_died           — 玩家事件
enemy_killed          — 战斗事件
item_collected        — 物品事件
quest_completed       — 任务事件
ui_panel_opened       — UI 事件
flow_state_changed    — 流程事件（框架内置，GF_Events.FLOW_STATE_CHANGED）
save_completed        — 存档事件
```

---

## 完整示例：成就系统监听击杀事件

```gdscript
# ---- game_events.gd（事件定义） ----

class_name GameEvents
extends RefCounted

static var ENEMY_KILLED := GF_EventDef.new("enemy_killed",
    func(p): return p is Dictionary and p.has("enemy_type"))

static var ITEM_COLLECTED := GF_EventDef.new("item_collected",
    func(p): return p is Dictionary and p.has("item_id") and p.has("count"))

static var BOSS_DEFEATED := GF_EventDef.new("boss_defeated",
    func(p): return p is Dictionary and p.has("boss_id"))

static var ACHIEVEMENT_UNLOCKED := GF_EventDef.new("achievement_unlocked",
    func(p): return p is Dictionary and p.has("ach_id"))


# ---- achievement_system.gd ----

class_name AchievementSystem
extends RefCounted

var _event_bus: GF_EventBus = null
var _unlocked: Array[String] = []

var _stats := {
    "enemy_killed_count": 0,
    "goblin_killed": 0,
}


func configure(p_event_bus: GF_EventBus) -> void:
    _event_bus = p_event_bus


func start_tracking() -> void:
    _event_bus.subscribe(GameEvents.ENEMY_KILLED, _on_enemy_killed, "achievement")
    _event_bus.subscribe(GameEvents.ITEM_COLLECTED, _on_item_collected, "achievement")
    _event_bus.subscribe(GameEvents.BOSS_DEFEATED, _on_boss_defeated, "achievement")


func stop_tracking() -> void:
    _event_bus.clear_scope("achievement")


func _on_enemy_killed(payload: Dictionary) -> void:
    _stats["enemy_killed_count"] += 1
    if payload["enemy_type"] == "goblin":
        _stats["goblin_killed"] += 1
    _check_achievements()


func _on_item_collected(_payload: Dictionary) -> void:
    _check_achievements()


func _on_boss_defeated(_payload: Dictionary) -> void:
    _check_achievements()


func _check_achievements() -> void:
    if _stats["enemy_killed_count"] >= 1 and not _unlocked.has("first_blood"):
        _unlock("first_blood", "首次击杀")
    if _stats["goblin_killed"] >= 50 and not _unlocked.has("goblin_slayer"):
        _unlock("goblin_slayer", "击杀 50 个哥布林")


func _unlock(p_ach_id: String, p_desc: String) -> void:
    _unlocked.append(p_ach_id)
    _event_bus.publish(GameEvents.ACHIEVEMENT_UNLOCKED, {"ach_id": p_ach_id, "desc": p_desc})


# ---- 在游戏模块中发布事件 ----

func _on_enemy_died(enemy_type: String, position: Vector2) -> void:
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
    event_bus.subscribe(GameEvents.SCORE_CHANGED, _update_score, "ui")
    event_bus.subscribe(GameEvents.ENEMY_KILLED, _update_kill_counter, "ui")


func _on_close() -> void:
    event_bus.clear_scope("ui")
```

### 变体 2：一次性订阅（等待某个条件）

```gdscript
event_bus.subscribe_once(GameEvents.SAVE_COMPLETED, func(payload: Dictionary):
    if payload.get("success", false):
        _show_notification("存档成功")
    else:
        _show_notification("存档失败")
)
```

### 变体 3：事件发布同步特性

`publish` 是同步的——所有监听器在 `publish` 调用期间依次执行。不要在监听器中发布可能触发递归的事件。

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
| `publish(event, payload)` | 无监听器时静默跳过；payload 校验失败时 push_error 并中止 |

---

## See Also

- [GF_EventBus API 参考](../api-reference/services/gf_event_bus.md)
- [应用状态机](./app-state-flow.md) -- `GF_Events.FLOW_STATE_CHANGED` 框架内置事件
- [实现游戏存档](./save-game-progress.md) -- 存档事件通信
