# godot-game-framework v0.3 架构改造方案

> 参考 QFramework 设计理念，解决三个核心架构问题：
> 1. 模块全部强制捆绑 — 无法按需引入
> 2. Installer 装配链路过于复杂
> 3. Context 间接层太多

**核心理念**：整个框架中**禁止使用字符串作为服务标识**。所有服务注册、获取、依赖声明均使用 `class_name` 引用，编译期安全。

---

## 一、当前架构问题

### 1.1 数字对比

| 指标 | 当前值 | QFramework | 改造目标 |
|------|--------|-----------|---------|
| 框架文件数 | 144 .gd 文件 | 1 个核心文件 | 按需加载 |
| 核心代码量 | ~12,000 行 | ~1,000 行 | 核心 ~2,000 行 |
| 初始化链路 | 5 文件、~580 行 | 1 方法、~30 行 | 1 文件、~150 行 |
| Context 间接层 | 4 层 | 1 层 | 1 层 |
| 模块可选 | ❌ | ✅ | ✅ |
| 服务标识 | 字符串 key | 泛型 `GetModel<T>()` | `class_name` 引用 |

### 1.2 当前启动流程（硬编码安装所有服务）

```
GF_DefaultBootstrap._ready()
  └─ GF_AppBootstrap._run_boot_sequence()
       ├─ GF_CoreInstaller.install()          ← Runtime、PathResolver、FileSystem、Log、EventBus、Loc、AppFlow
       ├─ GF_EngineInstaller.install()        ← AssetLoading、SceneFactory、SceneHost、Scheduler、Threading、InputAdapter
       ├─ GF_EcsInstaller.install()           ← EcsWorld、EcsScheduler
       ├─ GF_ServiceInstallerImpl.install()   ← Resource、ConfigService、Save、Input、Audio、Debug、UI
       ├─ GF_ServiceRegistry.register_all()   ← 优先级覆盖 + 所有权 + key 校验
       ├─ _build_game_services()              ← 22 个字段逐一赋值
       └─ _on_post_boot(context)
```

用户无法跳过任何模块。想要 ECS 但不想要 Input 系统？做不到。

### 1.3 服务依赖图

```
GF_LogService ← 所有人都依赖
GF_EventBus   ← AppFlow 依赖
GF_PathResolver ← FileSystem、AssetLoading、Save 依赖
GF_Scheduler  ← Threading、EcsScheduler 依赖
GF_FileSystemService ← ConfigService、LocalizationService 依赖
GF_AssetLoadingService ← SceneFactory、ResourceService 依赖
GF_SceneFactory  ← SceneHost 依赖
GF_SceneHost     ← UIService 依赖
GF_InputAdapter  ← InputService 依赖
GF_InputService  ← UIService 依赖
GF_AudioRuntime  ← AudioService 依赖
GF_SaveProvider  ← SaveService 依赖
GF_EcsWorld      ← EcsScheduler 依赖
GF_UIService     ← 依赖几乎所有东西（通过 UiContext 9 个字段）
```

---

## 二、QFramework 作为参考

```csharp
public class MyGame : Architecture<MyGame>
{
    protected override void Init()
    {
        // 声明式：我只注册我需要的
        RegisterModel<IPlayerModel>(new PlayerModel());
        RegisterSystem<ISaveSystem>(new SaveSystem());
        RegisterUtility<IStorage>(new EasySaveStorage());
    }
}

// 一层直达，泛型类型安全
var model = Architecture<MyGame>.Interface.GetModel<IPlayerModel>();
```

关键点：
- **没有 Installer**：`Init()` 就是全部
- **没有 Context DTO**：`GetModel<T>()` 一层直达
- **没有强制模块**：不注册就不存在
- **类型即 key**：`GetModel<IPlayerModel>()` — 编译期安全，不存在字符串

GDScript 没有泛型，但 `class_name` 是全局常量，可以用 `is_instance_of` 做类型匹配。

---

## 三、改造方案

### 3.1 核心设计：class_name 引用替代一切字符串

```gdscript
# ❌ 全框架禁止这种写法
var log := bootstrap.service("Log")           # 字符串 key
func dependencies() -> Array[String]:          # 字符串数组
    return ["Log", "PathResolver"]

# ✅ 全框架只用这种写法
var log := bootstrap.service(GF_LogService)    # class_name 引用，类型安全
func dependencies() -> Array:                   # class_name 引用数组
    return [GF_LogService, GF_PathResolver]
```

**为什么字符串不安全：**

```gdscript
# 字符串 — 拼错编译期发现不了
var log := bootstrap.service("Lgo")   # 运行时返回 null，半天找不到原因
deps["SaveProvide"]                   # 少了个 r，配置阶段静默失败

# class_name 引用 — 拼错编辑器直接标红
var log := bootstrap.service(GF_LgoService)   # 脚本解析阶段就报错
deps[GF_SaveProvide]                          # 不存在的 class_name，Godot 不给过
```

### 3.2 GF_Bootstrap：新的唯一入口

用一个文件替代当前的 5 个文件（AppBootstrap + 4 个 Installer + ServiceRegistry）。

```gdscript
## GF_Bootstrap
## 框架启动入口。Game 层继承此类，在 _assemble() 中按需注册服务。
##
## 使用方式：
##   class_name MyGame
##   extends GF_Bootstrap
##
##   func _assemble() -> void:
##       register(GF_InputService.new())
##       register(GF_EcsWorld.new())
##       # 不想要的模块不注册就行
##
##   func _on_ready() -> void:
##       var log := service(GF_LogService) as GF_LogService
##       log.info("MyGame", "启动完成")
class_name GF_Bootstrap
extends Node

## 所有已注册的服务实例
var _services: Array = []


func _ready() -> void:
    _install_builtins()       # 装框架内置的 5 个基础服务
    _assemble()                # 子类重写：注册自己的模块
    _init_all()                # 自动按依赖顺序 init + configure
    _on_ready()                # 子类重写：启动游戏逻辑


# ============================================================
# 子类重写
# ============================================================

func _assemble() -> void:
    pass

func _on_ready() -> void:
    pass


# ============================================================
# 公开 API
# ============================================================

## 注册一个或多个服务实例。同类型重复注册会报错。
## 接受单个实例或 Array，自动判断：
##   register(GF_InputService.new())        ← 单个
##   register([svc1, svc2])                ← Array，自动遍历
func register(p_what) -> GF_OperationResult:
    if p_what is Array:
        for item in p_what:
            var r := register(item)
            if r.is_fail(): return r
        return GF_OperationResult.ok()

    var cls := p_what.get_script()
    for svc in _services:
        if svc.get_script() == cls:
            return GF_OperationResult.fail(
                GF_OperationResult.ERR_CONFLICT,
                "服务已注册: %s" % cls.resource_path,
                "GF_Bootstrap"
            )
    _services.append(p_what)
    if p_what is GF_ModuleLifecycle:
        _bootstrap_ref_to(p_what)
    return GF_OperationResult.ok()


## 按 class_name 引用获取服务。类型安全，拼错的类名编译期就报错。
## var log := service(GF_LogService) as GF_LogService
func service(p_class) -> Variant:
    for svc in _services:
        if is_instance_of(svc, p_class):
            return svc
    push_error("GF_Bootstrap: 服务未注册 — %s" % p_class)
    return null


# ============================================================
# 内部
# ============================================================

func _bootstrap_ref_to(p_service) -> void:
    if p_service.has_method("_set_bootstrap"):
        p_service._set_bootstrap(self)


## 安装框架内置服务。这些总是存在，不占用户的 register 配额。
func _install_builtins() -> void:
    _add_builtin(GF_LogService.new())
    _add_builtin(GF_EventBus.new())
    _add_builtin(GF_PathResolver.new())

    var scheduler := GF_Scheduler.new()
    scheduler.name = "GF_Scheduler"
    add_child(scheduler)
    _add_builtin(scheduler)

    _add_builtin(GF_FileSystemService.new())


func _add_builtin(p_service) -> void:
    _services.append(p_service)
    _bootstrap_ref_to(p_service)


func _init_all() -> void:
    for svc in _services:
        if svc is GF_ModuleLifecycle:
            var r := svc.init_module()
            if r.is_fail():
                push_error("GF_Bootstrap: init 失败 — %s: %s" % [svc.module_name, r.error.message])

    var sorted := _topo_sort()

    for svc in sorted:
        if svc is GF_ModuleLifecycle:
            if svc.has_method("configure"):
                svc.configure()
            svc.finalize_configuration()


## 拓扑排序：dependencies() 中声明的类必须在当前服务之前配置
func _topo_sort() -> Array:
    # 构建 {class_ref → service_instance} 快速查找表
    var class_to_svc: Dictionary = {}
    for svc in _services:
        class_to_svc[svc.get_script()] = svc

    # 入度表：每个服务被多少个其他服务依赖
    var in_degree: Dictionary = {}
    var deps_graph: Dictionary = {}  # {svc → Array[svc_dep]}

    for svc in _services:
        var deps: Array = svc.dependencies() if svc.has_method("dependencies") else []
        deps_graph[svc] = deps
        if not in_degree.has(svc):
            in_degree[svc] = 0

        for dep_class in deps:
            var dep_svc = class_to_svc.get(dep_class, null)
            if dep_svc == null and svc.has_method("dependencies"):
                push_error("GF_Bootstrap: 依赖未满足 — %s 需要 %s" % [svc.module_name, dep_class])
                continue
            in_degree[svc] = in_degree.get(svc, 0) + 1

    # Kahn 算法
    var queue: Array = []
    for svc in _services:
        if in_degree.get(svc, 0) == 0:
            queue.append(svc)

    var result: Array = []
    while not queue.is_empty():
        var svc = queue.pop_front()
        result.append(svc)

        for other in deps_graph:
            var other_deps: Array = deps_graph[other]
            for dep_class in other_deps:
                if is_instance_of(svc, dep_class):
                    in_degree[other] = in_degree[other] - 1
                    if in_degree[other] == 0:
                        queue.append(other)

    return result
```

### 3.3 Service 统一写法

每个服务继承 `GF_ModuleLifecycle`，可选实现三个方法：

```gdscript
class_name GF_SaveService
extends GF_ModuleLifecycle

var _bootstrap: GF_Bootstrap = null
var _log: GF_LogService = null
var _path_resolver: GF_PathResolver = null
var _provider: GF_SaveProvider = null


## 由 GF_Bootstrap.register() 时自动注入
func _set_bootstrap(p_bs: GF_Bootstrap) -> void:
    _bootstrap = p_bs


## 声明依赖的服务类型。GF_Bootstrap 按此做拓扑排序，保证依赖先配置。
func dependencies() -> Array:
    return [GF_LogService, GF_PathResolver, GF_SaveProvider]


## 配置服务。此时依赖已按 dependencies() 声明完成配置，可直接获取。
func configure() -> GF_OperationResult:
    _log = _bootstrap.service(GF_LogService) as GF_LogService
    _path_resolver = _bootstrap.service(GF_PathResolver) as GF_PathResolver
    _provider = _bootstrap.service(GF_SaveProvider) as GF_SaveProvider

    if _log == null or _path_resolver == null or _provider == null:
        return GF_OperationResult.fail(...)
    return GF_OperationResult.ok()
```

**对于不需要依赖的服务，什么都不用写：**

```gdscript
class_name GF_EventBus
extends GF_ModuleLifecycle

func _on_init() -> GF_OperationResult:
    # 初始化内部状态
    return GF_OperationResult.ok()

# 没有 dependencies() → 没有依赖
# 没有 configure() → 无需配置
```

### 3.4 用户端使用效果

全部 `new()`，跟 QFramework 一致。依赖连线由各 Service 的 `configure()` 自动完成。

```gdscript
# my_game.gd
class_name MyGame
extends GF_Bootstrap

func _assemble() -> void:
    # 框架已自动装好 5 个内置服务（Log、EventBus、PathResolver、Scheduler、FileSystem）

    # ─── 全部 new()，不用想是用 new 还是 install ───
    register(GF_EcsWorld.new())
    register(GF_EcsScheduler.new())
    register(GF_SaveService.new())
    register(GF_LocalSaveProvider.new())
    register(GF_InputService.new())
    register(GF_InputAdapter.new())

    # 不想要 UI？不注册 GF_UIService 就行
    # 不想要 Audio？不注册 GF_AudioService 就行

func _on_ready() -> void:
    var log := service(GF_LogService) as GF_LogService
    var world := service(GF_EcsWorld) as GF_EcsWorld
    var save := service(GF_SaveService) as GF_SaveService

    log.info("MyGame", "启动完成")

    # 注册 ECS 系统
    var ecs_scheduler := service(GF_EcsScheduler) as GF_EcsScheduler
    ecs_scheduler.register_system(MyMovementSystem.new(), &"Simulation")
```

**关键：ECS 的连线在 configure() 中自动完成，不需要 Module.install() 手动连**

```gdscript
# GF_EcsScheduler 的 configure() 自动从 bootstrap 拿 EcsWorld 和 Scheduler
class_name GF_EcsScheduler
extends GF_ModuleLifecycle

func dependencies() -> Array:
    return [GF_EcsWorld, GF_Scheduler]

func configure() -> GF_OperationResult:
    _world = _bootstrap.service(GF_EcsWorld) as GF_EcsWorld
    var sched := _bootstrap.service(GF_Scheduler) as GF_Scheduler
    _bind_to_framework_scheduler(sched)
    return GF_OperationResult.ok()
```

**不想要 ECS 的项目：直接用 Godot 节点树 + 信号**

```gdscript
class_name SimpleGame
extends GF_Bootstrap

func _assemble() -> void:
    register(GF_SaveService.new())
    register(GF_LocalSaveProvider.new())
    register(GF_InputService.new())
    register(GF_AudioService.new())

func _on_ready() -> void:
    # 没有 ECS，用 Godot 原生方式管理实体
    add_child(preload("res://scenes/player.tscn").instantiate())
```

### 3.6 去掉窄 Context

**当前**：每个子系统有一个 Context DTO 类，手动拷贝字段：

```
GF_ServiceRegistry
  → GF_GameServices (22 个字段)
    → GF_UiContext (12 个字段拷贝)
    → GF_SaveContext (3 个字段拷贝)
    → GF_GameplayContext (6 个字段拷贝)
```

**改造后**：所有地方统一用 `_bootstrap.service(GF_XxxService)` 一层直达。

```gdscript
# 面板中
class_name MyPanel
extends GF_UIPanel

func _on_open(data: Dictionary) -> void:
    var log := _bootstrap.service(GF_LogService) as GF_LogService
    var save := _bootstrap.service(GF_SaveService) as GF_SaveService
    var audio := _bootstrap.service(GF_AudioService) as GF_AudioService
    log.info("MyPanel", "面板打开")

    # 不需要预先在 Context 里拷贝好字段，用到什么拿什么
```

`_bootstrap` 引用在 `GF_UIService` 创建面板时注入到 `panel._bootstrap`。

**删除的 Context 类：**
- `GF_GameServices` — 22 个字段的中间 DTO，不再需要
- `GF_UiContext` — 12 个字段的拷贝，不再需要
- `GF_SaveContext` — 3 个字段的拷贝，不再需要
- `GF_GameplayContext` — 6 个字段的拷贝，不再需要

### 3.7 测试友好

服务从 `_bootstrap` 获取依赖，测试时只需要一个最小 Bootstrap：

```gdscript
# 测试 GF_SaveService
func test_save_service() -> void:
    var bs := GF_Bootstrap.new()

    # 注入测试替身
    bs._services.append(GF_FakeLogService.new())      # is_instance_of 匹配 GF_LogService
    bs._services.append(GF_PathResolver.new())         # 真实 PathResolver（无状态）
    bs._services.append(GF_LocalSaveProvider.new())    # 存入测试目录

    var save_service := GF_SaveService.new()
    bs._services.append(save_service)
    bs._bootstrap_ref_to(save_service)

    # 手动 init + configure
    save_service.init_module()
    save_service.configure()

    assert_true(save_service.is_ready())
```

也可以保留显式 `configure(p_log, p_pr, p_provider)` 用于纯单元测试，但这取决于具体服务是否需要。

---

## 四、文件变更清单

### 4.1 删除的文件（10 个）

| 文件 | 原因 |
|------|------|
| `application/installers/core_installer.gd` | 合并到 GF_Bootstrap._install_builtins() |
| `application/installers/engine_installer.gd` | 各模块自管理 |
| `application/installers/ecs_installer.gd` | 各模块自管理 |
| `application/installers/service_installer_impl.gd` | 各模块自管理 |
| `application/installers/service_installer.gd` | 不再需要 Installer 抽象 |
| `application/service_registry.gd` | 由 Bootstrap._services + service() 替代 |
| `core/game_services.gd` | 由 Bootstrap.service() 替代 |
| `core/ui_context.gd` | 由 Bootstrap.service() 替代 |
| `core/save_context.gd` | 由 Bootstrap.service() 替代 |
| `core/gameplay_context.gd` | 由 Bootstrap.service() 替代 |

### 4.2 新增的文件

无。不需要新增 Module.install 类，全部通过 `new()` + `configure()` 完成。

### 4.3 重大修改的文件

| 文件 | 改动 |
|------|------|
| `application/app_bootstrap.gd` | **重写**为 GF_Bootstrap |
| `ui/ui_panel.gd` | `ctx` → `_bootstrap`，通过 `service(GF_XxxService)` 获取 |
| `ui/ui_service.gd` | 去掉 UiContext 依赖，configure() 改为从 bootstrap 获取 |
| `scenes/default_bootstrap.gd` | 适配新 API |
| 所有 `*_service.gd` | 统一实现 `dependencies()` + `configure()` |

---

## 五、改造后启动流程

```
GF_Bootstrap._ready()
  │
  ├─ _install_builtins()
  │   注册 Log、EventBus、PathResolver、Scheduler、FileSystem
  │
  ├─ _assemble()                    ← 子类重写：用户声明要哪些模块
  │    register(svc) for svc in GF_EcsModule.install()
  │    register(svc) for svc in GF_SaveModule.install()
  │    register(GF_InputService.new())
  │
  ├─ _init_all()                    ← 框架自动：
  │    ├─ 所有服务 init_module()
  │    ├─ 按 dependencies() 拓扑排序
  │    └─ 按序 configure() → finalize_configuration()
  │
  └─ _on_ready()                    ← 子类重写：所有服务就绪
       ├─ 注册 ECS 系统
       ├─ 注册 EventBus 消费者
       └─ 游戏逻辑开始
```

**与改造前对比：**

| 维度 | 改造前 | 改造后 |
|------|--------|--------|
| 装配方式 | 4 个 Installer 硬编码所有服务 | 用户 _assemble() 按需注册 |
| 服务注册 | GF_ServiceRegistry（字符串 key + 优先级覆盖 + 所有权） | Bootstrap._services（Array + class_name 引用） |
| 配置顺序 | 各 Installer 手动 new/init/cfg/track | _init_all() 自动拓扑排序 |
| 服务获取 | 4 层间接（Registry→GameServices→Context→panel.ctx） | 1 层（_bootstrap.service(GF_XxxService)） |
| 模块可选 | ❌ 全部强制捆绑 | ✅ 只注册需要的 |
| 类型安全 | ❌ 字符串 key | ✅ class_name 引用 |
| 装配代码量 | 5 文件、~580 行 | 1 文件、~150 行 |

---

## 六、分步实施

### Phase 1：核心改造（最优先）

1. **新建 `GF_Bootstrap`**：替代 AppBootstrap + 4 Installer + ServiceRegistry
2. **所有 Service 实现 `dependencies()` + `configure()`**：统一签名为无参，从 `_bootstrap.service(XxxService)` 获取依赖
3. **新增 `_set_bootstrap()`**：在 `GF_ModuleLifecycle` 基类中添加
4. **删除 4 个 Context 类**：`GF_GameServices`、`GF_UiContext`、`GF_SaveContext`、`GF_GameplayContext`
5. **删除 `GF_ServiceRegistry`**：
6. **重写 `scenes/default_bootstrap.gd`**

### Phase 2：清理 UI 依赖

7. `GF_UIService` 从 bootstrap 获取依赖，不再依赖 UiContext
8. `GF_UIPanel.ctx` → `GF_UIPanel._bootstrap`

### Phase 3：清理

9. 删除旧的 Installer 文件
10. 删除 `data_access/` 死代码
11. 更新测试文件
12. 更新文档

### Phase 4（后续）

14. 目录重组为 `core/` + `modules/`
15. Engine 适配层瘦身
16. 拆分 plugin/sub-plugin 支持

---

## 七、设计约束（框架必须遵守）

1. **全框架禁止字符串 key**：`register()`、`service()`、`dependencies()` 均使用 `class_name` 引用
2. **用户不注册就不存在**：Bootstrap 只装 5 个内置服务，其余全由用户控制
3. **一层直达**：`_bootstrap.service(GF_XxxService)` — 没有中间 Context DTO
4. **configure() 无参**：依赖通过 `_bootstrap.service()` 获取，显式声明在 `dependencies()` 中
5. **拓扑排序保证顺序**：依赖的 service 一定先配置好

---

## 八、一句话总结

> **从 "框架用字符串 key 替你硬编码装 23 个服务、4 层间接访问"，变成 "你用 class_name 引用声明要哪些模块，框架自动排序初始化、1 层直达"。**
