# GF_EventBus

> 适用版本: 0.3.0 | 继承: GF_EventBus -> GF_ModuleLifecycle

## 概述

事件总线，提供基于事件的解耦通信机制。支持按事件名订阅、按 Scope 分组管理和通过 `GF_EventToken` 精确取消订阅。派发为同步执行，内置安全隔离（无效 callback 自动注销，单个 listener 异常不会阻断后续 listener）。配合 `GF_EventDef` 可实现编译期类型检查的 typed event。

**使用场景：**

- 跨模块通信：UI 层通知游戏层状态变化，无需直接引用
- 场景切换时一键清理订阅：`clear_scope("battle_ui")` 清理战斗 UI 的所有监听
- 一次性事件监听：`subscribe_once()` 用于等待加载完成或动画结束等一次性通知
- 与 `GF_EventDef` 配合使用，获得类型化事件和 payload 校验

**不适用场景：**

- 不要用于高频调用（如每帧触发的移动/渲染事件）—— 应使用 ECS System 或直接函数调用
- 不要用于需要返回值或响应确认的场景 —— 事件总线是 fire-and-forget 模式
- 不要在单个模块内部过度使用（模块内部应直接函数调用）

## 属性

此服务不暴露公共成员属性。

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| （无公共属性） | | | 通过方法访问所有功能 |

## 公共方法

### 生命周期

---

#### _on_dispose() -> GF_OperationResult
清除所有监听器、令牌和待处理移除列表。在 `ModuleLifecycle` 销毁阶段自动调用。

**返回值：** 始终返回 `GF_OperationResult.ok()`。

---

### 订阅

---

#### subscribe(p_event: String, p_callback: Callable, p_scope: String = "global") -> GF_EventToken
订阅事件。返回 `GF_EventToken` 用于后续精确取消订阅。同一个 callback 可以多次订阅同一事件（每次返回不同的 token）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_event | String | 事件名，如 `"player_died"`、`"item_collected"` |
| p_callback | Callable | 回调函数，签名为 `func(p_data)`，`p_data` 为 `publish()` 传入的数据 |
| p_scope | String | 作用域标识，默认为 `"global"`。用于 `clear_scope()` 批量清理 |

**返回值：** `GF_EventToken`，持有令牌可用于 `unsubscribe()` 或 `unsubscribe_token()` 取消订阅。

**示例：**
```gdscript
var token := event_bus.subscribe("player_died", _on_player_died, "battle")
func _on_player_died(data) -> void:
    print("玩家死亡，数据: ", data)
```

---

#### subscribe_once(p_event: String, p_callback: Callable, p_scope: String = "global") -> GF_EventToken
订阅一次性事件。首次派发后自动取消订阅。适用于等待单次通知的场景（如等待资源加载完成、动画结束等）。

**参数：** 同 `subscribe()`。

**返回值：** 同 `subscribe()`。

**示例：**
```gdscript
event_bus.subscribe_once("scene_loaded", func(data):
    print("场景加载完成，准备开始游戏")
)
```

---

### 取消订阅

---

#### unsubscribe_token(p_token_id: String) -> void
通过 `GF_EventToken` 的 `id` 取消订阅。派发过程中调用时延迟到派发结束后执行，防止遍历时修改列表。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_token_id | String | token 的 id，由 `subscribe()` 返回的 `GF_EventToken.id` |

**示例：**
```gdscript
var token := event_bus.subscribe("tick", _on_tick)
# 之后取消
event_bus.unsubscribe_token(token.id)
# 或直接通过 token 取消
token.unsubscribe()
```

---

#### unsubscribe(p_event: String, p_callback: Callable) -> void
向后兼容的取消订阅方法。按事件名 + callback 匹配来移除 listener。由于每个 `Callable` 的相等性由对象和方法组合决定，同一 callback 多次订阅时只移除第一个匹配项。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_event | String | 事件名 |
| p_callback | Callable | 要移除的回调函数 |

**注意：** 新代码推荐使用 `unsubscribe_token()` 或 `GF_EventToken.unsubscribe()`，更精确且避免歧义。

---

#### clear_scope(p_scope: String) -> void
清理指定 scope 下的所有订阅。常用于场景切换时释放该场景中所有监听器。派发过程中调用时延迟到派发结束后执行。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_scope | String | 要清理的 scope 名称 |

**示例：**
```gdscript
# 战斗场景中注册的所有事件使用 "battle" scope
event_bus.subscribe("damage_dealt", _on_damage, "battle")
event_bus.subscribe("unit_spawned", _on_unit_spawn, "battle")

# 退出战斗场景时一键清理
event_bus.clear_scope("battle")
```

---

### 发布

---

#### publish(p_event: String, p_data = null) -> void
同步发布事件。遍历所有订阅者并按注册顺序依次调用。每个 listener 通过 `_safe_dispatch` 安全调用 —— 无效 callback 自动注销，错误不阻断后续 listener。一次性订阅（`subscribe_once`）在派发后自动标记移除。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_event | String | 事件名 |
| p_data | Variant | 事件数据，传递给 listener callback，默认为 `null` |

**行为细节：**
- 无 listener 时静默返回，不报错
- 派发期间禁用：`unsubscribe_token()`、`unsubscribe()` 和 `clear_scope()` 调用会延迟到派发结束后统一执行
- 一次性订阅在派发后立即从 `_once_tokens` 移除，派发结束后从 listener 列表清除
- 无效 callback（所属对象已被释放）自动跳过并标记移除

**示例：**
```gdscript
# 发布不带数据的事件
event_bus.publish("game_started")

# 发布带数据的事件
event_bus.publish("player_damaged", {
    "amount": 25,
    "source": enemy,
    "current_hp": 75,
})
```

---

### 查询

---

#### has_listeners(p_event: String) -> bool
检查指定事件是否有订阅者。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_event | String | 事件名 |

**返回值：** `bool`，有至少一个订阅者返回 `true`。

---

#### listener_count(p_event: String) -> int
获取指定事件的订阅者数量。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_event | String | 事件名 |

**返回值：** `int`，订阅者数量，0 表示无订阅者或事件未注册。

---

#### token_count() -> int
获取系统当前活跃的 `GF_EventToken` 总数（包括一次性订阅）。

**返回值：** `int`，token 总数。

---

## 相关类型

### GF_EventDef

> 适用版本: 0.3.0 | 继承: GF_EventDef -> RefCounted

#### 概述

类型化事件定义。将事件名和可选的 payload 校验器封装在一起，替代裸字符串事件名。使用 `GF_EventDef` 常量可以获得编译期拼写检查和运行时 payload 结构校验。

#### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| event_name | String | `""` | 事件名 |

#### 公共方法

##### _init(p_name: String, p_validator: Callable = Callable()) -> void
构造函数。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_name | String | 事件名 |
| p_validator | Callable | 可选的 payload 校验器，签名为 `func(p_data) -> bool` |

##### validate(p_data) -> bool
校验 payload 是否合法。未设置校验器时始终返回 `true`。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_data | Variant | 待校验的事件数据 |

**返回值：** `bool`，数据合法返回 `true`。

**示例：**
```gdscript
# 无校验器的简单事件
const GAME_STARTED := GF_EventDef.new(&"game_started")

# 带 payload 校验的 typed event
const HEALTH_CHANGED := GF_EventDef.new(&"health_changed",
    func(p): return p.has("hp") and p.has("max_hp"))

const ITEM_COLLECTED := GF_EventDef.new(&"item_collected",
    func(p): return p.has("item_id") and p.has("count"))

# 使用
event_bus.publish(GAME_STARTED.event_name)
event_bus.publish(HEALTH_CHANGED.event_name, {"hp": 80, "max_hp": 100})
event_bus.subscribe(ITEM_COLLECTED.event_name, _on_item_collected)

# 校验 payload
if ITEM_COLLECTED.validate(data):
    event_bus.publish(ITEM_COLLECTED.event_name, data)
```

---

### GF_EventToken

> 适用版本: 0.3.0 | 继承: GF_EventToken -> RefCounted

#### 概述

订阅令牌，由 `GF_EventBus.subscribe()` 返回。持有者可通过 `unsubscribe()` 方法取消对应的订阅，无需记住事件名和 callback。

#### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| id | String | `""` | token 唯一标识，格式为 `"{event_name}_{counter}"` |

#### 公共方法

##### unsubscribe() -> void
取消此令牌对应的订阅。内部调用 `GF_EventBus.unsubscribe_token(id)`。通过 `WeakRef` 持有对 EventBus 的引用，如果 EventBus 已被释放则静默跳过。

**示例：**
```gdscript
var token := event_bus.subscribe("tick", _on_tick)
# 通过 token 取消，无需记住事件名或 callback
token.unsubscribe()
```

---

## See Also

- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) -- 模块生命周期基类
- [GF_EventDef](#gf_eventdef) -- 类型化事件定义
- [GF_EventToken](#gf_eventtoken) -- 订阅令牌
