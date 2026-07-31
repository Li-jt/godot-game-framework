# GF_CommandBus

> 适用版本: 0.3.0 | 继承: GF_CommandBus -> RefCounted

## 概述

框架级命令总线（最小版）。负责命令校验调用、命令键路由到注册的 Handler、以及在 Handler 缺失时回退到命令对象自身的 `execute()` 方法。设计目标是提供稳定的命令执行入口，不绑定具体游戏语义，Remote / Hybrid 模式可在 `GF_CommandStrategy` 中复用同一入口。

**使用场景**：

- Game 层注册 `GF_ICommandHandler` 处理特定命令键
- 通过 `execute()` 统一执行命令，自动完成校验和路由
- Mod 或子系统通过 `register_handler()` 替换命令处理逻辑

**不适用场景**：

- 不要用于事件广播（使用 `GF_EventBus`）
- 不要用于 Game 层直接的函数调用（命令总线是间接分发层）
- 不要绕过命令总线直接执行命令对象（Remote/Hybrid 策略依赖此入口）

## 属性

此服务不暴露公共成员属性。

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| （无公共属性） | | | 通过方法访问所有功能 |

## 公共方法

### register_handler(p_handler) -> GF_OperationResult

注册命令处理器。重复注册同一命令键会覆盖旧处理器。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_handler | Variant | 命令处理器实例，必须实现 `command_key() -> String` 和 `handle(p_command, p_context) -> GF_OperationResult` |

**返回值：** `GF_OperationResult`。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| `ERR_BAD_REQUEST` (400) | `p_handler` 为 `null` |
| `ERR_BAD_REQUEST` (400) | `p_handler` 缺少 `command_key()` 或 `handle()` 方法 |
| `ERR_BAD_REQUEST` (400) | `p_handler.command_key()` 返回空字符串 |

**示例：**

```gdscript
var bus := GF_CommandBus.new()

# 注册处理器
var handler := MyPlaceBuildingHandler.new()
var result := bus.register_handler(handler)
if result.is_fail():
    printerr("注册处理器失败: ", result.error.message)
```

---

### unregister_handler(p_command_key: String) -> void

注销指定命令键的处理器。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_command_key | String | 要注销的命令键 |

**示例：**

```gdscript
bus.unregister_handler("place_building")
```

---

### clear_handlers() -> void

清空全部已注册的处理器。

**示例：**

```gdscript
bus.clear_handlers()
```

---

### execute(p_command, p_context: Dictionary) -> GF_OperationResult

执行命令。执行流程：1) 自动调用 `p_command.validate()` 校验（如果存在）；2) 查找已注册的 Handler 并调用其 `handle()`；3) 若未找到 Handler，回退到 `p_command.execute()`（如果存在）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_command | Variant | 命令对象，应实现 `command_key() -> String` 和 `execute(p_context) -> GF_OperationResult`，可选实现 `validate(p_context) -> GF_OperationResult` |
| p_context | Dictionary | 运行时上下文，传递给 `validate()`、`handle()` 和 `execute()` |

**返回值：** `GF_OperationResult`。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| `ERR_BAD_REQUEST` (400) | `p_command` 为 `null` |
| `ERR_NOT_FOUND` (404) | 未找到对应 Handler 且命令对象没有 `execute()` 方法 |
| `ERR_INTERNAL` (500) | `validate()` 返回值不是 `GF_OperationResult` 类型 |
| （透传） | 透传 `validate()`、`handle()` 或 `execute()` 返回的错误 |

**示例：**

```gdscript
var command := PlaceBuildingCommand.new()
command.building_type = "house"
command.position = Vector2(100, 200)

var context := {"world": world, "world_writer": world_writer}
var result := bus.execute(command, context)
if result.is_fail():
    _log.error("Command", "命令执行失败: %s" % result.error.message)
```

---

### has_handler(p_command_key: String) -> bool

查询指定命令键是否已注册处理器。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_command_key | String | 命令键 |

**返回值：** `bool`，已注册返回 `true`。

---

### get_registered_keys() -> Array[String]

获取当前已注册的所有命令键列表。

**返回值：** `Array[String]`，已注册命令键数组。

---

## See Also

- [GF_ICommand](#gf_icommand) -- 命令抽象，定义 `command_key()` / `validate()` / `execute()` 接口
- [GF_ICommandHandler](#gf_icommandhandler) -- 命令处理器抽象，分离执行逻辑
- [GF_RuntimeService](./gf_runtime_service.md) -- 运行时模式服务，提供 `get_command_strategy()`
- [GF_CommandStrategy](../runtime/gf_command_strategy.md) -- 命令执行策略抽象基类
- [GF_LocalCommandStrategy](#gf_localcommandstrategy) -- Local 模式命令策略

---

# GF_ICommand

> 适用版本: 0.3.0 | 继承: GF_ICommand -> RefCounted

## 概述

框架级命令抽象。Game 层命令可继承此类接入 `GF_CommandBus`。命令应保持"可验证 + 可执行"的最小行为约定。子类重写 `command_key()` 返回路由键，重写 `execute()` 实现执行逻辑，可选重写 `validate()` 进行前置校验。

**使用场景**：

- Game 层定义具体命令（PlaceBuilding、MoveUnit、StartResearch 等）
- 命令自身可独立执行（不依赖 Handler 时），也可通过 Handler 间接执行

---

## 公共方法

### command_key() -> String

返回命令键，用于路由到 `GF_CommandBus` 已注册的 Handler。返回空字符串表示无法路由到显式 Handler，`GF_CommandBus` 会直接调用 `execute()`。

**返回值：** `String`，命令键。默认返回 `""`。

**示例：**

```gdscript
class_name PlaceBuildingCommand
extends GF_ICommand

func command_key() -> String:
    return "place_building"
```

---

### validate(_p_context: Dictionary) -> GF_OperationResult

命令前置校验。在此方法中进行参数合法性检查、业务规则验证等。`GF_CommandBus.execute()` 会先调用此方法，校验失败则中止执行。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| _p_context | Dictionary | 运行时上下文 |

**返回值：** `GF_OperationResult`。默认返回 `ok()`。

**示例：**

```gdscript
func validate(_p_context: Dictionary) -> GF_OperationResult:
    if building_type.is_empty():
        return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "建筑类型不能为空", "PlaceBuildingCommand")
    if position.x < 0 or position.y < 0:
        return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "位置不能为负", "PlaceBuildingCommand")
    return GF_OperationResult.ok()
```

---

### execute(_p_context: Dictionary) -> GF_OperationResult

执行命令。子类必须重写此方法实现具体执行逻辑。`GF_CommandBus.execute()` 在没有注册 Handler 时会回退调用此方法。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| _p_context | Dictionary | 运行时上下文 |

**返回值：** `GF_OperationResult`。默认返回 `fail(ERR_INTERNAL, "GF_ICommand.execute 未实现")`。

**示例：**

```gdscript
func execute(_p_context: Dictionary) -> GF_OperationResult:
    var world: EcsWorld = _p_context["world"]
    var entity := world.spawn()
    world.add_component(entity, &"Building", {"type": building_type})
    world.add_component(entity, &"Position", {"x": position.x, "y": position.y})
    return GF_OperationResult.ok()
```

---

## See Also

- [GF_CommandBus](#gf_commandbus) -- 命令总线，执行入口
- [GF_ICommandHandler](#gf_icommandhandler) -- 命令处理器，替代命令对象自身的 `execute()`

---

# GF_ICommandHandler

> 适用版本: 0.3.0 | 继承: GF_ICommandHandler -> RefCounted

## 概述

框架级命令处理器抽象。用于把命令执行逻辑从命令对象中拆出，便于后续接入 Remote / Hybrid 策略时统一替换处理实现。Handler 通过 `GF_CommandBus.register_handler()` 注册后，所有匹配 `command_key()` 的命令都会路由到此 Handler 执行，不再经过命令对象自身的 `execute()`。

**使用场景**：

- Remote 模式：Handler 负责将命令序列化并发送到远程服务器
- Hybrid 模式：Handler 负责本地预测 + 远程确认 + 失败回滚
- Mod 扩展：替换框架默认的命令处理逻辑

---

## 公共方法

### command_key() -> String

声明本 Handler 处理的命令键。`GF_CommandBus` 使用此键值匹配命令路由。

**返回值：** `String`，命令键。默认返回 `""`。

**示例：**

```gdscript
class_name RemotePlaceBuildingHandler
extends GF_ICommandHandler

func command_key() -> String:
    return "place_building"
```

---

### handle(_p_command, _p_context: Dictionary) -> GF_OperationResult

处理命令。子类应重写并返回 `GF_OperationResult`。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| _p_command | Variant | 命令对象，通常为 `GF_ICommand` 子类实例 |
| _p_context | Dictionary | 运行时上下文 |

**返回值：** `GF_OperationResult`。默认返回 `fail(ERR_INTERNAL, "GF_ICommandHandler.handle 未实现")`。

**示例：**

```gdscript
func handle(_p_command, _p_context: Dictionary) -> GF_OperationResult:
    var cmd: PlaceBuildingCommand = _p_command as PlaceBuildingCommand
    if cmd == null:
        return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "命令类型错误", "RemotePlaceBuildingHandler")

    # 将命令发送到远程服务器
    var network := _p_context["network"]
    var result := network.send_command(cmd)
    return result
```

---

## See Also

- [GF_CommandBus](#gf_commandbus) -- 命令总线，Handler 的注册和执行入口
- [GF_ICommand](#gf_icommand) -- 命令抽象，Handler 未注册时的回退执行路径
- [GF_RuntimeService](./gf_runtime_service.md) -- 运行时模式服务，影响策略选择
