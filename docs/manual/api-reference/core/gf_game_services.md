# GF_GameServices

> 适用版本: 0.3.0 | 继承: GF_GameServices -> RefCounted

## 概述

Game 层可用的服务聚合对象，仅用于显式依赖注入。由 Application 层在启动装配完成后构造，传入 GameBootstrap。

设计目标：替代 Game 层直接访问 `GF_ServiceRegistry`，让 Game 子系统依赖在类型层面显式可见，保持 Game 对 Application 装配细节零感知。

## 属性（22 个服务字段）

| 属性 | 类型 | 描述 |
|------|------|------|
| `config` | `GF_AppConfig` | Game 层可读取的最终运行配置 |
| `log` | `GF_LogService` | 统一日志服务 |
| `scene_factory` | `GF_SceneFactory` | 场景工厂，统一场景实例化入口 |
| `input` | `GF_InputService` | 输入服务（Game 语义动作查询） |
| `ui` | `GF_UIService` | UI 服务（面板打开/关闭/缓存） |
| `audio` | `GF_AudioService` | 音频服务（高层播放入口） |
| `file_system` | `GF_FileSystemService` | 统一文件系统服务（文本/JSON 读写、目录操作） |
| `resource` | `GF_ResourceService` | 资源服务（高层资源访问入口） |
| `event_bus` | `GF_EventBus` | 事件总线（跨模块事件通知） |
| `save_service` | `GF_SaveService` | 存档服务（保存/读取/槽位管理） |
| `config_service` | `GF_ConfigService` | 配置服务（ItemDef / BuildingDef 等游戏内容定义查询） |
| `debug` | `GF_DebugService` | 调试服务（运行时统计 / 面板注册 / 命令追踪） |
| `loc` | `GF_LocalizationService` | 本地化服务（多语言文本） |
| `app_flow` | `GF_AppFlow` | 应用流程服务（MainMenu/InGame 等流程切换） |
| `scheduler` | `GF_Scheduler` | Tick 调度器（Game 层注册逐帧回调） |
| `runtime` | `GF_RuntimeService` | 运行时模式服务（Local/Remote/Hybrid 命令与存档策略入口） |
| `threading` | `GF_ThreadingService` | 线程任务服务（后台计算任务提交与主线程回收） |
| `ecs_world` | `GF_EcsWorld` | ECS 世界（实体管理与组件存储） |
| `ecs_scheduler` | `GF_EcsScheduler` | ECS 调度器（系统分组与 tick 驱动） |
| `content_def` | `GF_ContentDefRegistry` | 内容定义注册表（游戏物品/建筑/配方等 DataService 统一注册入口） |
| `def_id` | `GF_DefIdRegistry` | 内容定义 ID 注册表（Economy/Resource/Building/WorkJob 等 ID 统一注册和查询） |

## 公共方法

### create_gameplay_context() -> GF_GameplayContext

创建游戏玩法子系统可用的窄上下文。包含：log、event_bus、app_flow、scene_factory、input、config。

```gdscript
var ctx := services.create_gameplay_context()
var world := GameWorld.new()
world.init(ctx)
```

### create_ui_context() -> GF_UiContext

创建 UI 子系统可用的窄上下文。包含：log、ui、input、event_bus、scene_factory、loc、save_service、config_service、config、app_flow、debug、audio。

```gdscript
var ui_ctx := services.create_ui_context()
var panel := MyInventoryPanel.new()
panel.ctx = ui_ctx
```

### create_save_context() -> GF_SaveContext

创建存档子系统可用的窄上下文。包含：log、save_service、config_service、config。

```gdscript
var save_ctx := services.create_save_context()
var migrator := MySaveMigrator.new()
migrator.ctx = save_ctx
```

## See Also

- [GF_GameplayContext](./gf_gameplay_context.md) -- 玩法子系统窄上下文
- [GF_UiContext](./gf_ui_context.md) -- UI 子系统窄上下文
- [GF_SaveContext](./gf_save_context.md) -- 存档子系统窄上下文
