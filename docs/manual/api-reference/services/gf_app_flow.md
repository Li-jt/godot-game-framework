# GF_AppFlow

> 适用版本: 0.3.0 | 继承: GF_AppFlow -> GF_ModuleLifecycle

## 概述

应用流程状态机。管理 App 级逻辑状态（非 Godot SceneTree 状态），所有状态切换通过此服务完成。各模块不自行判断"当前在哪个界面"，统一由此服务驱控。每次状态切换通过 `GF_EventBus` 发布 `"flow_state_changed"` 事件。

**使用场景**：

- 在 Application 层初始化后将 `GF_AppFlow` 注册到 `GameServices`
- 场景切换、菜单进入、存档加载等流程驱动
- 监听 `"flow_state_changed"` 事件响应状态变化
- 通过 `current_payload` 携带过渡上下文（slot_id、world_id 等）

**不适用场景**：

- 不要用于管理 SceneTree 节点切换（Game 层通过 GF_SceneFactory 自行管理）
- 不要绕过此服务直接修改 `current_state`
- 不要在事件监听中再次调用 `transition_to()` 形成递归循环

## 状态常量

| 常量 | 值 | 描述 |
|------|-----|------|
| `STATE_BOOT` | `&"boot"` | 启动状态，Framework 资源加载、配置完成后的初始状态 |
| `STATE_MAIN_MENU` | `&"main_menu"` | 主菜单状态，可选择开始游戏、读档、设置等 |
| `STATE_LOADING` | `&"loading"` | 加载状态，异步加载场景或存档时的过渡状态 |
| `STATE_IN_GAME` | `&"in_game"` | 游戏中状态，正常的游戏流程 |
| `STATE_PAUSE` | `&"pause"` | 暂停状态，游戏逻辑暂停但仍可操作暂停菜单 |

### 状态流转图

```
BOOT → MAIN_MENU → LOADING → IN_GAME ⇄ PAUSE
         ↑                        ↓
         └────────────────────────┘
```

- `BOOT` 只能切换到 `MAIN_MENU`
- `MAIN_MENU` 只能切换到 `LOADING`
- `LOADING` 只能切换到 `IN_GAME`（可从 `MAIN_MENU` 或 `IN_GAME` 进入）
- `IN_GAME` 可切换到 `PAUSE`、`LOADING`、`MAIN_MENU`
- `PAUSE` 只能切换回 `IN_GAME`

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `current_state` | `StringName` | `STATE_BOOT` | 当前流程状态 |
| `previous_state` | `StringName` | `STATE_BOOT` | 上一个流程状态，切换时自动更新 |
| `current_payload` | `Dictionary` | `{}` | 当前状态携带的上下文数据 |

## 公共方法

### 生命周期

---

#### configure(p_event_bus: GF_EventBus) -> GF_OperationResult

注入 `GF_EventBus` 实例，用于发布状态变化事件。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_event_bus | GF_EventBus | 事件总线实例 |

**返回值：** `GF_OperationResult`。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| `ERR_BAD_REQUEST` (400) | `p_event_bus` 为 `null` |

**示例：**

```gdscript
var app_flow := GF_AppFlow.new()
app_flow.module_name = "AppFlow"
app_flow.init_module()

var event_bus := GF_EventBus.new()
var result := app_flow.configure(event_bus)
if result.is_fail():
    printerr("配置失败: ", result.error.message)
```

---

### 状态切换

---

#### transition_to(p_target: StringName, p_payload: Dictionary = {}) -> GF_OperationResult

切换到指定状态。同状态切换（`p_target == current_state`）直接返回 OK 但不发布事件。无效状态或不允许的转换返回失败。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_target | StringName | 目标状态（必须已注册的状态常量或 `register_state()` 添加的状态） |
| p_payload | Dictionary | 可选，携带过渡上下文数据（如 `{"slot_id": "save_01"}`） |

**返回值：** `GF_OperationResult`。成功时 `previous_state` 和 `current_state` 已更新，`current_payload` 已设置为 `p_payload`。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| `ERR_BAD_REQUEST` (400) | `p_target` 未注册（不在 `_transitions` 中） |
| `ERR_PRECONDITION` (428) | 从 `current_state` 到 `p_target` 的转换不允许 |

**副作用：**

- 成功时发布 `"flow_state_changed"` 事件，事件数据为 `{"from": previous_state, "to": current_state, "payload": current_payload}`

**示例：**

```gdscript
# 切换到加载状态，携带存档槽位信息
var result := app_flow.transition_to(GF_AppFlow.STATE_LOADING, {"slot_id": "save_01"})
if result.is_fail():
    _log.error("AppFlow", "状态切换失败: %s" % result.error.message)
    return

# 同状态切换，直接返回 OK，不发布事件
app_flow.transition_to(GF_AppFlow.STATE_IN_GAME)  # 当前已是 IN_GAME
```

---

#### register_state(p_state: StringName, p_valid_from: Array[StringName], p_valid_to: Array[StringName]) -> void

动态注册新的流程状态。Mod 或 Game 层可通过此方法扩展框架预设的状态集。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_state | StringName | 新状态名称 |
| p_valid_from | Array[StringName] | 允许从哪些状态切换到新状态 |
| p_valid_to | Array[StringName] | 允许从新状态切换到哪些状态 |

**示例：**

```gdscript
# Mod 注册一个"设置"状态
app_flow.register_state(
    &"settings",
    [GF_AppFlow.STATE_MAIN_MENU, GF_AppFlow.STATE_IN_GAME],
    [GF_AppFlow.STATE_MAIN_MENU, GF_AppFlow.STATE_IN_GAME]
)
```

---

### 状态查询

---

#### get_current_payload() -> Dictionary

获取当前状态携带的 payload 数据。

**返回值：** `Dictionary`，当前 `current_payload` 的引用。

---

#### get_state() -> StringName

获取当前状态。

**返回值：** `StringName`，当前 `current_state` 的值。

---

#### is_in_state(p_state: StringName) -> bool

查询是否在指定状态。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_state | StringName | 要检查的状态 |

**返回值：** `bool`，当前状态等于 `p_state` 时为 `true`。

---

#### get_previous_state() -> StringName

获取上一次的状态。

**返回值：** `StringName`，`previous_state` 的值。

---

### 便捷方法

---

#### to_main_menu() -> GF_OperationResult

切换到 `STATE_MAIN_MENU`。等同于 `transition_to(STATE_MAIN_MENU)`。

**返回值：** `GF_OperationResult`。

---

#### to_loading() -> GF_OperationResult

切换到 `STATE_LOADING`。等同于 `transition_to(STATE_LOADING)`。

**返回值：** `GF_OperationResult`。

---

#### to_in_game() -> GF_OperationResult

切换到 `STATE_IN_GAME`。等同于 `transition_to(STATE_IN_GAME)`。

**返回值：** `GF_OperationResult`。

---

#### to_pause() -> GF_OperationResult

切换到 `STATE_PAUSE`。等同于 `transition_to(STATE_PAUSE)`。

**返回值：** `GF_OperationResult`。

---

#### resume_from_pause() -> GF_OperationResult

从暂停状态恢复到 `STATE_IN_GAME`。仅在当前状态为 `STATE_PAUSE` 时有效。

**返回值：** `GF_OperationResult`。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| `ERR_PRECONDITION` (428) | 当前状态不是 `STATE_PAUSE` |

---

## 事件

### flow_state_changed

状态切换成功时由 `transition_to()` 自动发布。事件数据格式：

```gdscript
{
    "from": StringName,    # 旧状态
    "to": StringName,      # 新状态
    "payload": Dictionary  # 携带的上下文数据
}
```

监听示例：

```gdscript
event_bus.subscribe("flow_state_changed", _on_flow_changed)

func _on_flow_changed(p_data: Dictionary) -> void:
    var from_state: StringName = p_data["from"]
    var to_state: StringName = p_data["to"]
    var payload: Dictionary = p_data["payload"]

    if to_state == GF_AppFlow.STATE_IN_GAME:
        _start_gameplay(payload)
    elif to_state == GF_AppFlow.STATE_PAUSE:
        _pause_gameplay()
```

## See Also

- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) -- 模块生命周期基类
- [GF_EventBus](../event/gf_event_bus.md) -- 事件总线，承载 `flow_state_changed` 事件
- [GF_GameServices](../core/gf_game_services.md) -- 服务聚合对象，通过 `GameServices.app_flow` 访问
- [GF_SceneFactory](../engine/gf_scene_factory.md) -- 场景工厂，场景切换由 Game 层通过 SceneFactory 实现
