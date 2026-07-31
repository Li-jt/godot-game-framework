# GF_RuntimeService

> 适用版本: 0.3.0 | 继承: GF_RuntimeService -> GF_ModuleLifecycle

## 概述

运行时模式服务。根据 `GF_AppConfig.RuntimeSection` 确定当前运行模式（Local / Remote / Hybrid），Framework 各模块（Command、Save、Network）通过此服务判断行为分支。设计目标是集中管理运行模式决策，避免各服务散落 `is_local()` 式的手动判断。

**使用场景**：

- Command 层通过 `get_command_strategy()` 获取策略，不自己做模式判断
- Save 层通过 `get_save_strategy()` 获取策略
- Game 层通过 `is_local()` / `is_hybrid()` 等查询模式选择不同的逻辑分支
- Network 层通过 `requires_remote_confirm()` 决定是否需要等待服务端确认

**不适用场景**：

- 不要用于 Application 启动阶段的配置选择（使用 `GF_AppConfig` 直接读取）
- 不要绕过此服务直接读取 `GF_AppConfig.runtime.mode`（集中查询便于后续模式迁移）

## 运行模式

| 模式 | 枚举值 | 描述 |
|------|--------|------|
| LOCAL | `GF_RuntimeMode.Mode.LOCAL` | 本地即权威，直接读写，不依赖网络 |
| REMOTE | `GF_RuntimeMode.Mode.REMOTE` | 远程即权威，操作依赖远程确认（预留） |
| HYBRID | `GF_RuntimeMode.Mode.HYBRID` | 本地预测 + 远程确认，失败回滚（预留） |

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| （无公共属性） | | | 通过方法访问所有功能 |

## 公共方法

### 生命周期

---

#### configure(p_config: GF_AppConfig.RuntimeSection) -> GF_OperationResult

从 `GF_AppConfig.RuntimeSection` 读取配置并应用运行模式。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_config | GF_AppConfig.RuntimeSection | 运行时配置对象，包含 `mode`（String）、`enable_prediction`（bool）、`enable_rollback`（bool） |

**返回值：** `GF_OperationResult`。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| `ERR_BAD_REQUEST` (400) | `p_config` 为 `null` |

**示例：**

```gdscript
var runtime := GF_RuntimeService.new()
runtime.module_name = "Runtime"
runtime.init_module()

var app_config := GF_AppConfig.new()
app_config.runtime.mode = "Local"
var result := runtime.configure(app_config.runtime)
if result.is_fail():
    printerr("运行时配置失败: ", result.error.message)
```

---

### 模式查询

---

#### is_local() -> bool

当前模式是否为 LOCAL。

**返回值：** `bool`。

---

#### is_remote() -> bool

当前模式是否为 REMOTE。

**返回值：** `bool`。

---

#### is_hybrid() -> bool

当前模式是否为 HYBRID。

**返回值：** `bool`。

---

#### get_mode() -> GF_RuntimeMode.Mode

获取当前运行模式枚举值。

**返回值：** `GF_RuntimeMode.Mode`。

---

#### get_mode_name() -> String

获取当前运行模式的本地化名称。

**返回值：** `String`，`"Local"`、`"Remote"`、`"Hybrid"` 或 `"Unknown"`。

---

### 特性查询

---

#### requires_remote_confirm() -> bool

是否需要远程确认。Remote 或 Hybrid 模式下返回 `true`，表示命令执行需要等待远程服务器响应。

**返回值：** `bool`。

---

#### is_local_authority() -> bool

本地是否为最终权威。仅在 Local 模式下返回 `true`。非 Local 模式下本地操作仅为预测或请求，最终状态由远程定案。

**返回值：** `bool`。

---

#### is_prediction_enabled() -> bool

预测功能是否启用。仅在配置中 `enable_prediction` 为 `true` **且** 当前模式为 Hybrid 时返回 `true`。

**返回值：** `bool`。

---

#### is_rollback_enabled() -> bool

回滚功能是否启用。仅在配置中 `enable_rollback` 为 `true` **且** 当前模式为 Hybrid 时返回 `true`。

**返回值：** `bool`。

---

### 命令总线

---

#### set_command_bus(p_command_bus) -> void

配置框架级命令总线。在 `_on_init()` 中自动创建默认 `GF_CommandBus` 实例，此方法允许替换为自定义总线。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_command_bus | Variant | 命令总线实例 |

---

#### get_command_bus()

获取当前命令总线。用于注册或注销命令处理器。

**返回值：** `Variant`，当前命令总线实例。

**示例：**

```gdscript
var bus := runtime.get_command_bus()
bus.register_handler(my_handler)
```

---

### 策略入口

---

#### get_command_strategy() -> GF_OperationResult

获取当前模式对应的命令执行策略。CommandExecutor 通过此方法获取策略，无需自己做模式判断。

**返回值：** `GF_OperationResult`，`data` 字段为策略实例。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| `ERR_INTERNAL` (500) | Remote 或 Hybrid 模式的命令策略尚未实现 |
| OK | Local 模式返回 `GF_LocalCommandStrategy` 实例，已自动注入 `command_bus` |

**示例：**

```gdscript
var result := runtime.get_command_strategy()
if result.is_fail():
    _log.warn("Runtime", "命令策略不可用: %s" % result.error.message)
    return

var strategy: GF_CommandStrategy = result.data
strategy.execute(command, context)
```

---

#### get_save_strategy() -> GF_OperationResult

获取当前模式对应的存档策略。`GF_SaveService` 通过此方法获取策略。

**返回值：** `GF_OperationResult`，`data` 字段为策略实例。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| `ERR_INTERNAL` (500) | Remote 或 Hybrid 模式的存档策略尚未实现 |
| OK | Local 模式返回 `GF_SaveStrategy` 实例 |

**示例：**

```gdscript
var result := runtime.get_save_strategy()
if result.is_fail():
    _log.error("Runtime", "存档策略不可用: %s" % result.error.message)
    return

var strategy: GF_SaveStrategy = result.data
var provider_type := strategy.get_provider_type()  # "Local"
```

---

## 架构设计说明

### CommandExecutor 调用路径

```
Game 层 CommandExecutor
  → GF_RuntimeService.get_command_strategy()
    → GF_LocalCommandStrategy（Local 模式）
    → 未实现（Remote / Hybrid，返回 fail）
  → strategy.execute(command, context)
    → handler 已配置 → handler.call(command, context)
    → command_bus 已配置 → command_bus.execute(command, context)
    → 都未配置 → fail
```

### SaveService 调用路径

```
GF_SaveService
  → GF_RuntimeService.get_save_strategy()
    → GF_SaveStrategy.get_provider_type() → "Local"（Local 模式）
    → 未实现（Remote / Hybrid，返回 fail）
```

### 条件分支推荐写法

```gdscript
var runtime := game_services.runtime

# 简单分支
if runtime.is_local():
    execute_locally(command)
elif runtime.is_hybrid():
    predict_then_confirm(command)
else:
    # Remote 模式，等待服务端响应
    send_to_server(command)

# 通过策略入口（推荐：不自己做模式判断）
var result := runtime.get_command_strategy()
if result.is_ok():
    result.data.execute(command, context)
else:
    # 当前模式不支持命令执行，降级处理
    _log.error("Command", "无法执行命令: %s" % result.error.message)
```

## See Also

- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) -- 模块生命周期基类
- [GF_AppConfig](../environment/gf_app_config.md) -- 应用配置，包含 `RuntimeSection`
- [GF_RuntimeMode](../runtime/gf_runtime_mode.md) -- 运行模式枚举 (LOCAL / REMOTE / HYBRID)
- [GF_CommandBus](./gf_command_bus.md) -- 命令总线，Local 模式下通过策略调用
- [GF_CommandStrategy](../runtime/gf_command_strategy.md) -- 命令执行策略抽象基类
- [GF_LocalCommandStrategy](#gf_localcommandstrategy) -- Local 模式命令策略实现
- [GF_SaveStrategy](#gf_savestrategy) -- 存档策略抽象基类
- [GF_GameServices](../core/gf_game_services.md) -- 服务聚合对象，通过 `GameServices.runtime` 访问

---

# GF_RuntimeMode

> 适用版本: 0.3.0 | 继承: GF_RuntimeMode -> RefCounted

## 概述

运行时模式枚举定义。提供 `Mode` 枚举（LOCAL / REMOTE / HYBRID）和 `from_string()` 静态方法用于字符串到枚举的转换。

## 枚举

```gdscript
enum Mode {
    LOCAL,   # 本地即权威，直接读写，不依赖网络
    REMOTE,  # 远程即权威，操作依赖远程确认
    HYBRID,  # 本地预测 + 远程确认，失败回滚
}
```

## 静态方法

### from_string(p_text: String) -> Mode

将字符串转换为 Mode 枚举值。大小写不敏感，未知字符串默认返回 `LOCAL`。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_text | String | 模式字符串，如 `"local"`、`"Remote"`、`"HYBRID"` |

**返回值：** `GF_RuntimeMode.Mode`。匹配失败默认返回 `Mode.LOCAL`。

---

# GF_LocalCommandStrategy

> 适用版本: 0.3.0 | 继承: GF_LocalCommandStrategy -> GF_CommandStrategy -> RefCounted

## 概述

Local 模式的命令执行策略。优先使用配置的 `handler`（Callable），其次使用命令总线，两者都未配置则返回失败。

## 公共方法

### configure(p_handler: Callable) -> void

配置命令执行的 handler 回调。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_handler | Callable | 回调签名：`func(command, context: Dictionary) -> GF_OperationResult` |

### configure_command_bus(p_bus) -> void

配置命令总线。当 handler 未配置或无效时，通过命令总线执行命令。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_bus | Variant | `GF_CommandBus` 实例 |

### execute(p_command, p_context: Dictionary) -> GF_OperationResult

执行命令。优先级：handler → command_bus → fail。

---

# GF_SaveStrategy

> 适用版本: 0.3.0 | 继承: GF_SaveStrategy -> RefCounted

## 概述

存档策略抽象基类。Local / Remote / Hybrid 各自实现。`GF_SaveService` 通过 `get_provider_type()` 确定应使用的 `GF_SaveProvider` 类型。

## 公共方法

### get_provider_type() -> String

返回当前策略推荐的 SaveProvider 类型标识。

**返回值：** `String`，默认返回 `"Local"`。
