# 全部 class_name 速查表

本表列出 godot-game-framework 框架层全部约 144 个 `class_name`，按模块分类。

> 注意：Gut* 类和 MCP* 类为测试工具和 MCP 集成，不属于框架 API；Fake* 类仅在 test 分支存在。

## Application 层 (3)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_AppBootstrap` | application | Node | 应用启动基类，Installer 模式装配服务，提供 10 个生命周期 Hook |
| `GF_ServiceRegistry` | application | RefCounted | 服务注册中心，支持优先级覆盖和按 owner 批量注销 |
| `GF_ServiceInstaller` | application | RefCounted | 服务安装器接口（基类） |

## Core 层 (12)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_ModuleLifecycle` | core | RefCounted | 所有服务的生命周期状态机基类 |
| `GF_OperationResult` | core | RefCounted | 统一操作结果类型，HTTP 风格状态码 |
| `GF_ErrorInfo` | core | RefCounted | 错误详情（code/message/source_module/context/cause） |
| `GF_CoreLifecycleState` | core | RefCounted | 模块生命周期状态枚举 |
| `GF_GameServices` | core | RefCounted | Game 层可直接使用的所有服务聚合对象 |
| `GF_GameplayContext` | core | RefCounted | Gameplay 子系统窄上下文 |
| `GF_UiContext` | core | RefCounted | UI 子系统窄上下文 |
| `GF_SaveContext` | core | RefCounted | 存档子系统窄上下文 |
| `GF_ContentDefRegistry` | core | RefCounted | 游戏内容定义注册表（物品/建筑/配方等 DataService 统一入口） |
| `GF_DefIdRegistry` | core | RefCounted | 内容定义 ID 注册表（Economy/Resource/Building 等 ID 查询） |
| `GF_DefJsonLoader` | core | RefCounted | JSON 定义加载工具 |
| `GF_ObjectPool` | core | RefCounted | 通用对象池（RefCounted 对象复用） |

## ECS 层 (27)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_EcsWorld` | ecs | RefCounted | ECS 世界，实体管理和组件存储 |
| `GF_EcsEntityId` | ecs | RefCounted | 实体 ID 工具（生成/有效性校验） |
| `GF_EcsQuery` | ecs | RefCounted | ECS 查询构建器（with/without/optional） |
| `GF_EcsQueryPlan` | ecs | RefCounted | ECS 查询执行计划 |
| `GF_EcsQueryResult` | ecs | RefCounted | 查询结果集 |
| `GF_EcsQueryRow` | ecs | RefCounted | 查询结果单行访问器 |
| `GF_EcsCommandBuffer` | ecs | RefCounted | 命令缓冲区，延迟批量写入 |
| `GF_EcsCommand` | ecs | RefCounted | 单个 ECS 命令（spawn/despawn/set/remove） |
| `GF_EcsSystem` | ecs | RefCounted | ECS System 基类 |
| `GF_EcsSystemDescriptor` | ecs | RefCounted | System 元数据描述符 |
| `GF_EcsSystemGroup` | ecs | RefCounted | System 分组枚举 |
| `GF_EcsScheduler` | ecs | RefCounted | ECS System 调度器（分组/依赖/顺序驱动） |
| `GF_EcsSchedulerBridge` | ecs | RefCounted | Scheduler 到 EcsScheduler 的桥接 |
| `GF_EcsComponentBase` | ecs | RefCounted | ECS 组件基类（带序列化支持） |
| `GF_EcsComponentFactory` | ecs | RefCounted | 组件工厂（从序列化数据重建组件） |
| `GF_EcsComponentTypeRegistry` | ecs | RefCounted | 组件类型注册表 |
| `GF_EcsStorageIndex` | ecs | RefCounted | 存储索引（type_id → storage 映射） |
| `GF_EcsSparseSetStorage` | ecs | RefCounted | Sparse Set 存储实现 |
| `GF_EcsArchetypeStorage` | ecs | RefCounted | Archetype 存储实现（高频查询优化） |
| `GF_EcsWorldSnapshot` | ecs/snapshot | RefCounted | ECS 世界可序列化快照 |
| `GF_EcsSnapshotBuilder` | ecs/snapshot | RefCounted | 从 World 构建快照 |
| `GF_EcsSnapshotApplier` | ecs/snapshot | RefCounted | 将快照恢复到 World |
| `GF_EcsSaveAdapter` | ecs | RefCounted | ECS 数据的 GF_ISaveable 适配器 |
| `GF_EcsSaveVersionMigrator` | ecs | RefCounted | ECS 存档版本迁移器 |
| `GF_EcsRuntimeBridge` | ecs | RefCounted | ECS 运行时调试桥接 |
| `GF_EcsInstaller` | ecs | Node | ECS 模块安装器 |

## ECS 接口 (6)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_IEcsWorld` | ecs | RefCounted | ECS World 接口 |
| `GF_IEcsStorage` | ecs | RefCounted | 组件存储接口 |
| `GF_IEcsStorageIndex` | ecs | RefCounted | 存储索引接口 |
| `GF_IEcsQuery` | ecs | RefCounted | 查询接口 |
| `GF_IEcsCommandBuffer` | ecs | RefCounted | 命令缓冲区接口 |
| `GF_IEcsScheduler` | ecs | RefCounted | ECS Scheduler 接口 |
| `GF_IEcsSystemGroup` | ecs | RefCounted | System 分组接口 |

## Engine 层 (13)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_SceneFactory` | engine | RefCounted | 场景工厂，统一场景实例化入口 |
| `GF_Scheduler` | engine | Node | Tick 调度器，按 TickGroup 驱动回调 |
| `GF_ThreadingService` | engine/threading | GF_ModuleLifecycle | 线程任务服务，优先级队列+取消+超时+统计 |
| `GF_ThreadJobOptions` | engine/threading | RefCounted | 线程任务配置（priority/timeout/retry/tag/callbacks） |
| `GF_ThreadJobToken` | engine/threading | RefCounted | 线程任务取消令牌 |
| `GF_ThreadJobHandle` | engine/threading | RefCounted | 线程任务句柄（查询和取消） |
| `GF_ThreadJobCallbacks` | engine/threading | RefCounted | 线程任务回调集合 |
| `GF_ThreadJobSummary` | engine/threading | RefCounted | 线程任务摘要快照 |
| `GF_ThreadJobState` | engine/threading | RefCounted | 线程任务状态枚举 |
| `GF_ThreadJobPriority` | engine/threading | RefCounted | 线程任务优先级枚举 |
| `GF_PathResolver` | engine | RefCounted | 路径解析器，标准化资源路径 |
| `GF_FileSystemService` | engine | GF_ModuleLifecycle | 文件系统服务，统一 FileAccess 操作 |
| `GF_AssetLoadingService` | engine | GF_ModuleLifecycle | 资源加载服务 |

## Engine 工具 (4)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_NodePool` | engine | RefCounted | Node 对象池 |
| `GF_RuntimeUtilities` | engine | RefCounted | 运行时工具函数集 |
| `GF_WorldRoot` | modules/world_root | Node | 世界根节点 |
| `GF_Pathfinder` | engine | RefCounted | A* 寻路算法 |
| `GF_ManhattanHeuristic` | engine | RefCounted | 曼哈顿启发函数 |

## Input 层 (13)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_InputService` | input | GF_ModuleLifecycle | 统一输入服务 |
| `GF_InputRouter` | input | Node | 输入路由 Node，采集原始事件 |
| `GF_ActionResolver` | input | RefCounted | 动作解析器，原始信号→动作状态 |
| `GF_InputPolicy` | input | RefCounted | 输入策略，上下文栈权限判定 |
| `GF_InputGestureEngine` | input | RefCounted | 手势识别引擎 |
| `GF_InputRebindService` | input | RefCounted | 按键重绑定服务 |
| `GF_InputContext` | input | RefCounted | 输入上下文（黑白名单动作控制） |
| `GF_InputActionDef` | input | RefCounted | 动作定义（ID + 默认绑定 + 手势配置） |
| `GF_InputActionState` | input | RefCounted | 动作实时状态（pressed/just_pressed/value） |
| `GF_InputBinding` | input | RefCounted | 单个按键绑定 |
| `GF_InputBindingConfig` | input | RefCounted | 按键绑定配置集合 |
| `GF_InputRawSignal` | input | RefCounted | 归一化输入信号 |
| `GF_DeviceNormalizer` | input | RefCounted | 设备归一化器，Godot InputEvent→RawSignal |
| `GF_InputGestureProfile` | input | RefCounted | 手势配置档案 |

## UI 层 (11)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_UIService` | ui | GF_ModuleLifecycle | UI 服务，面板管理 |
| `GF_UIPanel` | ui | Control | UI 面板基类 |
| `GF_UIPanelDef` | ui | RefCounted | 面板定义（名称/场景路径/关闭策略/输入阻挡模式/Canvas Layer） |
| `GF_UIDragManager` | ui | Node | 拖拽事件驱动 Node（L1 协议层核心） |
| `GF_UIDragHandler` | ui | RefCounted | 拖拽处理器接口（L1 协议层） |
| `GF_UIDragEvent` | ui | RefCounted | 拖拽事件数据 |
| `GF_UIDragSlot` | ui | Control | 拖拽槽位（L2 便利层） |
| `GF_UIDragGhost` | ui | Control | 拖拽跟随视觉 |
| `GF_UIDragExtensions` | ui | RefCounted | 拖拽扩展工具 |
| `GF_UIDropTarget` | ui | Control | 放置目标接收器 |
| `GF_InputAdapter` | input | Node | 输入适配器（连接 InputRouter 到场景树） |

## Save 层 (8)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_SaveService` | save | GF_ModuleLifecycle | 存档服务，槽位管理+版本迁移+ISaveable 收集 |
| `GF_SaveProvider` | save | RefCounted | 存档提供者接口（抽象） |
| `GF_LocalSaveProvider` | save | RefCounted | 本地文件存档提供者 |
| `GF_ISaveable` | save | RefCounted | 可存档模块接口基类 |
| `GF_SaveVersion` | save | RefCounted | 存档版本常量定义 |
| `GF_SaveVersionMigrator` | save | RefCounted | 存档版本迁移器基类 |
| `GF_SaveMeta` | save | RefCounted | 存档元数据（label/timestamp/save_version） |
| `GF_EntityRegistry` | save | RefCounted | 实体注册表（存档中实体 ID 管理） |

## Runtime 层 (8)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_RuntimeService` | runtime | GF_ModuleLifecycle | 运行时模式服务（Local/Remote/Hybrid 策略入口） |
| `GF_RuntimeMode` | runtime | RefCounted | 运行时模式枚举 |
| `GF_CommandBus` | runtime | RefCounted | 命令总线，命令处理器注册和分发 |
| `GF_ICommand` | runtime | RefCounted | 命令接口 |
| `GF_ICommandHandler` | runtime | RefCounted | 命令处理器接口 |
| `GF_CommandStrategy` | runtime | RefCounted | 命令执行策略抽象 |
| `GF_LocalCommandStrategy` | runtime | RefCounted | 本地命令执行策略 |
| `GF_SaveStrategy` | runtime | RefCounted | 存档策略抽象 |

## Event 层 (3)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_EventBus` | event | GF_ModuleLifecycle | 事件总线，支持 scope/once/pending_removes |
| `GF_EventDef` | event | RefCounted | 事件定义（结构化事件元数据） |
| `GF_EventToken` | event | RefCounted | 事件订阅令牌（用于取消订阅） |

## Flow 层 (1)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_AppFlow` | flow | GF_ModuleLifecycle | 应用流程状态机（BOOT→MAIN_MENU→LOADING→IN_GAME⇄PAUSE） |

## Audio 层 (5)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_AudioService` | audio | GF_ModuleLifecycle | 音频服务（高层 API） |
| `GF_AudioRuntime` | audio | RefCounted | 音频运行时（底层 AudioStreamPlayer 管理） |
| `GF_AudioBus` | audio | RefCounted | Audio Bus 管理（音量/静音） |
| `GF_AudioCueDef` | audio | RefCounted | 音频提示定义（stream + bus + volume 预设） |

## Config 层 (3)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_ConfigService` | config | GF_ModuleLifecycle | 游戏内容定义服务（ItemDef/BuildingDef 查询） |
| `GF_DefValidator` | config | RefCounted | 内容定义校验器 |
| `GF_ReferenceValidator` | config | RefCounted | 引用完整性校验器 |

## Environment 层 (5)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_AppConfig` | environment | RefCounted | 应用配置根对象（app/runtime/save/logging/threading/debug/network） |
| `GF_AppConfigLoader` | environment | RefCounted | 配置加载器（JSON 文件 + 合并默认值） |
| `GF_AppConfigValidator` | environment | RefCounted | 配置校验器 |
| `GF_EnvParser` | environment | RefCounted | 环境变量解析器 |
| `GF_ConfigSummary` | environment | RefCounted | 配置摘要输出工具 |

## Resource 层 (1)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_ResourceService` | resource | GF_ModuleLifecycle | 资源服务（缓存+LRU 回收） |

## Logging 层 (4)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_LogService` | logging | GF_ModuleLifecycle | 日志服务 |
| `GF_LogLevel` | logging | RefCounted | 日志级别枚举 |
| `GF_LogSink` | logging | RefCounted | 日志输出目标接口 |
| `GF_MemoryLogSink` | logging | RefCounted | 内存日志输出（保留最近 N 条） |

## Localization 层 (1)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_LocalizationService` | localization | GF_ModuleLifecycle | 本地化服务（多语言） |

## Debug 层 (1)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_DebugService` | debug | GF_ModuleLifecycle | 调试服务（FPS 统计/面板注册/命令追踪） |

## Network 层 (4)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_NetworkClient` | network | GF_ModuleLifecycle | 网络请求客户端 |
| `GF_NetworkRequest` | network | RefCounted | 网络请求定义 |
| `GF_NetworkResponse` | network | RefCounted | 网络响应封装 |
| `GF_MockNetworkClient` | network | RefCounted | Mock 网络客户端（测试用） |

## Data Access 层 (7)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_IEntityRepository` | data_access | RefCounted | 实体仓库接口 |
| `GF_ISaveRepository` | data_access | RefCounted | 存档仓库接口 |
| `GF_IMapRepository` | data_access | RefCounted | 地图仓库接口 |
| `GF_IWorldRepository` | data_access | RefCounted | 世界仓库接口 |
| `GF_UnitOfWork` | data_access | RefCounted | 工作单元（事务管理） |
| `GF_ChangeSet` | data_access | RefCounted | 变更集 |
| `GF_Revision` | data_access | RefCounted | 数据修订版本 |

## Installer 层 (4)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `GF_CoreInstaller` | application | RefCounted | Core 模块安装器 |
| `GF_EngineInstaller` | application | RefCounted | Engine 模块安装器 |
| `GF_EcsInstaller` | ecs | RefCounted | ECS 模块安装器 |
| `GF_ServiceInstallerImpl` | application | RefCounted | 领域服务安装器实现 |

## ECS Inspector (1)

| class_name | 模块 | 继承 | 一句话描述 |
|-----------|------|------|-----------|
| `EcsInspector` | ecs | RefCounted | ECS 运行时检查器（调试工具） |

---

> **Test 分支专属类**（不在 main 分支）：`FakeComponent`, `GutErrorTracker`, `GutHookScript`, `GutInputFactory`, `GutInputSender`, `GutMain`, `GutStringUtils`, `GutTest`, `GutTrackedError`, `GutUtils`, `MCPBaseTool`, `MCPLocalization`, `MCPServer`, `EcsInspector`, `GF_FakeFileSystemService`, `GF_FakeLogService`, `GF_FakeSaveProvider`, `GF_EcsTestFixture`
