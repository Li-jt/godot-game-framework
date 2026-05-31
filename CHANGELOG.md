# Changelog

## [0.2.0] — 2026-05-31

### 新增

- **InputService v2.0**: 新增 `register_action_def()` 支持完整动作定义（二进制/轴类型），新增 `read_axis()` 统一轴查询（聚合键盘/鼠标滚轮/手柄），`_game_input_blocker` 扩展到所有查询方法
- **InputActionDef**: 输入动作定义类，描述动作类型（BINARY/AXIS）、InputMap 绑定列表、灵敏度和死区
- **InputAdapter v2.0**: 新增 `read_axis()` 方法，聚合 InputMap action strength + 鼠标滚轮增量，支持手柄摇杆/扳机

### 变更

- `InputService.is_pressed/is_just_pressed/is_just_released` 统一走 `_can_pass()` 过滤（上下文 + 动态阻挡器），修复 dynamic blocker 仅对键盘生效的问题
- `InputAdapter.read_axis` 通过 `InputMap.action_get_events` 自动检测滚轮方向，无需手动注册正负方向

### 原则

- 所有游戏输入必须通过 `InputService` 查询，禁止直接使用 Godot `Input` 单例或 `_input/_unhandled_input` 回调
- 新增输入设备（手柄、触摸屏）只需修改 InputMap 绑定，不改业务代码

---

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
