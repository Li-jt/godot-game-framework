# 服务依赖注入

**类比**：建造一栋房子时，你不会让水管工自己去工地挖地基——你按照"地基→框架→管道→电线→装修"的顺序，每步完成后再进行下一步。框架的依赖注入就是确保每个"工人"在上岗时，他需要的"材料"已经准备好了。

## 依赖注入 vs 全局单例

### 全局单例的问题

```gdscript
# ❌ 全局单例模式：任何代码可以随时访问任何服务
func do_something() -> void:
    var config := GlobalConfig.get_config()  # 隐式依赖
    var log := GlobalLog.instance            # 隐式依赖
    # 问题：
    # 1. 你不知道这个方法依赖什么（必须读代码体）
    # 2. 如果是 Mod，你不知道这些全局单例是否已初始化
    # 3. 单元测试时无法替换为 mock
```

### 依赖注入的优势

```gdscript
# ✅ 依赖注入：构造函数声明了所有依赖
func configure(p_config: GF_AppConfig, p_log: GF_LogService, p_world: GF_EcsWorld) -> GF_OperationResult:
    _config = p_config
    _log = p_log
    _world = p_world
    return GF_OperationResult.ok()

# 优点：
# 1. 签名明确声明了依赖（自文档化）
# 2. 测试时可以注入 mock 对象
# 3. 依赖关系可追踪、可分析
```

## configure() 注入模式

框架的所有服务通过 `configure()` 方法接收依赖，而不是通过 `_init()`：

```gdscript
class_name MyGameService
extends GF_ModuleLifecycle


var _log: GF_LogService = null
var _world: GF_EcsWorld = null
var _save_service: GF_SaveService = null


func configure(p_log: GF_LogService, p_world: GF_EcsWorld, p_save: GF_SaveService) -> GF_OperationResult:
    if p_log == null:
        return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "log 不能为空", module_name)
    if p_world == null:
        return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "world 不能为空", module_name)
    if p_save == null:
        return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "save 不能为空", module_name)

    _log = p_log
    _world = p_world
    _save_service = p_save
    _log.info(module_name, "配置完成")
    return GF_OperationResult.ok()
```

**为什么不在 `_init()` 中注入？**
- `_init()` 执行时，其他服务可能尚未创建
- `_init()` 不支持返回 `GF_OperationResult`
- 框架采用的是"创建实例 → `init_module()` → `configure()` → `finalize_configuration()` → READY"的顺序

## ServiceRegistry — 服务注册中心

`GF_ServiceRegistry` 是一个中央注册中心，维护服务名称到服务实例的映射。框架在启动时自动注册所有内置服务：

```gdscript
# 框架内部自动执行（你不需要手动做）
registry.register_all([
    [GF_ServiceRegistry.KEY_LOG,            log_service],
    [GF_ServiceRegistry.KEY_ECS_WORLD,      ecs_world],
    [GF_ServiceRegistry.KEY_INPUT,          input_service],
    [GF_ServiceRegistry.KEY_UI,             ui_service],
    [GF_ServiceRegistry.KEY_SAVE,           save_service],
    [GF_ServiceRegistry.KEY_AUDIO,          audio_service],
    [GF_ServiceRegistry.KEY_EVENT_BUS,      event_bus],
    [GF_ServiceRegistry.KEY_CONFIG_SERVICE, config_service],
    # ... 等 20+ 个服务
])
```

注册中心提供了以下能力：

| 能力 | 说明 |
|---|---|
| 按 key 查询服务实例 | `registry.get("log")` |
| 验证所有必需服务已注册 | `registry.verify_pending()` |
| 防止重复注册 | 重复 key 会触发警告 |

## GF_GameServices — 服务聚合对象

框架组装完所有服务后，构造一个 `GF_GameServices` 聚合对象，传递给游戏代码。这是游戏代码获取框架服务的**唯一入口**：

```gdscript
# 在 _on_post_boot 中
func _on_post_boot(context: GF_GameServices) -> GF_OperationResult:
    # 通过 context 访问所有框架服务
    var log: GF_LogService = context.log
    var world: GF_EcsWorld = context.ecs_world
    var input: GF_InputService = context.input
    var ui: GF_UIService = context.ui
    var audio: GF_AudioService = context.audio
    var save: GF_SaveService = context.save_service
    var event: GF_EventBus = context.event_bus
    var config: GF_ConfigService = context.config_service
    var resource: GF_ResourceService = context.resource
    var scheduler: GF_Scheduler = context.scheduler
    var ecs_scheduler: GF_EcsScheduler = context.ecs_scheduler
    var threading: GF_ThreadingService = context.threading
    var file_system: GF_FileSystemService = context.file_system
    var loc: GF_LocalizationService = context.loc
    var debug: GF_DebugService = context.debug
    var app_flow: GF_AppFlow = context.app_flow
    var runtime: GF_RuntimeService = context.runtime

    return GF_OperationResult.ok()
```

### GameServices 完整字段列表

| 字段 | 类型 | 说明 |
|---|---|---|
| `config` | `GF_AppConfig` | 应用配置 |
| `log` | `GF_LogService` | 日志服务 |
| `scene_factory` | `GF_SceneFactory` | 场景工厂，统一场景实例化入口 |
| `input` | `GF_InputService` | 输入服务 |
| `ui` | `GF_UIService` | UI 服务 |
| `audio` | `GF_AudioService` | 音频服务 |
| `file_system` | `GF_FileSystemService` | 文件系统服务 |
| `resource` | `GF_ResourceService` | 资源服务 |
| `event_bus` | `GF_EventBus` | 事件总线 |
| `save_service` | `GF_SaveService` | 存档服务 |
| `config_service` | `GF_ConfigService` | 配置服务（内容定义查询） |
| `debug` | `GF_DebugService` | 调试服务 |
| `loc` | `GF_LocalizationService` | 本地化服务 |
| `app_flow` | `GF_AppFlow` | 应用流程状态机 |
| `scheduler` | `GF_Scheduler` | Tick 调度器 |
| `runtime` | `GF_RuntimeService` | 运行时模式服务 |
| `threading` | `GF_ThreadingService` | 线程服务 |
| `ecs_world` | `GF_EcsWorld` | ECS 世界 |
| `ecs_scheduler` | `GF_EcsScheduler` | ECS 调度器 |
| `content_def` | `GF_ContentDefRegistry` | 内容定义注册表 |
| `def_id` | `GF_DefIdRegistry` | ID 注册表 |

## 窄上下文 — 按需分配

直接传递整个 `GF_GameServices` 有时过于宽泛——一个存档系统不需要访问输入服务。框架提供了三个窄上下文：

### GF_GameplayContext — 玩法上下文

```gdscript
var ctx: GF_GameplayContext = game_services.create_gameplay_context()
# 包含：log, event_bus, app_flow, scene_factory, input, config
```

适合：ECS 系统、命令行处理器、游戏玩法逻辑。

### GF_UiContext — UI 上下文

```gdscript
var ctx: GF_UiContext = game_services.create_ui_context()
# 包含：log, ui, input, event_bus, scene_factory, loc, save_service, config_service, config, app_flow, debug, audio
```

适合：UI 面板脚本、UI 控制器。

### GF_SaveContext — 存档上下文

```gdscript
var ctx: GF_SaveContext = game_services.create_save_context()
# 包含：log, save_service, config_service, config
```

适合：存档相关的逻辑、版本迁移器。

**为什么用窄上下文？**
- 文档化：接收方一眼看出自己需要什么
- 约束：防止 UI 脚本偷偷访问 ECS World 或存档
- 测试：只需要 mock 少量服务

## 将上下文传递给游戏子系统

```gdscript
# my_game_bootstrap.gd
func _on_post_boot(context: GF_GameServices) -> GF_OperationResult:
    # 创建窄上下文
    var gameplay_ctx := context.create_gameplay_context()
    var ui_ctx := context.create_ui_context()
    var save_ctx := context.create_save_context()

    # 注入到游戏子系统
    var game_world := MyGameWorld.new()
    var init_result := game_world.initialize(gameplay_ctx, context.ecs_world, context.ecs_scheduler)
    if init_result.is_fail():
        return init_result

    var ui_manager := MyUIManager.new()
    ui_manager.initialize(ui_ctx)

    var save_manager := MySaveManager.new()
    save_manager.initialize(save_ctx)

    return GF_OperationResult.ok()
```

## 启动流程全景

```text
GF_AppBootstrap._ready()
  │
  ├─ _create_app_config()          → 加载 config/app_config.json
  │
  ├─ _boot_phase_core()            → CoreInstaller 安装
  │    ├─ GF_ModuleLifecycle       ● 日志服务、配置对象
  │    ├─ GF_OperationResult       ● 服务注册中心
  │    └─ GF_ServiceRegistry
  │
  ├─ _boot_phase_engine()          → EngineInstaller 安装
  │    └─ 引擎适配层服务             ● SceneFactory, FileSystem, Threading, Scheduler ...
  │
  ├─ _boot_phase_ecs()             → EcsInstaller 安装
  │    └─ ECS 基础设施               ● EcsWorld, EcsScheduler, EcsStorage ...
  │
  ├─ _boot_phase_services()        → ServiceInstaller 安装
  │    └─ 高级服务                   ● InputService, UIService, SaveService, AudioService ...
  │
  ├─ _boot_phase_finalize()        → 最终装配
  │    ├─ registry.verify_pending()
  │    ├─ _build_game_services()   → 构造 GF_GameServices
  │    ├─ _on_post_boot(context)   → ★ 你的入口点
  │    └─ app_flow.transition_to(MAIN_MENU)
  │
  └─ _on_app_ready(context)        → 应用完全就绪
```

## 10 个生命周期 Hook

`GF_AppBootstrap` 提供了 10 个可覆写的 Hook，允许你在各安装阶段之间注入逻辑：

```gdscript
class_name MyGameBootstrap
extends GF_AppBootstrap


func _on_before_any_install() -> void:
    pass  # 最早执行：在任何安装器之前

func _on_before_core_install() -> void:
    pass  # Core 安装前

func _on_after_core_install(p_deps: Dictionary) -> void:
    pass  # Core 安装后：日志已可用

func _on_before_engine_install(p_deps: Dictionary) -> void:
    pass  # 引擎层安装前

func _on_after_engine_install(p_deps: Dictionary) -> void:
    pass  # 引擎层安装后：文件系统、调度器已可用

func _on_before_ecs_install(p_deps: Dictionary) -> void:
    pass  # ECS 安装前

func _on_after_ecs_install(p_deps: Dictionary) -> void:
    pass  # ECS 安装后：World、Scheduler 已可用，可注册组件类型

func _on_before_service_install(p_deps: Dictionary) -> void:
    pass  # 高级服务安装前

func _on_after_service_install(p_deps: Dictionary) -> void:
    pass  # 高级服务安装后：Input、UI、Save、Audio 已可用

func _on_post_boot(context: GF_GameServices) -> GF_OperationResult:
    return GF_OperationResult.ok()  # ★ 主要入口：所有服务已就绪

func _on_app_ready(p_context: GF_GameServices) -> void:
    pass  # 应用完全就绪：AppFlow 已切换到 MAIN_MENU
```

**最常用的两个 Hook**：
- `_on_post_boot(context)`：注册 ECS 系统、创建初始实体、初始化游戏世界
- `_on_app_ready(context)`：首次进入主菜单后执行，适合加载首页 UI

---

**下一步**: [类名约定](class-name-convention.md) — 框架的命名规则一览，或返回[框架概览](../getting-started/overview.md)。
