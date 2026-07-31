# GF_SceneHost

> 适用版本: 0.3.0 | 继承: GF_SceneHost -> Node

## 概述

场景宿主。管理持久挂载点（世界根节点、相机、UI 层级），协调场景切换与 UI 面板加载。是游戏世界的场景树根容器，负责世界场景的加载/卸载/切换，以及 UI 面板的分层挂载。

适用场景：GameBootstrap 在启动时实例化 GF_SceneHost，将其作为游戏场景树的根节点。不应在 Game 层直接操作挂载点的子节点，应通过 GF_SceneHost 的加载 API 进行。

## 场景树结构

```
Main (GameBootstrap)
└── GF_SceneHost
    ├── WorldMount  (Node2D)     — 游戏世界挂载点，受 GameCamera 影响
    ├── GameCamera   (Camera2D)  — 游戏世界相机（用户可拖动/缩放）
    └── UiCanvas     (CanvasLayer) — UI 层（独立于游戏相机，固定屏幕渲染）
        └── UIRoot   (Control)
            ├── HudLayer
            ├── ScreenLayer
            ├── PopupLayer
            ├── TooltipLayer
            ├── SystemLayer
            └── DebugLayer
```

节点结构定义在 `scene_host.tscn` 中，可在 Godot 编辑器中直接查看和调整。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `world_root` | `Node2D` | — | 游戏世界挂载点，受 GameCamera 影响 |
| `game_camera` | `Camera2D` | — | 游戏世界相机，`_ready()` 时自动启用 |
| `ui_canvas` | `CanvasLayer` | — | UI 画布层，独立于游戏相机渲染 |
| `ui_root` | `Control` | — | UI 根控件，所有 UI 层的父节点 |
| `hud_layer` | `Control` | — | HUD 层（始终可见的游戏界面） |
| `screen_layer` | `Control` | — | 全屏界面层（主菜单、设置等） |
| `popup_layer` | `Control` | — | 弹窗层（对话框、确认框等） |
| `tooltip_layer` | `Control` | — | 提示层（悬浮提示、帮助文本等） |
| `system_layer` | `Control` | — | 系统层（Loading、黑幕过渡等） |
| `debug_layer` | `Control` | — | 调试层（调试面板、FPS 显示等） |

## 公共方法

### configure(p_scene_factory: GF_SceneFactory, p_log: GF_LogService) -> GF_OperationResult

注入场景工厂和日志服务的依赖。应在 `_ready()` 之前调用。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_scene_factory` | `GF_SceneFactory` | 场景工厂，用于实例化场景 |
| `p_log` | `GF_LogService` | 日志服务 |

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_BAD_REQUEST` | `p_scene_factory` 或 `p_log` 为 null |

**示例:**

```gdscript
var result := scene_host.configure(scene_factory, log_service)
if result.is_fail():
    push_error("SceneHost 配置失败: %s" % result.error.message)
```

---

### is_runtime_ready() -> bool

检查 SceneHost 是否已完成 `_ready()` 初始化，即所有挂载点节点引用是否就绪。

---

### set_world_context(p_ctx: GF_GameServices) -> void

注入世界上下文。Game 层在启动后调用此方法注入 GF_GameServices，后续所有通过 `replace_world()` 加载的世界场景将自动获得此上下文的引用。

**示例:**

```gdscript
scene_host.set_world_context(game_services)
```

---

### get_world_root() -> Node2D

获取世界挂载点节点（WorldMount）。所有世界场景作为此节点的子节点加载。

---

### get_camera() -> Camera2D

获取游戏世界相机节点（GameCamera）。

---

### get_ui_root() -> Control

获取 UI 根控件节点（UIRoot）。

---

### get_ui_canvas() -> CanvasLayer

获取 UI 画布层节点（UiCanvas）。此 CanvasLayer 独立于游戏相机，适合放置固定屏幕位置的 UI 元素。

---

### get_ui_layer(p_kind: StringName) -> Control

根据 UI 面板类型路由到对应的 UI 层节点。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_kind` | `StringName` | UI 面板类型，对应 `GF_UIPanelDef.KIND_*` 常量 |

**返回值:** 对应的 UI 层 Control 节点。未知类型默认返回 `screen_layer`。

**路由规则:**

| p_kind 值 | 返回节点 |
|-----------|---------|
| `KIND_HUD` | `hud_layer` |
| `KIND_SCREEN` | `screen_layer` |
| `KIND_POPUP` | `popup_layer` |
| `KIND_TOOLTIP` | `tooltip_layer` |
| `KIND_SYSTEM` | `system_layer` |
| `KIND_DEBUG` | `debug_layer` |
| 其他 | `screen_layer`（默认） |

---

### load_world(p_scene_path: String, p_data: Dictionary = {}) -> GF_OperationResult

加载世界场景到世界挂载点。先清空 world_root 的所有现有子节点，再通过 GF_SceneFactory 实例化新场景并添加为子节点。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_scene_path` | `String` | 场景文件路径 |
| `p_data` | `Dictionary` | 传递给场景工厂的初始化数据 |

**返回值:** 成功时 `data` 字段包含实例化后的 Node 引用。

**示例:**

```gdscript
var result := scene_host.load_world("res://scenes/worlds/main_world.tscn")
if result.is_fail():
    _log.error("Scene", "加载世界失败: %s" % result.error.message)
```

---

### load_ui_panel(p_kind: StringName, p_scene_path: String, p_data: Dictionary = {}) -> GF_OperationResult

加载 UI 面板到对应的 UI 层。根据 `p_kind` 自动路由到正确的 UI 层子节点下。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_kind` | `StringName` | 面板类型，决定挂载到哪个 UI 层 |
| `p_scene_path` | `String` | 场景文件路径 |
| `p_data` | `Dictionary` | 传递给场景工厂的初始化数据 |

**返回值:** 成功时 `data` 字段包含实例化后的 Node 引用。

**示例:**

```gdscript
var result := scene_host.load_ui_panel(GF_UIPanelDef.KIND_POPUP, "res://scenes/ui/confirm_dialog.tscn")
```

---

### unload_world() -> void

卸载当前世界场景。对所有 world_root 的子节点调用 `_on_world_exit()`，然后 `queue_free()` 清空。卸载后通过日志记录。

---

### replace_world(p_scene_path: String, p_data: Dictionary = {}) -> GF_OperationResult

安全替换世界场景。执行完整的切换流程：

1. 通过 GF_SceneFactory 实例化新场景
2. 若新场景根节点是 GF_WorldRoot 且已设置 `_world_context`，则注入 ctx 并调用 `_on_world_setup()`
3. 调用 SaveService 的 `on_world_switch()` 处理旧世界的 ISaveable 注销和新世界的 ISaveable 收集
4. 卸载旧世界（`unload_world()`）
5. 挂载新世界到 world_root

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_scene_path` | `String` | 新世界场景文件路径 |
| `p_data` | `Dictionary` | 传递给场景工厂的初始化数据 |

**返回值:** 成功时 `data` 字段包含新世界场景的根节点引用。

**示例:**

```gdscript
var result := scene_host.replace_world("res://scenes/worlds/dungeon_level.tscn", {"level_id": 3})
if result.is_fail():
    _log.error("Scene", "切换世界失败: %s" % result.error.message)
```

---

### clear_world() -> void

清空世界挂载点的所有子节点（`queue_free()`），不执行 `_on_world_exit()` 回调。用于快速重置世界。

---

### clear_layer(p_kind: StringName) -> void

清空指定 UI 层的所有子节点（`queue_free()`）。

---

# GF_WorldRoot

> 适用版本: 0.3.0 | 继承: GF_WorldRoot -> Node2D

## 概述

世界场景根节点基类。所有游戏世界场景的根节点必须继承此类。GF_SceneHost 在加载世界后自动注入 `ctx`（GF_GameServices），子类在 `_on_world_setup()` 中执行初始化逻辑。

适用场景：每个游戏世界场景（主世界、地牢、战斗场景等）的根节点继承 GF_WorldRoot。不应在非世界场景中使用。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `ctx` | `GF_GameServices` | `null` | 游戏服务上下文，由 GF_SceneHost 在加载世界后自动注入 |

## 虚方法（子类覆写）

### _on_world_setup() -> void

GF_SceneHost 注入 `ctx` 后立即调用。子类在此创建实体、初始化地图、注册系统等。

**示例:**

```gdscript
class_name MainWorldRoot
extends GF_WorldRoot

func _on_world_setup() -> void:
    ctx.log.info("World", "主世界初始化开始")
    # 创建 ECS 世界、生成实体等
    _spawn_landscape()
    _spawn_entities()
```

---

### _on_world_exit() -> void

世界退出时由 GF_SceneHost 调用。子类在此清理订阅、注销 tick 回调、释放资源。

**示例:**

```gdscript
func _on_world_exit() -> void:
    ctx.scheduler.unregister("main_world_tick")
    ctx.log.info("World", "主世界清理完成")
```

## See Also

- [GF_GameServices](../core/gf_game_services.md) -- 游戏服务聚合对象
- [GF_Scheduler](./gf_scheduler.md) -- 统一 Tick 驱动器
