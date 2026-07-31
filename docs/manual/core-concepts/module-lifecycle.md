# 模块生命周期

**类比**：想象一个家电的启动过程——插电（初始化）、设置参数（配置）、开始工作（就绪）、拔电（释放）。你不能在插电之前就设置参数，也不能在拔电之后继续工作。框架的每个服务都遵循同样的纪律。

## 7 态状态机

`GF_ModuleLifecycle` 定义了服务模块的完整生命周期。所有框架服务（`GF_InputService`、`GF_UIService`、`GF_SaveService` 等）以及你自定义的服务都必须继承它。

```text
UNINITIALIZED  →  INITIALIZING  →  INITIALIZED  →  CONFIGURING  →  READY
                     ↘ FAILED                                       
                                                                    
任意状态 → DISPOSED（不可逆）
```

| 状态 | 含义 | 可执行的操作 |
|---|---|---|
| `UNINITIALIZED` | 刚 `new()` 出来，未调用任何方法 | 无 |
| `INITIALIZING` | `init_module()` 正在执行 | 内部初始化（创建数据结构、分配资源） |
| `INITIALIZED` | 初始化完成，等待配置 | 可以 `configure()` 注入依赖 |
| `CONFIGURING` | `finalize_configuration()` 正在执行 | 过渡态，瞬间完成 |
| `READY` | 已就绪，可正常使用 | 所有业务方法 |
| `FAILED` | 初始化或配置阶段出错 | 只能检查错误信息，不能执行业务 |
| `DISPOSED` | 已释放，不可逆 | 无 |

## init_module() — 初始化

调用 `init_module()` 后，模块从 `UNINITIALIZED` 进入 `INITIALIZING`，并执行 `_on_init()` 虚方法。成功则进入 `INITIALIZED`，失败则进入 `FAILED`。

```gdscript
var service := MyService.new()
service.module_name = "MyService"

var result := service.init_module()
if result.is_fail():
    printerr("初始化失败: ", result.error.message)
    return

# 此时 service.state == GF_CoreLifecycleState.State.INITIALIZED
```

**幂等性**：对已处于 `READY` 状态的模块再次调用 `init_module()` 会直接返回成功，不会重复初始化。对已 `DISPOSED` 的模块调用会返回 `ERR_DISPOSED` 错误。

## dispose_module() — 释放

调用 `dispose_module()` 执行 `_on_dispose()` 虚方法，然后将状态设为 `DISPOSED`。此操作不可逆——释放后模块不能再被使用。

```gdscript
service.dispose_module()
# service.state == GF_CoreLifecycleState.State.DISPOSED
```

**幂等性**：对已 `DISPOSED` 的模块再次调用不会报错。

## finalize_configuration() — 配置完成

在通过 `configure()` 注入所有依赖后，调用 `finalize_configuration()` 将状态从 `INITIALIZED` 推进到 `READY`。此方法通常由 `GF_AppBootstrap._cfg_or_fail()` 自动调用，你不需要手动调用。

**前置条件**：只能在 `INITIALIZED` 状态调用，否则返回 `ERR_PRECONDITION`。

## 重写虚方法

子类重写 `_on_init()` 和 `_on_dispose()` 来实现自定义逻辑：

```gdscript
class_name MyCustomService
extends GF_ModuleLifecycle


var _database: Dictionary = {}


func _on_init() -> GF_OperationResult:
    # 分配资源、创建内部数据结构
    _database = {}
    return GF_OperationResult.ok()


func _on_dispose() -> GF_OperationResult:
    # 释放资源、关闭连接、清理引用
    _database.clear()
    return GF_OperationResult.ok()


func configure(p_api_key: String) -> GF_OperationResult:
    # 在 INITIALIZED 状态注入依赖
    if state != GF_CoreLifecycleState.State.INITIALIZED:
        return GF_OperationResult.fail(
            GF_OperationResult.ERR_PRECONDITION,
            "只能在 INITIALIZED 状态调用 configure()",
            module_name
        )
    _api_key = p_api_key
    return GF_OperationResult.ok()
```

## 完整的使用流程

在 Bootstrap 中，框架自动执行初始化 → 配置 → 就绪的完整流程：

```gdscript
# 框架内部逻辑（你不需要手动写这些）
func _init_or_fail(p_module: GF_ModuleLifecycle) -> bool:
    # 1. init_module() → INITIALIZED
    var r := p_module.init_module()
    if r.is_fail():
        _fail_boot(p_module.module_name, r)
        return false
    return true

func _cfg_or_fail(p_name: String, p_result: GF_OperationResult, p_module: GF_ModuleLifecycle = null) -> bool:
    if p_result.is_fail():
        if p_module != null:
            p_module.fail_configuration(p_result)
        _fail_boot(p_name, p_result)
        return false
    # 2. configure() 成功后 → finalize_configuration() → READY
    if p_module != null:
        p_module.finalize_configuration()
    return true
```

## 状态查询方法

| 方法 | 返回值 | 说明 |
|---|---|---|
| `is_ready()` | `bool` | 模块是否处于 `READY` 状态 |
| `is_initialized()` | `bool` | 模块是否处于 `INITIALIZED` 状态 |
| `is_failed()` | `bool` | 模块是否处于 `FAILED` 状态 |

## 完整错误码

`init_module()` 可能返回的错误：

| 错误码 | 含义 |
|---|---|
| `OK` (200) | 初始化成功 |
| `ERR_DISPOSED` (505) | 模块已被释放，不能再初始化 |

`finalize_configuration()` 可能返回的错误：

| 错误码 | 含义 |
|---|---|
| `OK` (200) | 配置完成 |
| `ERR_PRECONDITION` (428) | 当前状态不是 `INITIALIZED`，不能完成配置 |

---

**下一步**: [统一错误处理](operation-result.md) — 理解 `GF_OperationResult` 的使用模式，或 [ECS 世界](ecs-world.md) 开始学习数据架构。
