# GF_EcsRuntimeBridge

> 适用版本: 0.3.0 | 继承: GF_EcsRuntimeBridge -> RefCounted

## 概述

ECS 运行时模式桥接。根据 `GF_RuntimeMode`（Local/Remote/Hybrid）选择不同的 ECS 命令执行策略，支持预测（Prediction）、确认（Confirm）和回滚（Rollback）基础流程。

Hybrid 模式下维护一个预测快照栈，用于在网络权威服务器返回不一致结果时回滚到预测前的状态。

## 枚举: ExecuteMode

| 值 | 描述 |
|-----|------|
| `LOCAL` (0) | 本地权威模式 -- 客户端直接执行命令，无需预测/回滚 |
| `REMOTE` (1) | 远程权威模式 -- 客户端发送命令到服务器，等确认后执行 |
| `HYBRID` (2) | 混合预测模式 -- 客户端立即预测执行，服务器确认后校正或回滚 |

## 公共方法

### set_mode(p_mode: int) -> void

设置运行时模式。

```gdscript
bridge.set_mode(GF_EcsRuntimeBridge.ExecuteMode.HYBRID)
```

### get_mode() -> int

获取当前模式。

### save_prediction_snapshot(p_world: GF_EcsWorld) -> void

为 Hybrid 模式保存预测前快照。仅在 HYBRID 模式下有效，其他模式静默忽略。快照保存在内部栈中。

```gdscript
# 在发送命令到服务器前保存快照
bridge.save_prediction_snapshot(world)
# 立即预测执行...
```

### rollback_prediction(p_world: GF_EcsWorld) -> GF_OperationResult

Hybrid 模式：回滚到最近一次预测前状态。弹出栈顶快照并应用到世界。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_PRECONDITION` | 预测栈为空，无可用快照 |

```gdscript
# 服务器返回不一致结果时回滚
var result := bridge.rollback_prediction(world)
if result.is_fail():
    push_error("回滚失败: %s" % result.error.message)
```

### confirm_prediction() -> void

Hybrid 模式：确认预测（弹出栈顶快照，不恢复）。服务器确认后调用。

```gdscript
bridge.confirm_prediction()  # 服务器确认，丢弃该预测快照
```

### clear_predictions() -> void

清空预测栈。

### is_local() -> bool

是否为本地权威模式。

### is_remote() -> bool

是否为远程权威模式。

### is_hybrid() -> bool

是否为混合预测模式。

## 使用示例

### 本地模式（默认）

```gdscript
var bridge := GF_EcsRuntimeBridge.new()  # 默认 LOCAL
# 直接执行命令即可，无需预测/回滚
```

### Hybrid 模式流程

```gdscript
var bridge := GF_EcsRuntimeBridge.new(GF_EcsRuntimeBridge.ExecuteMode.HYBRID)

# 1. 发送命令前保存快照
bridge.save_prediction_snapshot(world)

# 2. 立即预测执行
ecb.spawn() ...
ecb.apply_to(world)

# 3. 服务器响应后
func _on_server_response(confirmed: bool) -> void:
    if confirmed:
        bridge.confirm_prediction()
    else:
        # 回滚并应用服务器权威状态
        bridge.rollback_prediction(world)
        _apply_server_state(world, server_data)
```

## See Also

- [GF_EcsSnapshot](./gf_ecs_snapshot.md) -- 世界快照系统（预测/回滚的基础设施）
- [GF_EcsWorld](./gf_ecs_world.md) -- ECS 世界
