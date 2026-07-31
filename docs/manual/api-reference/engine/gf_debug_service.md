# GF_DebugService

> 适用版本: 0.3.0 | 继承: GF_DebugService → GF_ModuleLifecycle

## 概述

调试服务，管理调试面板注册、运行时性能统计、命令追踪和网络统计。所有调试功能仅在 `config.debug.enable_debug_panel = true` 时启用，生产环境关闭无开销。

**适用场景**：开发阶段需要实时监控 FPS、追踪命令执行历史、注册自定义调试面板。

**不适用场景**：生产环境建议关闭 `enable_debug_panel`；不应用于核心游戏逻辑的数据统计。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `enabled` | `bool` | `false` | 调试面板总开关，从 `config.debug.enable_debug_panel` 读取 |
| `command_trace_enabled` | `bool` | `false` | 命令追踪开关，从 `config.debug.show_prediction_state` 读取 |
| `panels` | `Dictionary` | `{}` | 已注册的调试面板，键为面板名称，值为工厂 Callable |
| `fps` | `float` | `0.0` | 每秒帧数（每 1 秒更新一次） |
| `frame_time_ms` | `float` | `0.0` | 平均帧时间，单位毫秒（每 1 秒更新一次） |
| `network_requests` | `int` | `0` | 累计网络请求数 |
| `network_errors` | `int` | `0` | 累计网络错误数 |

## 公共方法

### configure(p_config: GF_AppConfig.DebugSection, p_log: GF_LogService) → GF_OperationResult

注入调试配置和日志服务。在 `_on_configure()` 阶段由 Application 层调用。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_config` | `GF_AppConfig.DebugSection` | 调试配置段，提供 `enable_debug_panel` 和 `show_prediction_state` |
| `p_log` | `GF_LogService` | 日志服务 |

**返回值：**

- `GF_OperationResult.ok()` — 配置成功，`enabled` 和 `command_trace_enabled` 从配置同步
- `GF_OperationResult.fail(ERR_BAD_REQUEST, ...)` — 任一参数为 null

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| `ERR_BAD_REQUEST` | `p_config` 为 null |
| `ERR_BAD_REQUEST` | `p_log` 为 null |

**示例：**

```gdscript
var debug := GF_DebugService.new()
var result := debug.configure(app_config.debug, log)
if result.is_fail():
    return result
```

---

### register_panel(p_name: String, p_factory: Callable) → void

注册一个调试面板。面板通过工厂 Callable 创建，在调试 UI 中按名称选择显示。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_name` | `String` | 面板名称，在调试 UI 中显示。重名会覆盖之前的注册 |
| `p_factory` | `Callable` | 无参工厂函数，返回一个 `Node` 实例作为调试面板 |

**示例：**

```gdscript
debug.register_panel("ECS Stats", func() -> Node:
    var panel := preload("res://debug/ecs_stats_panel.tscn").instantiate()
    return panel
)

debug.register_panel("Memory", func() -> Node:
    var label := Label.new()
    label.name = "MemoryPanel"
    return label
)
```

---

### get_panel_names() → Array[String]

获取所有已注册的调试面板名称。

**返回值：** 面板名称的字符串数组，顺序与注册顺序一致。

**示例：**

```gdscript
for name in debug.get_panel_names():
    print("注册的调试面板: %s" % name)
```

---

### tick_stats(p_delta: float) → void

由 `GF_Scheduler` 的 `TickGroup.DEBUG` 每帧调用，累积帧计数和耗时。每累计 1 秒后更新 `fps` 和 `frame_time_ms` 属性，然后重置计数器。

当 `enabled == false` 时直接返回，不做任何计算。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_delta` | `float` | 帧间隔时间，单位秒 |

**示例：**

```gdscript
# 通常由 Scheduler 自动调用，不需要手动调用
# GF_Scheduler 注册时：
scheduler.register_system(debug.tick_stats, GF_Scheduler.TickGroup.DEBUG)

# 在别处读取统计：
print("FPS: %.1f, Frame: %.2fms" % [debug.fps, debug.frame_time_ms])
```

---

### trace_command(p_id: String, p_type: String, p_state: String = "executed") → void

记录一条命令执行追踪。当 `command_trace_enabled == false` 时直接返回。最多保留 200 条历史记录（FIFO）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_id` | `String` | 命令唯一标识符 |
| `p_type` | `String` | 命令类型，如 `"Move"`、`"Attack"`、`"Build"` |
| `p_state` | `String` | 命令状态，默认 `"executed"`，可传入 `"queued"`、`"failed"` 等 |

**示例：**

```gdscript
# 在命令执行后追踪
debug.trace_command(cmd.id, "Build", "queued")
# ... 执行逻辑 ...
debug.trace_command(cmd.id, "Build", "executed")

# 失败时记录
debug.trace_command(cmd.id, "Attack", "failed")
```

---

### get_command_history() → Array

获取所有被追踪的命令历史记录。

**返回值：** `Array[Dictionary]`，每个元素包含以下字段：

| 字段 | 类型 | 描述 |
|------|------|------|
| `id` | `String` | 命令 ID |
| `type` | `String` | 命令类型 |
| `state` | `String` | 命令状态 |
| `time` | `String` | 记录时间（`Time.get_datetime_string_from_system(false, true)` 格式） |

**示例：**

```gdscript
for entry in debug.get_command_history():
    print("[%s] %s: %s → %s" % [entry.time, entry.type, entry.id, entry.state])
```

---

### record_network_request(p_success: bool) → void

记录一次网络请求，累加 `network_requests` 计数。如果请求失败，同时累加 `network_errors` 计数。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_success` | `bool` | 请求是否成功 |

**示例：**

```gdscript
# 在网络请求完成后记录
var result := client.http_get("/api/data")
debug.record_network_request(result.is_ok())
```

---

### reset_network_stats() → void

重置网络统计数据，将 `network_requests` 和 `network_errors` 归零。

**示例：**

```gdscript
# 切换场景或重新开始游戏时重置
debug.reset_network_stats()
```

---

## See Also

- [GF_Scheduler](../core/gf_scheduler.md) — 调度器，在 DEBUG tick 组中驱动 `tick_stats()`
- [GF_AppConfig](../environment/gf_app_config.md) — 应用配置，提供 `DebugSection`
- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) — 模块生命周期基类
