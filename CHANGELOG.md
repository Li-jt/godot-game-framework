# Changelog

## [0.3.0] — 2026-06-01

### 重构

- **InputService v3.0**: 完全重写，底层引入 `InputProvider` (Node) + `ActionResolver` + `InputActionState` 事件驱动架构
- **InputBinding**: 新增设备绑定类，支持 7 种设备源（键盘/鼠标按钮/滚轮/手柄按钮/手柄轴/触控板滑动/触控板捏合）+ 3 种输出模式（IMPULSE/HELD/ANALOG）
- **InputActionDef v3.0**: 重写，支持链式 API（`.bind_key().bind_wheel().set_deadzone()`），新增 `ComposeMode`（SUM/MAX/AVERAGE）
- **InputProvider**: 新增事件收集器 Node，`_unhandled_input` 统一收集原始事件。UI/游戏输入冲突由 Godot 引擎自动解决（GUI 消费后不触发 `_unhandled_input`）
- **ActionResolver**: 新增动作解析器，匹配原始事件到绑定，管理所有动作状态
- **InputActionState**: 新增运行时状态类，每帧合成 IMPULSE+HELD+ANALOG → 死区 → 灵敏度 → 平滑
- **InputAdapter**: 功能被 InputProvider 替代，保留但不再使用

### 移除

- `InputService` 不再依赖 `InputAdapter.configure()`
- `InputActionDef` 不再依赖 Godot InputMap 动作

---

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
