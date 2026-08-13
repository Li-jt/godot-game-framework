# GF_EventBus

> 适用版本: 0.3.0 | 继承: GF_EventBus -> GF_ModuleLifecycle

## 概述

事件总线，提供基于事件的解耦通信机制。所有事件通过 `GF_EventDef` 标识（不接受裸字符串），`publish()` 自动执行 payload 校验。支持按 Scope 分组管理和通过 `GF_EventToken` 精确取消订阅。派发为同步执行，内置安全隔离（无效 callback 自动注销，单个 listener 异常不会阻断后续 listener）。

**使用场景：**

- 跨模块通信：UI 层通知游戏层状态变化，无需直接引用
- 场景切换时一键清理订阅：`clear_scope("battle_ui")` 清理战斗 UI 的所有监听
- 一次性事件监听：`subscribe_once()` 用于等待加载完成或动画结束等一次性通知
- payload 校验：事件定义时声明校验器，`publish()` 时 fail fast

**不适用场景：**

- 不要用于高频调用（如每帧触发的移动/渲染事件）—— 应使用 ECS System 或直接函数调用
- 不要用于需要返回值或响应确认的场景 —— 事件总线是 fire-and-forget 模式
- 不要在单个模块内部过度使用（模块内部应直接函数调用）

## 事件定义

事件定义集中在 `GF_Events`（框架内置事件）和 Game 层自己的事件集合类：

```gdscript
# Game 层：game_events.gd
class_name GameEvents
extends RefCounted

static var ENEMY_KILLED := GF_EventDef.new("enemy_killed")
static var SCORE_CHANGED := GF_EventDef.new("score_changed",
    func(p): return p is Dictionary and p.has("new_score"))
```

## 公共方法

### 订阅

#### subscribe(p_event: GF_EventDef, p_callback: Callable, p_scope: String = "global") -> GF_EventToken
订阅事件。返回 `GF_EventToken` 用于后续精确取消订阅。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_event | GF_EventDef | 事件定义，如 `GameEvents.ENEMY_KILLED` |
| p_callback | Callable | 回调函数，签名为 `func(p_data)`，`p_data` 为 `publish()` 传入的数据 |
| p_scope | String | 作用域标识，默认为 `"global"`。用于 `clear_scope()` 批量清理 |

**返回值：** `GF_EventToken`，持有令牌可用于 `unsubscribe_token()` 或 `token.unsubscribe()`。

**示例：**
```gdscript
var token := event_bus.subscribe(GameEvents.ENEMY_KILLED, _on_enemy_killed, "battle")
```

#### subscribe_once(p_event: GF_EventDef, p_callback: Callable, p_scope: String = "global") -> GF_EventToken
订阅一次性事件。首次派发后自动取消订阅。

### 取消订阅

#### unsubscribe_token(p_token_id: String) -> void
通过 `GF_EventToken` 的 `id` 取消订阅。派发过程中调用时延迟到派发结束后执行。

#### unsubscribe(p_event: GF_EventDef, p_callback: Callable) -> void
按事件定义 + callback 匹配移除 listener。

#### clear_scope(p_scope: String) -> void
清理指定 scope 下的所有订阅。常用于场景切换时释放该场景中所有监听器。

### 发布

#### publish(p_event: GF_EventDef, p_data = null) -> void
同步发布事件。先执行 `GF_EventDef` 的 payload 校验，失败 `push_error` 并中止派发（fail fast）。然后按注册顺序派发到所有订阅者。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_event | GF_EventDef | 事件定义 |
| p_data | Variant | 事件数据，传递给 listener callback，默认为 `null` |

**示例：**
```gdscript
event_bus.publish(GameEvents.ENEMY_KILLED, {"enemy_type": "goblin"})

# payload 校验失败时不会派发，控制台输出错误
event_bus.publish(GameEvents.SCORE_CHANGED, {})  # 缺少 new_score → push_error
```

### 查询

#### has_listeners(p_event: GF_EventDef) -> bool
检查指定事件是否有订阅者。

#### listener_count(p_event: GF_EventDef) -> int
获取指定事件的订阅者数量。

#### token_count() -> int
获取当前活跃的 `GF_EventToken` 总数。

## 相关类型

### GF_Events

框架内置事件的集中定义：

| 事件 | payload | 说明 |
|------|---------|------|
| `GF_Events.FLOW_STATE_CHANGED` | `{from, to, payload}` | GF_AppFlow 状态切换 |

### GF_EventDef

类型化事件定义。事件名 + 可选 payload 校验器。

**注意：** GDScript 的 `const` 不能存 `GF_EventDef.new()`（非编译期常量），集中定义时使用 `static var`。

### GF_EventToken

订阅令牌，由 `GF_EventBus.subscribe()` 返回。`token.unsubscribe()` 取消对应订阅。

## See Also

- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) -- 模块生命周期基类
- [GF_AppFlow](../services/gf_app_flow.md) -- 应用流程状态机
