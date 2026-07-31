# 运行时模式

## 概述

GF_RuntimeService 管理框架的运行时模式，决定命令执行和存档的策略路径。框架定义了三种运行模式，当前仅 LOCAL 模式完整实现，REMOTE 和 HYBRID 为预留模式。

## 三种模式

| 模式 | 枚举值 | 含义 | 实现状态 |
|------|--------|------|---------|
| LOCAL | `GF_RuntimeMode.Mode.LOCAL` | 本地即权威，直接读写 | 完整实现 |
| REMOTE | `GF_RuntimeMode.Mode.REMOTE` | 远程即权威，操作依赖远程确认 | 预留 |
| HYBRID | `GF_RuntimeMode.Mode.HYBRID` | 本地预测 + 远程确认，失败回滚 | 预留 |

```gdscript
# 在 app_config.json 中配置
{
    "runtime": {
        "mode": "local",
        "enable_prediction": false,
        "enable_rollback": false
    }
}
```

## LOCAL 模式

LOCAL 模式下，游戏在本地计算机运行，本地即为权威。所有命令在本地直接执行，存档在本地读写。

```gdscript
# 通过 GF_GameServices 访问
if services.runtime.is_local():
    # 本地直接执行命令
    var result := services.runtime.get_command_strategy()
    # ...
```

### CommandStrategy 替换点

`GF_CommandStrategy` 定义了命令执行的抽象。在 LOCAL 模式下，框架使用 `GF_LocalCommandStrategy`：

```gdscript
# GF_LocalCommandStrategy（框架内部）
class_name GF_LocalCommandStrategy
extends GF_CommandStrategy

func execute(p_command: GF_ICommand) -> GF_OperationResult:
    # 直接执行命令，不经过网络
    return _command_bus.execute(p_command)
```

### SaveStrategy 替换点

`GF_SaveStrategy` 定义了存档读写的抽象。在 LOCAL 模式下，存档直接在本地文件系统读写：

```gdscript
# 获取存档策略
var result := services.runtime.get_save_strategy()
if result.is_ok():
    var strategy: GF_SaveStrategy = result.data
    # strategy.save() / strategy.load()
```

## REMOTE 模式（预留）

REMOTE 模式下，游戏逻辑运行在服务器，客户端仅为输入/渲染终端。所有命令需要发送到远程服务器确认后才能生效。

预留的架构设计：

```
客户端                        服务器
  │                            │
  ├─ 发送命令 ────────────────→│
  │                            ├─ 验证命令
  │                            ├─ 执行命令
  │  ←─────────────────────────┤─ 返回结果
  ├─ 应用结果                   │
```

## HYBRID 模式（预留）

HYBRID 模式结合了 LOCAL 和 REMOTE 的优势：客户端立即执行预测（乐观更新），同时发送命令到服务器。当服务器确认与预测不一致时，回滚到正确状态。

预留的架构设计：

```
客户端                        服务器
  │                            │
  ├─ 保存快照                   │
  ├─ 执行预测（乐观）            │
  ├─ 发送命令 ────────────────→│
  │                            ├─ 验证命令
  │                            ├─ 执行命令
  │  ←─────────────────────────┤─ 返回确认
  ├─ 比较预测与确认              │
  ├─ 不一致 → 回滚并重放         │
  ├─ 一致 → 确认预测             │
```

### 相关配置项

```json
{
    "runtime": {
        "mode": "hybrid",
        "enable_prediction": true,
        "enable_rollback": true
    }
}
```

## 运行时模式 API

### 模式查询

```gdscript
# 判断模式
runtime.is_local()           # 是否本地模式
runtime.is_remote()          # 是否远程模式
runtime.is_hybrid()          # 是否混合模式
runtime.get_mode()           # 获取枚举值
runtime.get_mode_name()      # 获取可读名称（"Local" / "Remote" / "Hybrid"）
```

### 特性查询

```gdscript
# 是否需要远程确认
runtime.requires_remote_confirm()  # Remote 或 Hybrid 返回 true

# 本地是否为最终权威
runtime.is_local_authority()       # 仅 LOCAL 返回 true

# 功能启用检查
runtime.is_prediction_enabled()    # 预测是否启用（需 HYBRID 且 enable_prediction=true）
runtime.is_rollback_enabled()      # 回滚是否启用（需 HYBRID 且 enable_rollback=true）
```

### 策略获取

```gdscript
# 获取命令执行策略
var cmd_result := runtime.get_command_strategy()
if cmd_result.is_ok():
    var strategy: GF_CommandStrategy = cmd_result.data
    strategy.execute(my_command)

# 获取存档策略
var save_result := runtime.get_save_strategy()
if save_result.is_ok():
    var strategy: GF_SaveStrategy = save_result.data
    # 使用策略读写存档
```

> **注意**：`get_command_strategy()` 和 `get_save_strategy()` 在 REMOTE/HYBRID 模式下返回 `fail`（`ERR_INTERNAL`），因为这两种模式尚未实现。

## 当前能力边界

| 功能 | LOCAL | REMOTE | HYBRID |
|------|-------|--------|--------|
| 命令本地执行 | ✅ | ❌ | ❌ |
| 存档本地读写 | ✅ | ❌ | ❌ |
| 网络命令同步 | N/A | 🔮 | 🔮 |
| 预测执行 | N/A | N/A | 🔮 |
| 回滚机制 | N/A | N/A | 🔮 |
| CommandStrategy | ✅ | 🔮 | 🔮 |
| SaveStrategy | ✅ | 🔮 | 🔮 |

> 🔮 = 预留，将在未来版本实现

## 完整示例：模式检测 + 条件逻辑

```gdscript
# game_command_executor.gd
class_name GameCommandExecutor
extends RefCounted

var _runtime: GF_RuntimeService = null
var _log: GF_LogService = null


func configure(p_runtime: GF_RuntimeService, p_log: GF_LogService) -> void:
    _runtime = p_runtime
    _log = p_log


func execute_build(p_building_id: String, p_position: Vector2) -> GF_OperationResult:
    match _runtime.get_mode():
        GF_RuntimeMode.Mode.LOCAL:
            return _execute_local(p_building_id, p_position)

        GF_RuntimeMode.Mode.HYBRID:
            if _runtime.is_prediction_enabled():
                return _execute_hybrid_predictive(p_building_id, p_position)
            else:
                return _execute_local(p_building_id, p_position)

        GF_RuntimeMode.Mode.REMOTE:
            return _execute_remote(p_building_id, p_position)

        _:
            return GF_OperationResult.fail(
                GF_OperationResult.ERR_INTERNAL,
                "未知运行时模式",
                "GameCommandExecutor"
            )


func _execute_local(p_building_id: String, p_position: Vector2) -> GF_OperationResult:
    _log.info("Command", "LOCAL 模式：直接建造 %s 在 (%f, %f)" % [p_building_id, p_position.x, p_position.y])

    # 1. 资源校验
    if not _has_resources(p_building_id):
        return GF_OperationResult.fail(GF_OperationResult.ERR_PRECONDITION, "资源不足")

    # 2. 位置校验
    if not _is_position_valid(p_position):
        return GF_OperationResult.fail(GF_OperationResult.ERR_CONFLICT, "位置已被占用")

    # 3. 扣减资源 + 创建建筑
    _deduct_resources(p_building_id)
    _create_building_entity(p_building_id, p_position)

    return GF_OperationResult.ok()


func _execute_remote(_p_building_id: String, _p_position: Vector2) -> GF_OperationResult:
    return GF_OperationResult.fail(
        GF_OperationResult.ERR_INTERNAL,
        "REMOTE 模式尚未实现",
        "GameCommandExecutor"
    )


func _execute_hybrid_predictive(_p_building_id: String, _p_position: Vector2) -> GF_OperationResult:
    return GF_OperationResult.fail(
        GF_OperationResult.ERR_INTERNAL,
        "HYBRID 预测模式尚未实现",
        "GameCommandExecutor"
    )
```

```gdscript
# 在 Game 层启动时使用
func _on_app_ready(p_context: GF_GameServices) -> void:
    var executor := GameCommandExecutor.new()
    executor.configure(p_context.runtime, p_context.log)

    var mode_name := p_context.runtime.get_mode_name()
    p_context.log.info("Game", "运行模式: %s" % mode_name)

    if p_context.runtime.is_local():
        p_context.log.info("Game", "本地权威模式：命令和存档在本地处理")
```
