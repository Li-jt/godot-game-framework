# GF_GameplayContext

> 适用版本: 0.3.0 | 继承: GF_GameplayContext -> RefCounted

## 概述

游戏玩法子系统可用的窄上下文。World / Command / Simulation 通过此对象获取服务，避免直接访问 `GF_GameServices` 拿到不该拿的服务（如 UI 服务）。

由 `GF_GameServices.create_gameplay_context()` 构造，或由 `GF_ServiceInstallerImpl` 在启动流程中构建。

## 属性

| 属性 | 类型 | 描述 |
|------|------|------|
| `log` | `GF_LogService` | 日志服务 |
| `event_bus` | `GF_EventBus` | 事件总线 |
| `app_flow` | `GF_AppFlow` | 应用流程状态机 |
| `scene_host` | `GF_SceneHost` | 场景宿主 |
| `input` | `GF_InputService` | 输入服务 |
| `config` | `GF_AppConfig` | 应用运行配置 |
| `threading` | `Variant` | 线程服务（可选） |

## 使用示例

```gdscript
# 在 GameBootstrap 中创建上下文
var services: GF_GameServices = app.get_services()
var gameplay_ctx := services.create_gameplay_context()

# 传给游戏世界
var world := GameWorld.new()
world.init(gameplay_ctx)
```

## See Also

- [GF_UiContext](./gf_ui_context.md) -- UI 子系统窄上下文
- [GF_SaveContext](./gf_save_context.md) -- 存档子系统窄上下文
- [GF_GameServices](./gf_game_services.md) -- 服务聚合对象
