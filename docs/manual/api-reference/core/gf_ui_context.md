# GF_UiContext

> 适用版本: 0.3.0 | 继承: GF_UiContext -> RefCounted

## 概述

UI 子系统可用的窄上下文。UI 面板通过 `panel.ctx` 获取所有所需服务，避免直接依赖 `GF_GameServices` 获取不相关的服务（如 ECS World）。

由框架层（`GF_ServiceInstallerImpl` 或 `GF_GameServices.create_ui_context()`）构建并注入。

## 属性

| 属性 | 类型 | 描述 |
|------|------|------|
| `log` | `GF_LogService` | 日志服务 |
| `ui` | `GF_UIService` | UI 管理服务 |
| `input` | `GF_InputService` | 输入服务 |
| `event_bus` | `GF_EventBus` | 事件总线 |
| `scene_host` | `GF_SceneHost` | 场景宿主 |
| `loc` | `GF_LocalizationService` | 本地化服务 |
| `save_service` | `GF_SaveService` | 存档服务 |
| `config_service` | `GF_ConfigService` | 游戏配置定义服务 |
| `config` | `GF_AppConfig` | 应用运行配置 |
| `app_flow` | `GF_AppFlow` | 应用流程状态机 |
| `debug` | `GF_DebugService` | 调试服务 |
| `audio` | `GF_AudioService` | 音频服务 |

## 使用示例

```gdscript
# 在面板中使用上下文
extends Control
class_name MyInventoryPanel

var ctx: GF_UiContext = null

func _ready() -> void:
    ctx.log.info("Inventory", "面板已打开")

func _on_close_pressed() -> void:
    ctx.ui.close_panel(self)
```

## See Also

- [GF_GameplayContext](./gf_gameplay_context.md) -- 玩法子系统窄上下文
- [GF_SaveContext](./gf_save_context.md) -- 存档子系统窄上下文
- [GF_GameServices](./gf_game_services.md) -- 服务聚合对象
