# GF_ModuleLifecycle

> 适用版本: 0.3.0 | 继承: GF_ModuleLifecycle -> RefCounted

## 概述

所有 Framework 服务模块的统一生命周期基类。提供 7 种状态的状态机管理、幂等的初始化/释放接口，以及供子类覆写的初始化/释放钩子。

适用场景：任何需要在启动时初始化、关闭时释放资源的服务（InputService、UIService、SaveService 等）。不应在无需生命周期管理的纯工具类上使用。

## 状态枚举 (GF_CoreLifecycleState.State)

| 状态 | 值 | 描述 |
|------|-----|------|
| `UNINITIALIZED` | 0 | 未初始化，`_init()` 后的初始状态 |
| `INITIALIZING` | 1 | 初始化中，`init_module()` 已调用，`_on_init()` 执行中 |
| `INITIALIZED` | 2 | 初始化完成，等待配置（`configure()`） |
| `CONFIGURING` | 3 | 配置中，`finalize_configuration()` 已调用 |
| `READY` | 4 | 已就绪，可正常使用 |
| `FAILED` | 5 | 初始化或配置失败，不可恢复 |
| `DISPOSED` | 6 | 已释放，不可逆 |

### 状态流转规则

```
UNINITIALIZED → INITIALIZING → INITIALIZED → CONFIGURING → READY
                                                  ↓
                                               FAILED
任意状态 → DISPOSED（不可逆）
```

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `state` | `GF_CoreLifecycleState.State` | `UNINITIALIZED` | 当前生命周期状态 |
| `module_name` | `String` | `""` | 模块名称，初始化前由外部设置，用于日志和错误追踪 |

## 公共方法

### init_module() -> GF_OperationResult

执行模块初始化。幂等：重复调用处于 READY 状态的模块不会重新初始化。失败后（FAILED 状态）不允许再次调用，需由上层决定降级或退出。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_DISPOSED` (505) | 模块已释放 |

**示例:**

```gdscript
var service := MyService.new()
service.module_name = "MyService"
var result := service.init_module()
if result.is_fail():
    printerr("初始化失败: ", result.error.message)
```

### dispose_module() -> GF_OperationResult

释放模块资源。幂等：对已 DISPOSED 的模块重复调用不会报错。状态设置为 DISPOSED 后不可恢复。

**示例:**

```gdscript
service.dispose_module()
```

### finalize_configuration() -> GF_OperationResult

标记配置完成，将状态从 INITIALIZED 切换到 CONFIGURING 再切换到 READY。由 `GF_AppBootstrap._cfg_or_fail()` 在 `configure()` 成功后自动调用，通常不需要手动调用。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_PRECONDITION` (428) | 当前状态不是 INITIALIZED |

### is_ready() -> bool

模块是否处于 READY 状态（已就绪可正常使用）。

### is_failed() -> bool

模块是否处于 FAILED 状态（初始化或配置失败）。

### is_initialized() -> bool

模块是否处于 INITIALIZED 状态（初始化完成，等待配置）。

## 虚方法（子类覆写）

### _on_init() -> GF_OperationResult

子类覆写，执行模块的初始化逻辑。默认实现返回 `GF_OperationResult.ok()`。

**示例:**

```gdscript
func _on_init() -> GF_OperationResult:
    _event_bus = GF_EventBus.new()
    return GF_OperationResult.ok()
```

### _on_dispose() -> GF_OperationResult

子类覆写，执行模块的释放清理逻辑。默认实现返回 `GF_OperationResult.ok()`。

**示例:**

```gdscript
func _on_dispose() -> GF_OperationResult:
    _event_bus = null
    return GF_OperationResult.ok()
```

## See Also

- [GF_OperationResult](./gf_operation_result.md) -- 统一操作结果类型
- [GF_GameServices](./gf_game_services.md) -- 服务聚合对象
