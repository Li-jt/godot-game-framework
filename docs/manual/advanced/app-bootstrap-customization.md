# 自定义启动流程

## 概述

GF_AppBootstrap 是框架的启动装配器，使用 Installer 模式按阶段装配所有框架服务。它提供 10 个生命周期 Hook，允许 Game 层和 Mod 在各安装阶段之间注入自定义逻辑。

## 启动流程概览

```
_on_before_any_install()
    │
    ├─ _on_before_core_install()
    ├─ GF_CoreInstaller.install()         # 核心服务（Log, Config, EventBus）
    ├─ _on_after_core_install(deps)
    │
    ├─ _on_before_engine_install(deps)
    ├─ GF_EngineInstaller.install()       # 引擎适配层
    ├─ _on_after_engine_install(deps)
    │
    ├─ _on_before_ecs_install(deps)
    ├─ GF_EcsInstaller.install()          # ECS 基础设施
    ├─ _on_after_ecs_install(deps)
    │
    ├─ _on_before_service_install(deps)
    ├─ GF_ServiceInstallerImpl.install()  # 领域服务（Input/UI/Save/Audio）
    ├─ _on_after_service_install(deps)
    │
    ├─ ServiceRegistry.verify_pending()
    ├─ _on_post_boot(context)             # Game 层初始化入口
    ├─ AppFlow → MAIN_MENU
    └─ _on_app_ready(context)            # 应用就绪
```

## 10 个生命周期 Hook 详解

### 1. `_on_before_any_install()`

在任何 Installer 运行之前调用。适合设置全局状态、解析命令行参数、初始化第三方 SDK。

```gdscript
func _on_before_any_install() -> void:
    # 解析启动参数
    var args := OS.get_cmdline_args()
    for arg in args:
        if arg == "--no-audio":
            _boot_flags.disable_audio = true
```

### 2. `_on_before_core_install()`

在 GF_CoreInstaller 运行前调用。此时尚无任何服务可用。

### 3. `_on_after_core_install(p_deps: Dictionary)`

GF_CoreInstaller 运行后调用。此时可用的服务包括：

- `deps.log` — GF_LogService
- `deps.config` — GF_AppConfig
- `deps.event_bus` — GF_EventBus
- `deps.file_system` — GF_FileSystemService

适合注册 Mod 的基础服务。

### 4. `_on_before_engine_install(p_deps: Dictionary)`

GF_EngineInstaller 运行前调用。Core 服务已就绪。

### 5. `_on_after_engine_install(p_deps: Dictionary)`

GF_EngineInstaller 运行后调用。此时新增可用服务：

- `deps.scene_factory` — GF_SceneFactory
- `deps.scheduler` — GF_Scheduler
- `deps.threading_svc` — GF_ThreadingService
- `deps.path_resolver` — GF_PathResolver
- `deps.resource_svc` — GF_ResourceService

适合注册 Mod 的引擎级依赖。

### 6. `_on_before_ecs_install(p_deps: Dictionary)`

GF_EcsInstaller 运行前调用。Engine 服务已就绪。

### 7. `_on_after_ecs_install(p_deps: Dictionary)`

GF_EcsInstaller 运行后调用。此时 ECS 基础设施就绪：

- `deps.ecs_world` — GF_EcsWorld
- `deps.ecs_scheduler` — GF_EcsScheduler

**这是注册 ECS 组件类型和系统的理想时机。**

```gdscript
func _on_after_ecs_install(p_deps: Dictionary) -> void:
    var world: GF_EcsWorld = p_deps.ecs_world
    var scheduler: GF_EcsScheduler = p_deps.ecs_scheduler

    # 注册组件类型
    world.register_component_type(&"Position")
    world.register_component_type(&"Velocity")
    world.register_component_type(&"Health")

    # 注册系统
    scheduler.add_system(MovementSystem.new(), GF_EcsSystemGroup.GAMEPLAY)
```

### 8. `_on_before_service_install(p_deps: Dictionary)`

GF_ServiceInstaller 运行前调用。ECS 和 Engine 服务已就绪。

### 9. `_on_after_service_install(p_deps: Dictionary)`

GF_ServiceInstaller 运行后调用。所有框架服务就绪：

- `deps.input_service` — GF_InputService
- `deps.ui_service` — GF_UIService
- `deps.audio_service` — GF_AudioService
- `deps.save_service` — GF_SaveService
- `deps.config_svc` — GF_ConfigService
- 等等...

适合注册 Mod 的高级服务。

### 10. `_on_post_boot(context: GF_GameServices) -> GF_OperationResult`

所有 Installer + verify 完成后调用。这是 **Game 层初始化入口**。

在此方法中完成 Game 层的装配：注册输入动作、加载内容定义、创建 Game 层服务。

```gdscript
func _on_post_boot(p_context: GF_GameServices) -> GF_OperationResult:
    # 注册输入动作
    _register_game_actions(p_context.input)

    # 加载游戏内容定义
    var result := _load_game_defs(p_context.config_service)
    if result.is_fail():
        return result

    # 注册存档模块
    _register_saveables(p_context.save_service)

    return GF_OperationResult.ok()
```

### 11. `_on_app_ready(context: GF_GameServices)`

应用完全就绪后调用（GF_AppFlow 已切换到 MAIN_MENU）。适合 Mod 初始化、延迟加载等非关键初始化。

## 自定义 Installer

如果需要添加自定义安装阶段，可以覆写 `_run_boot_sequence()` 并在其中插入自定义 Installer：

```gdscript
class_name MyGameBootstrap
extends GF_AppBootstrap


func _run_boot_sequence() -> void:
    state = BootState.LOADING
    _on_before_any_install()

    var config := _create_app_config()
    var registry := GF_ServiceRegistry.new()

    # 框架标准阶段
    var core_deps := _boot_phase_core(config, registry)
    if core_deps.is_empty(): return

    var engine_deps := _boot_phase_engine(core_deps, registry)
    if engine_deps.is_empty(): return

    # 自定义阶段：游戏内容初始化
    var content_deps := _boot_phase_content(engine_deps, registry)
    if content_deps.is_empty(): return

    var ecs_deps := _boot_phase_ecs(content_deps, registry)
    if ecs_deps.is_empty(): return

    var svc_deps := _boot_phase_services(content_deps, ecs_deps, registry)
    if svc_deps.is_empty(): return

    _boot_phase_finalize(svc_deps, ecs_deps, registry)


func _boot_phase_content(p_engine_deps: Dictionary, p_registry: GF_ServiceRegistry) -> Dictionary:
    var result := ContentInstaller.new().install({
        "_bootstrap": self,
        "_engine_deps": p_engine_deps,
        "_registry": p_registry,
    })
    if result.is_fail():
        return {}
    return result.data
```

## ServiceRegistry 高级用法

### required_keys

各 Installer 通过 `add_required()` 声明自己产出的必需服务。`verify_pending()` 在启动末尾校验所有必需服务是否已注册且就绪。

```gdscript
# 在自定义 Installer 中
func install(p_input: Dictionary) -> GF_OperationResult:
    var registry: GF_ServiceRegistry = p_input._registry

    # 声明此 Installer 的产出
    registry.add_required("MyCustomService")

    # 注册服务
    var svc := MyCustomService.new()
    svc.init_module()
    registry.register("MyCustomService", svc)

    return GF_OperationResult.ok({"my_service": svc})
```

### priority 覆盖机制

同名 key 注册时，只有更高优先级（数值更小）的可以覆盖已注册的服务。

```gdscript
# 框架默认注册（priority=100）
registry.register("Log", framework_log)

# Mod 用更高优先级覆盖（priority=10）
registry.register_with_priority("Log", mod_log, "mod:extended_logging", 10)
```

### owner 标识

注册时指定 owner，支持按 owner 批量注销（Mod 卸载时使用）：

```gdscript
# 以 Mod 身份注册
registry.register_with_priority("FishingData", fishing_data, "mod:fishing", 100)

# Mod 卸载时批量清除
var removed := registry.unregister_by_owner("mod:fishing")
```

## 失败恢复机制

启动过程中任何阶段失败，框架会：

1. 设置 `state = BootState.FAILED`
2. 调用 `_cleanup_on_fail()` — 逆序释放已初始化的模块
3. 打印 `push_error` 输出失败信息

```gdscript
func _cleanup_on_fail() -> void:
    # 逆序释放（先释放后初始化的）
    for i in range(_boot_modules.size() - 1, -1, -1):
        var m := _boot_modules[i]
        if m != null and m.is_ready():
            m.dispose_module()

    # 释放已添加的节点
    for child in _boot_nodes:
        if GF_RuntimeUtilities.is_node_valid(child):
            child.queue_free()

    _boot_modules.clear()
    _boot_nodes.clear()
```

## 完整示例：添加自定义安装阶段

```gdscript
# my_game_bootstrap.gd
class_name MyGameBootstrap
extends GF_AppBootstrap


func _on_after_ecs_install(p_deps: Dictionary) -> void:
    # 注册游戏专用的 ECS 组件类型
    var world: GF_EcsWorld = p_deps.ecs_world
    world.register_component_type(&"Position")
    world.register_component_type(&"Movement")
    world.register_component_type(&"Health")
    world.register_component_type(&"Combat")

    # 注册游戏系统
    var ecs_sched: GF_EcsScheduler = p_deps.ecs_scheduler
    ecs_sched.add_system(MovementSystem.new(), GF_EcsSystemGroup.GAMEPLAY)
    ecs_sched.add_system(CombatSystem.new(), GF_EcsSystemGroup.GAMEPLAY)


func _on_after_service_install(p_deps: Dictionary) -> void:
    # 注册自定义 Mod 服务（以 Mod 身份覆盖框架日志）
    # 可选：用更高优先级覆盖框架注册的服务
    pass


func _on_post_boot(p_context: GF_GameServices) -> GF_OperationResult:
    # 注册输入动作
    var input := p_context.input
    _register_action(input, "move_up", "W")
    _register_action(input, "move_down", "S")
    _register_action(input, "move_left", "A")
    _register_action(input, "move_right", "D")
    _register_action(input, "interact", "E")

    # 加载内容定义
    var result := p_context.config_service.load_defs("res://content/defs/")
    if result.is_fail():
        return GF_OperationResult.wrap(result, "MyGameBootstrap", "内容定义加载失败")

    # 注册非 Node 存档
    var stats := GameStats.new()
    p_context.save_service.register_saveable(stats)

    p_context.log.info("Game", "Game 层初始化完成")
    return GF_OperationResult.ok()


func _on_app_ready(p_context: GF_GameServices) -> void:
    # 延迟初始化：不在关键路径上的初始化
    p_context.log.info("Game", "应用就绪，开始 Mod 初始化")
    _init_mods(p_context)


func _register_action(p_input: GF_InputService, p_id: String, p_key: String) -> void:
    var def := GF_InputActionDef.new()
    def.action_id = p_id
    def.default_key = p_key
    p_input.register_action_def(def)
```

## 关键注意事项

1. **Hook 的执行顺序是固定的。** 不要跳过某些 Hook，依赖链可能断裂。
2. **`_on_post_boot` 必须返回 OperationResult。** 如果返回 fail，启动流程会中断。
3. **`_on_app_ready` 不应阻塞启动流程。** 此 Hook 在应用已就绪后调用，用于非关键初始化。
4. **自定义 Installer 需要确保产出服务已 init_module 且 ready。** 未 ready 的模块注册到 ServiceRegistry 会失败。
5. **优先级覆盖要谨慎。** 错误的覆盖可能导致框架功能失效。
