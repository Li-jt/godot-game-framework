# Changelog

## [Unreleased] — 2026-05-29

### 新增

- **ECS**: 新增完整 ECS 基础设施（EcsWorld、SparseSet Storage、Query、CommandBuffer、SystemGroup、Scheduler、Snapshot、SaveAdapter）
- **Application**: 新增 `EcsInstaller`，启动装配链路扩展为 Core → Engine → ECS → Services
- **Threading**: 新增 `ThreadingService` 与任务类型体系（Handle/Token/Options/Summary/Callbacks）
- **Runtime**: 新增框架级 `CommandBus` 最小实现，支持命令处理器注册与执行转发
- **Engine**: 新增 `NodePool` 通用节点对象池
- **Docs**: 新增架构文档与模块成熟度评审文档

### 变更

- **ECS**: `EcsScheduler` 直接注册到 Framework `Scheduler`，移除中间桥接对象以避免 GC 回收风险
- **Engine/SceneHost**: 场景宿主改为从 `.tscn` 实例化；世界挂载点命名从 `WorldRoot` 调整为 `WorldMount`；UI 与相机层级进一步解耦
- **Engine/Algorithm**: Pathfinder 升级为接口化三层拆分（`IPathGraph` / `ITraversal` / `IHeuristic`），支持按请求注入通行规则
- **Save**: `SaveService` API 调整（`load_slot` / `delete_slot`），避免与 Godot 内置函数命名冲突
- **UI/Input**: 新增 UI 输入阻挡闸门，强化面板与世界输入边界

### 修复

- **ECS**: 修复 `EcsScheduler` 节流系统使用时间参数错误（改为传入实际 elapsed）
- **ECS**: 修复 QueryRow 内嵌类导致的语法与外部引用问题，提取为独立类型
- **ECS**: 补全接口继承、命名统一、类型标注与空安全处理
- **Threading**: `slow_job_warn` 默认阈值由 120ms 调整为 350ms，并支持按任务覆写

## [0.1.0] — 2026-05-19

### 新增

- **Application**: AppBootstrap 装配器、ServiceRegistry 注册中心、CoreInstaller / EngineInstaller / ServiceInstallerImpl 安装器
- **Core**: ModuleLifecycle 生命周期基类、OperationResult 统一结果、GameServices 服务聚合、UiContext / GameplayContext / SaveContext 窄上下文
- **Config**: ConfigService 游戏定义仓库、DefValidator 校验器
- **Environment**: AppConfig 配置模型、AppConfigLoader 多源加载（JSON + .env）、环境合并优先级
- **Event**: EventBus 事件总线、EventToken 订阅令牌、scope 清理
- **Flow**: AppFlow 应用状态机（BOOT→MAIN_MENU→LOADING→IN_GAME⇄PAUSE）
- **Input**: InputService 输入服务、InputContext 上下文栈（白名单/黑名单）、InputAdapter 引擎适配
- **Logging**: LogService 分级日志（Debug/Info/Warning/Error）、MemoryLogSink、文件分层输出
- **UI**: UIService 面板管理（注册/打开/关闭/缓存/prewarm）、UIPanel 基类（HIDE_ON_CLOSE / DESTROY_ON_CLOSE / PERSISTENT 生命周期）、UIPanelDef 面板定义、UiContext 自动注入
- **Engine**: AssetLoadingService 资源加载、SceneFactory 场景工厂、SceneHost 场景宿主（WorldRoot + 6 层 UI 层）、PathResolver 路径解析、Scheduler Tick 调度器、FileSystemService 文件系统
- **Resource**: ResourceService 分组资源缓存、LRU 回收
- **Runtime**: RuntimeService 运行时模式（Local/Remote/Hybrid）、CommandStrategy / SaveStrategy
- **Save**: SaveService 存档服务、SaveProvider / LocalSaveProvider、SaveVersionMigrator 版本迁移
- **Network**: NetworkRequest / NetworkResponse、MockNetworkClient
- **DataAccess**: IEntityRepository / IMapRepository / IWorldRepository 接口、UnitOfWork
