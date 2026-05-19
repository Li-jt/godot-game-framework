# Changelog

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
