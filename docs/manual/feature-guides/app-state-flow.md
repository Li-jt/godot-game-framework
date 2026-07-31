# 应用状态机

## 场景描述

游戏有明确的顶层状态流转：启动 → 主菜单 → 加载中 → 游戏中 ⇄ 暂停。各模块不应自行判断"当前在哪个界面"，而应通过统一的状态机来驱动场景切换、UI 管理和输入上下文变化。

本章覆盖：5 种内置状态、状态切换、动态注册状态、转换守卫、事件发布、完整的游戏主循环示例。

---

## 最小示例

```gdscript
# 配置
app_flow.configure(event_bus)

# 状态切换
app_flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)
app_flow.transition_to(GF_AppFlow.STATE_LOADING, {"target": "overworld"})
app_flow.transition_to(GF_AppFlow.STATE_IN_GAME)

# 便捷方法
app_flow.to_main_menu()
app_flow.to_loading()
app_flow.to_in_game()
app_flow.to_pause()
app_flow.resume_from_pause()

# 查询
var current := app_flow.get_state()
var previous := app_flow.get_previous_state()
if app_flow.is_in_state(GF_AppFlow.STATE_PAUSE):
    pass
```

---

## 逐步解释

### 第一步：5 种内置状态

```
BOOT → MAIN_MENU → LOADING → IN_GAME ⇄ PAUSE
         ↑                        ↓
         └────────────────────────┘
```

| 状态 | StringName 常量 | 说明 |
|------|----------------|------|
| BOOT | `&"boot"` | 初始状态，引导完成后立即离开 |
| MAIN_MENU | `&"main_menu"` | 主菜单界面 |
| LOADING | `&"loading"` | 加载中（场景切换、存档加载） |
| IN_GAME | `&"in_game"` | 游戏中 |
| PAUSE | `&"pause"` | 暂停（菜单打开时） |

### 第二步：配置

```gdscript
var result := app_flow.configure(event_bus)
if result.is_fail():
    _log.error("Flow", "配置失败: %s" % result.error.message)
```

`configure` 接收 `GF_EventBus` 实例。每次成功状态切换时，`GF_AppFlow` 会通过 EventBus 发布 `"flow_state_changed"` 事件：

```gdscript
# 监听状态变化
event_bus.subscribe("flow_state_changed", func(payload: Dictionary):
    var from: StringName = payload["from"]
    var to: StringName = payload["to"]
    var data: Dictionary = payload["payload"]
    _log.info("Flow", "状态切换: %s → %s" % [from, to])
)
```

### 第三步：状态切换

```gdscript
# 基本切换
var result := app_flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)
if result.is_fail():
    _log.error("Flow", "切换失败: %s" % result.error.message)

# 带 payload 的切换
var result := app_flow.transition_to(GF_AppFlow.STATE_LOADING, {
    "slot_id": 3,
    "world_path": "res://content/worlds/overworld.tscn",
})
```

`transition_to` 检查三项条件：

1. **目标状态必须已注册**：如果 `_transitions` 中没有该状态的转换规则，返回 `ERR_BAD_REQUEST`
2. **当前状态必须在 `valid_from` 列表中**：例如 `IN_GAME` 的 `from` 是 `[LOADING, PAUSE]`，如果从 `MAIN_MENU` 直接切到 `IN_GAME`，返回 `ERR_PRECONDITION`
3. **特殊情况**：`from` 列表第一个元素为 `"*"` 时表示可从任意状态切换

切换成功时：
1. 保存 `previous_state = current_state`
2. 更新 `current_state = p_target`
3. 保存 `current_payload = p_payload`
4. 通过 EventBus 发布 `"flow_state_changed"` 事件

### 第四步：内置转换规则

```gdscript
var _transitions: Dictionary = {
    STATE_BOOT:       { "from": ["*"],           "to": [STATE_MAIN_MENU] },
    STATE_MAIN_MENU:  { "from": [STATE_BOOT],     "to": [STATE_LOADING] },
    STATE_LOADING:    { "from": [STATE_MAIN_MENU, STATE_IN_GAME], "to": [STATE_IN_GAME] },
    STATE_IN_GAME:    { "from": [STATE_LOADING, STATE_PAUSE], "to": [STATE_PAUSE, STATE_LOADING, STATE_MAIN_MENU] },
    STATE_PAUSE:      { "from": [STATE_IN_GAME],  "to": [STATE_IN_GAME] },
}
```

理解这个转换表：
- **BOOT** → 只能到 MAIN_MENU（`from: ["*"]` 表示可从任意状态来）
- **MAIN_MENU** → 只能到 LOADING
- **LOADING** → 只能到 IN_GAME
- **IN_GAME** → 可到 PAUSE、LOADING（换地图）、MAIN_MENU（退出）
- **PAUSE** → 只能回 IN_GAME（恢复）

### 第五步：查询方法

```gdscript
# 当前状态
var state := app_flow.get_state()

# 上一状态
var prev := app_flow.get_previous_state()

# 是否在指定状态
if app_flow.is_in_state(GF_AppFlow.STATE_IN_GAME):
    _process_gameplay()

# 获取当前 payload
var payload := app_flow.get_current_payload()
var target_world := payload.get("world_path", "")
```

### 第六步：动态注册状态（Mod 支持）

```gdscript
# Mod 注册自定义状态
var valid_from: Array[StringName] = [GF_AppFlow.STATE_IN_GAME]
var valid_to: Array[StringName] = [GF_AppFlow.STATE_IN_GAME]

app_flow.register_state(&"photo_mode", valid_from, valid_to)

# 之后可以切换到该状态
app_flow.transition_to(&"photo_mode", {"camera_params": {...}})
```

### 第七步：便捷方法

```gdscript
app_flow.to_main_menu()       # → MAIN_MENU
app_flow.to_loading()         # → LOADING
app_flow.to_in_game()         # → IN_GAME
app_flow.to_pause()           # → PAUSE
app_flow.resume_from_pause()  # PAUSE → IN_GAME（只有当前在 PAUSE 时才有效）
```

---

## 完整示例：游戏主循环状态管理

```gdscript
# ---- game_bootstrap.gd ----

class_name GameBootstrap
extends Node


func _ready() -> void:
    # 配置 AppFlow
    var result := app_flow.configure(event_bus)
    if result.is_fail():
        _log.error("Bootstrap", "AppFlow 配置失败")
        return

    # 监听状态变化
    event_bus.subscribe("flow_state_changed", _on_flow_changed)

    # 启动：BOOT → MAIN_MENU
    app_flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)


func _on_flow_changed(payload: Dictionary) -> void:
    var to: StringName = payload["to"]
    _log.info("Flow", "进入状态: %s" % to)

    match to:
        GF_AppFlow.STATE_MAIN_MENU:
            _enter_main_menu()

        GF_AppFlow.STATE_LOADING:
            _enter_loading(payload.get("payload", {}))

        GF_AppFlow.STATE_IN_GAME:
            _enter_game()

        GF_AppFlow.STATE_PAUSE:
            _enter_pause()


func _enter_main_menu() -> void:
    # 卸载世界
    scene_host.unload_world()
    # 关闭游戏 UI
    ui_service.clear_all_ui()
    # 打开主菜单
    ui_service.open("main_menu")
    # 停止游戏 BGM
    audio_service.stop_bus("BGM")


func _enter_loading(p_data: Dictionary) -> void:
    # 打开加载画面（MANAGED_BY_FLOW 面板）
    ui_service.open("loading", {"message": "加载中..."})

    # 异步加载世界
    var world_path := p_data.get("world_path", "")
    var result := scene_host.load_world(world_path)

    if result.is_fail():
        _log.error("Flow", "加载世界失败: %s" % result.error.message)
        app_flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)
        return

    # 加载完成 → 进入游戏
    app_flow.transition_to(GF_AppFlow.STATE_IN_GAME, p_data)


func _enter_game() -> void:
    # 关闭加载画面
    ui_service.force_close("loading")
    # 显示 HUD
    ui_service.show_hud()
    # 播放 BGM
    audio_service.play_cue("bgm.town")


func _enter_pause() -> void:
    # 打开暂停菜单
    ui_service.open("pause_menu")
    # 暂停所有游戏逻辑（通过 Scheduler 暂停）
    # scheduler.set_paused(true)


func _exit_pause() -> void:
    ui_service.close("pause_menu")
    # scheduler.set_paused(false)


# ---- 玩家操作触发状态切换 ----

func _on_new_game_pressed() -> void:
    var result := app_flow.transition_to(GF_AppFlow.STATE_LOADING, {
        "world_path": "res://content/worlds/tutorial.tscn",
        "new_game": true,
    })
    if result.is_fail():
        _log.error("Flow", "切换失败: %s" % result.error.message)


func _on_continue_pressed(slot_id: int) -> void:
    var load_result := save_service.load_and_restore(slot_id)
    if load_result.is_fail():
        _log.error("Flow", "加载存档失败")
        return

    var result := app_flow.transition_to(GF_AppFlow.STATE_LOADING, {
        "world_path": "res://content/worlds/overworld.tscn",
        "slot_id": slot_id,
    })
    if result.is_fail():
        _log.error("Flow", "切换失败: %s" % result.error.message)


func _on_pause_pressed() -> void:
    var result := app_flow.to_pause()
    if result.is_fail():
        _log.warning("Flow", "无法暂停: %s" % result.error.message)


func _on_resume_pressed() -> void:
    var result := app_flow.resume_from_pause()
    if result.is_fail():
        _log.warning("Flow", "无法恢复: %s" % result.error.message)


func _on_return_to_menu() -> void:
    var result := app_flow.transition_to(GF_AppFlow.STATE_MAIN_MENU)
    if result.is_fail():
        _log.error("Flow", "返回菜单失败: %s" % result.error.message)


# ---- 地图切换（游戏中 → 加载 → 游戏中） ----

func _on_portal_entered(target_world: String, entrance: String) -> void:
    var result := app_flow.transition_to(GF_AppFlow.STATE_LOADING, {
        "world_path": "res://content/worlds/%s.tscn" % target_world,
        "entrance": entrance,
    })
```

---

## 常见变体

### 变体 1：Mod 注册自定义状态

```gdscript
# 照相模式 Mod
func _register_photo_mode() -> void:
    app_flow.register_state(&"photo_mode",
        [GF_AppFlow.STATE_IN_GAME],
        [GF_AppFlow.STATE_IN_GAME]
    )

    # 监听状态变化
    event_bus.subscribe("flow_state_changed", func(payload: Dictionary):
        if payload["to"] == &"photo_mode":
            _enter_photo_mode()
        elif payload["from"] == &"photo_mode":
            _exit_photo_mode()
    )
```

### 变体 2：转换守卫（在 transition_to 之前做额外检查）

```gdscript
func safe_transition_to(p_target: StringName, p_payload: Dictionary = {}) -> GF_OperationResult:
    # 额外检查：正在保存时不允许切换
    if _is_saving:
        return GF_OperationResult.fail(
            GF_OperationResult.ERR_PRECONDITION,
            "存档进行中，无法切换状态",
            module_name
        )
    return app_flow.transition_to(p_target, p_payload)
```

### 变体 3：扩展内置状态

```gdscript
# 可以添加更多状态
app_flow.register_state(&"multiplayer_lobby",
    [GF_AppFlow.STATE_MAIN_MENU, GF_AppFlow.STATE_IN_GAME],
    [GF_AppFlow.STATE_LOADING, GF_AppFlow.STATE_MAIN_MENU]
)

app_flow.register_state(&"credits",
    [GF_AppFlow.STATE_MAIN_MENU],
    [GF_AppFlow.STATE_MAIN_MENU]
)
```

---

## 错误码

| 方法 | 可能的错误码 | 说明 |
|------|------------|------|
| `configure(event_bus)` | `ERR_BAD_REQUEST` | event_bus 为 null |
| `transition_to(target, payload)` | `ERR_BAD_REQUEST` | 目标状态未注册（不在 `_transitions` 中） |
| | `ERR_PRECONDITION` | 当前状态不在目标状态的 `valid_from` 列表中 |
| `resume_from_pause()` | `ERR_PRECONDITION` | 当前不在 PAUSE 状态 |

同状态切换（`target == current_state`）返回 `GF_OperationResult.ok()`，不报错，不发布事件。

---

## See Also

- [场景切换](./scene-switching.md) -- 状态驱动的世界切换
- [创建和管理 UI 面板](./create-ui-panels.md) -- MANAGED_BY_FLOW 面板
- [模块间事件通信](./event-communication.md) -- `flow_state_changed` 事件
- [处理玩家输入](./handle-player-input.md) -- 不同状态下的输入上下文
