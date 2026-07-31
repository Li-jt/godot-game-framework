# GF_ThreadingService

> 适用版本: 0.3.0 | 继承: GF_ThreadingService -> GF_ModuleLifecycle -> RefCounted

## 概述

框架级线程任务服务。提供任务队列、优先级调度、超时检测、重试退避、协作式取消、统计追踪和历史记录。业务层通过 `submit()` 提交纯数据计算任务到 WorkerThreadPool 后台执行。

适用场景：路径计算、数据序列化/反序列化、大量数据转换等耗时纯计算任务。禁止在子线程中操作场景树、UI 节点或 ECS World。

禁用线程模式：通过 `GF_AppConfig.ThreadingSection.enabled` 设为 `false` 时，任务在主线程同步执行，功能保持可用，方便调试和低端设备降级。

## 任务生命周期

```
submit → QUEUED → (dispatch) → RUNNING → (complete) → COMPLETED
                                              ↓ (fail, retries remain)
                                         RETRY_WAIT → (wait) → QUEUED → ...
                                              ↓ (fail, no retries)
                                            FAILED
                                              ↓ (cancel/timeout)
                                     CANCELLED / TIMEOUT
```

**调度策略:**
- 按优先级排序（`GF_ThreadJobPriority.Level`，数值越小优先级越高）
- 同优先级按提交时间（FIFO）
- 高优先级任务（CRITICAL、HIGH）使用 WorkerThreadPool 高优先级通道
- 每帧最多分发 `max_dispatch_per_tick` 个任务
- 同时最多运行 `max_active_jobs` 个任务

**重试策略:**
- 任务失败后自动重试（最多 `max_retries` 次）
- 每次重试等待 `retry_backoff_ms * 当前重试序号` 毫秒
- 重试期间状态为 `RETRY_WAIT`，到达 `next_dispatch_at_ms` 后重新入队

**超时检测:**
- 每帧 `pump()` 时检查运行中任务是否超过 `timeout_ms`
- 超时任务标记为 `TIMEOUT`，请求取消令牌，将后台线程任务加入 orphan 列表等待自然退出

**历史清理:**
- 默认保留最近 256 个终态任务记录
- 超出上限时按完成时间清理最早的任务

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `_enabled` | `bool` | `true` | 是否启用多线程。禁用时任务通过 `_execute_inline()` 在主线程同步执行 |
| `_max_active_jobs` | `int` | `4` | 最大并发任务数 |
| `_max_dispatch_per_tick` | `int` | `2` | 每帧最多分发任务数 |
| `_default_timeout_ms` | `int` | `30000` | 默认任务超时时间（毫秒） |
| `_slow_job_warn_ms` | `int` | `350` | 慢任务警告阈值（毫秒）。超过此阈值输出警告日志 |
| `_history_limit` | `int` | `256` | 终态任务历史记录上限 |

以上属性通过 `configure()` 从 `GF_AppConfig.ThreadingSection` 读取，不应手动设置。

## 公共方法

### configure(p_config: GF_AppConfig.ThreadingSection, p_log: GF_LogService) -> GF_OperationResult

配置线程服务。从配置文件读取并发数、超时、慢任务警告阈值等参数。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_config` | `GF_AppConfig.ThreadingSection` | 线程配置节（enabled、max_active_jobs、default_timeout_ms 等） |
| `p_log` | `GF_LogService` | 日志服务 |

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_BAD_REQUEST` | `p_config` 或 `p_log` 为 null |

---

### pump(_p_delta: float) -> void

每帧泵送。应在主线程逐帧调用（建议通过 GF_Scheduler 的 FRAME 组注册）。执行四个步骤：

1. **清理 orphan 任务** — 回收已终态但后台线程尚未退出的任务
2. **收集已完成任务** — 检查 `WorkerThreadPool.is_task_completed()`，获取结果并做终态/重试判断
3. **处理超时** — 检查运行中任务是否超时，超时则标记为 TIMEOUT
4. **分发新任务** — 按优先级从队列取任务提交到 WorkerThreadPool

**示例:**

```gdscript
# 通过 Scheduler 注册每帧泵送
scheduler.register(Scheduler.TickGroup.FRAME, "threading_pump", func(delta): threading_service.pump(delta))
```

---

### submit(p_work: Callable, p_options: GF_ThreadJobOptions = null) -> GF_OperationResult

提交线程任务。任务签名：`func(token: GF_ThreadJobToken) -> Variant | GF_OperationResult`。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_work` | `Callable` | 任务函数。接收 GF_ThreadJobToken 参数（若 token 已取消则提前退出）。返回普通 Variant 时自动包装为 `GF_OperationResult.ok(data)`；返回 `GF_OperationResult` 时直接使用 |
| `p_options` | `GF_ThreadJobOptions` | 任务选项（名称、优先级、标签、超时、重试、回调等）。为 null 时使用默认选项 |

**返回值:** 成功时 `data` 字段包含 `GF_ThreadJobHandle` 实例。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_PRECONDITION` | 服务未处于 READY 状态 |
| `ERR_BAD_REQUEST` | `p_work` 无效 |

**示例:**

```gdscript
# 提交 A* 寻路计算
var options := GF_ThreadJobOptions.new()
options.name = "find_path_%d" % entity_id
options.priority = GF_ThreadJobPriority.Level.HIGH
options.tag = "pathfinding"
options.timeout_ms = 5000
options.max_retries = 2
options.metadata = {"entity_id": entity_id}

var result := threading_service.submit(
    func(token: GF_ThreadJobToken) -> Variant:
        if token.is_cancel_requested():
            return GF_OperationResult.fail(-1, "cancelled")
        # 纯计算：A* 路径搜索
        return _astar_find(start, end, grid),
    options
)

if result.is_ok():
    var handle: GF_ThreadJobHandle = result.data
    # 保存 handle 供后续查询
```

---

### cancel_job(p_job_id: int, p_reason: String = "cancelled_by_request") -> GF_OperationResult

取消指定任务。采用协作式取消：

- **QUEUED / RETRY_WAIT 状态**: 立即从队列移除，标记为 CANCELLED
- **RUNNING 状态**: 通过 GF_ThreadJobToken 请求取消，立即进入终态。后台线程在检查 token 后自行退出
- **已终态**: 幂等返回成功

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_job_id` | `int` | 任务 ID |
| `p_reason` | `String` | 取消原因（用于日志和调试） |

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 任务不存在 |

**示例:**

```gdscript
var result := threading_service.cancel_job(job_id, "player_teleported")
```

---

### cancel_by_tag(p_tag: String, p_reason: String = "cancelled_by_tag") -> int

按标签批量取消任务。取消所有匹配标签的未终态任务（包括排队中和运行中）。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_tag` | `String` | 任务标签。空字符串时直接返回 0 |
| `p_reason` | `String` | 取消原因 |

**返回值:** 成功取消的任务数量。

**示例:**

```gdscript
# 取消所有寻路任务
var count := threading_service.cancel_by_tag("pathfinding", "world_unloaded")
_log.info("Threading", "已取消 %d 个寻路任务" % count)
```

---

### cancel_all(p_reason: String = "cancelled_all") -> int

取消所有未完成任务。遍历所有任务，取消处于非终态的任务。

**返回值:** 成功取消的任务数量。

**示例:**

```gdscript
# 场景切换时取消所有后台任务
var count := threading_service.cancel_all("scene_switching")
```

---

### get_job_state(p_job_id: int) -> int

查询任务状态。

**返回值:** `GF_ThreadJobState.Value` 枚举值。任务不存在时返回 `FAILED`。

---

### get_job_summary(p_job_id: int) -> GF_ThreadJobSummary

查询任务执行摘要快照。

**返回值:** `GF_ThreadJobSummary` 实例。任务不存在时返回 `null`。

---

### get_stats() -> Dictionary

获取运行时统计快照。返回字典的副本，不会受后续任务影响。

**返回字段:**

| 字段 | 类型 | 描述 |
|------|------|------|
| `submitted` | `int` | 已提交任务总数 |
| `completed` | `int` | 已完成任务数 |
| `failed` | `int` | 已失败任务数 |
| `cancelled` | `int` | 已取消任务数 |
| `timed_out` | `int` | 已超时任务数 |
| `retried` | `int` | 已重试次数 |
| `running_peak` | `int` | 历史最大并发数 |
| `queue_peak` | `int` | 历史最大排队数 |
| `avg_duration_ms` | `float` | 平均任务耗时（毫秒） |

**示例:**

```gdscript
var stats := threading_service.get_stats()
print("已完成: %d, 失败: %d, 平均耗时: %.1f ms" % [stats.completed, stats.failed, stats.avg_duration_ms])
```

---

### get_recent_history(p_limit: int = 20) -> Array[GF_ThreadJobSummary]

获取最近完成的终态任务摘要列表，按完成时间倒序排列（最新在前）。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_limit` | `int` | 最大返回数量，最小值为 1 |

---

### is_runtime_ready() -> bool

运行时就绪检查。委托给 `is_ready()`。

---

# 支持类型

## GF_ThreadJobOptions

> 继承: GF_ThreadJobOptions -> RefCounted

线程任务提交参数对象。用于控制优先级、超时、重试、标签与回调。

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `name` | `String` | `""` | 任务名称（用于日志与调试）。为空时自动生成 `"job_<id>"` |
| `priority` | `int` | `NORMAL` (50) | 任务优先级，使用 `GF_ThreadJobPriority.Level` |
| `tag` | `String` | `""` | 任务标签（用于批量取消/统计分组） |
| `timeout_ms` | `int` | `-1` | 超时时间（毫秒）。<= 0 时使用 GF_ThreadingService 默认值 |
| `max_retries` | `int` | `0` | 最大重试次数（失败后自动重试，不含首次执行） |
| `retry_backoff_ms` | `int` | `150` | 重试退避基准（毫秒）。实际等待 = retry_backoff_ms * 当前重试序号 |
| `metadata` | `Dictionary` | `{}` | 调试元数据（仅供主线程读取）。支持自定义字段如 `slow_warn_ms` 覆盖全局慢任务阈值 |
| `callbacks` | `GF_ThreadJobCallbacks` | `GF_ThreadJobCallbacks.new()` | 回调集合（全部在主线程触发） |

**方法:**

#### resolve_timeout_ms(p_default_timeout_ms: int) -> int

解析最终超时时间。若 `timeout_ms > 0` 则返回自身，否则返回传入的默认值。

---

## GF_ThreadJobHandle

> 继承: GF_ThreadJobHandle -> RefCounted

线程任务句柄。`submit()` 返回此对象，用于取消、状态查询和结果读取。内部通过 WeakRef 引用 GF_ThreadingService，Service 释放后仍可安全调用。

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `job_id` | `int` | `0` | 任务 ID |
| `job_name` | `String` | `""` | 任务名称 |

**方法:**

#### cancel(p_reason: String = "cancelled_by_handle") -> GF_OperationResult

请求取消任务。委托给 `GF_ThreadingService.cancel_job()`。

#### get_state() -> int

查询任务状态枚举值（`GF_ThreadJobState.Value`）。Service 不可用时返回 `FAILED`。

#### is_done() -> bool

查询任务是否已进入终态（COMPLETED / FAILED / CANCELLED / TIMEOUT）。

#### get_summary() -> GF_ThreadJobSummary

查询任务摘要快照。Service 不可用时返回 `null`。

#### get_result() -> GF_OperationResult

查询任务最终结果。任务未完成时返回 `null`。

---

## GF_ThreadJobToken

> 继承: GF_ThreadJobToken -> RefCounted

线程任务取消令牌。传入任务函数，用于协作式取消。内部使用 Mutex 保证线程安全，任务函数应周期性调用 `is_cancel_requested()` 检查并尽快退出。

**方法:**

#### request_cancel(p_reason: String = "cancelled_by_request") -> void

请求取消。重复调用会保留第一次设置的原因。

#### is_cancel_requested() -> bool

查询是否已收到取消请求。

#### cancel_reason() -> String

获取取消原因。

**示例:**

```gdscript
var result := threading_service.submit(
    func(token: GF_ThreadJobToken) -> Variant:
        for chunk in large_data:
            if token.is_cancel_requested():
                return GF_OperationResult.fail(-1, "cancelled: %s" % token.cancel_reason())
            _process_chunk(chunk)
        return _finalize(),
    options
)
```

---

## GF_ThreadJobState

> 继承: GF_ThreadJobState -> RefCounted

线程任务状态枚举。

| 枚举值 | 数值 | 描述 | 终态 |
|--------|------|------|------|
| `QUEUED` | 0 | 排队等待调度 | 否 |
| `RUNNING` | 1 | 正在执行 | 否 |
| `RETRY_WAIT` | 2 | 失败后等待重试 | 否 |
| `COMPLETED` | 3 | 成功完成 | 是 |
| `FAILED` | 4 | 失败（重试耗尽） | 是 |
| `CANCELLED` | 5 | 被取消 | 是 |
| `TIMEOUT` | 6 | 超时 | 是 |

**静态方法:**

#### is_terminal(p_state: int) -> bool

判断任务是否处于终态（COMPLETED / FAILED / CANCELLED / TIMEOUT）。

#### to_text(p_state: int) -> String

将状态枚举值转换为可读文本（"queued", "running", "retry_wait", "completed", "failed", "cancelled", "timeout", "unknown"）。

---

## GF_ThreadJobPriority

> 继承: GF_ThreadJobPriority -> RefCounted

线程任务优先级定义。数值越小优先级越高。

| 枚举值 | 数值 | 描述 |
|--------|------|------|
| `CRITICAL` | 0 | 关键任务（最高优先级，走 WorkerThreadPool 高优先级通道） |
| `HIGH` | 10 | 高优先级（走 WorkerThreadPool 高优先级通道） |
| `NORMAL` | 50 | 普通优先级（默认） |
| `LOW` | 100 | 低优先级 |
| `BACKGROUND` | 200 | 后台任务（最低优先级） |

**静态方法:**

#### is_high_priority(p_priority: int) -> bool

判断优先级是否应映射到 WorkerThreadPool 的高优先级通道（`<= HIGH`）。

---

## GF_ThreadJobCallbacks

> 继承: GF_ThreadJobCallbacks -> RefCounted

线程任务回调集合。所有回调均在主线程触发。回调签名统一为 `func(summary: GF_ThreadJobSummary) -> void`。

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `on_completed` | `Callable` | `Callable()` | 任务成功时触发 |
| `on_failed` | `Callable` | `Callable()` | 任务失败时触发 |
| `on_cancelled` | `Callable` | `Callable()` | 任务取消时触发 |
| `on_timeout` | `Callable` | `Callable()` | 任务超时时触发 |
| `on_finished` | `Callable` | `Callable()` | 任务进入任意终态时触发（在具体回调之后） |

**示例:**

```gdscript
var options := GF_ThreadJobOptions.new()
var callbacks := GF_ThreadJobCallbacks.new()
callbacks.on_completed = func(summary: GF_ThreadJobSummary):
    _log.info("Threading", "寻路完成: %s, 耗时 %d ms" % [summary.name, summary.duration_ms()])
callbacks.on_failed = func(summary: GF_ThreadJobSummary):
    _log.error("Threading", "寻路失败: %s" % summary.result.error.message)
options.callbacks = callbacks
```

---

## GF_ThreadJobSummary

> 继承: GF_ThreadJobSummary -> RefCounted

线程任务执行摘要。用于句柄查询、日志输出、回调参数与调试面板展示。

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `job_id` | `int` | `0` | 任务 ID |
| `name` | `String` | `""` | 任务名称 |
| `tag` | `String` | `""` | 任务标签 |
| `state` | `int` | `QUEUED` (0) | 任务状态（`GF_ThreadJobState.Value`） |
| `attempts` | `int` | `0` | 已执行次数（含当前/最后一次） |
| `submitted_at_ms` | `int` | `0` | 提交时间戳（`Time.get_ticks_msec()`） |
| `started_at_ms` | `int` | `-1` | 最近一次开始执行时间戳。未开始为 -1 |
| `finished_at_ms` | `int` | `-1` | 完成时间戳。未完成或未结束为 -1 |
| `timeout_ms` | `int` | `0` | 最终生效的超时时间（毫秒） |
| `cancel_reason` | `String` | `""` | 取消原因 |
| `metadata` | `Dictionary` | `{}` | 任务提交时的元数据副本 |
| `result` | `GF_OperationResult` | `null` | 任务最终结果。未完成时为 null |

**方法:**

#### duration_ms() -> int

计算任务最近一次执行的总耗时（毫秒）。未开始或未完成时返回 -1。

#### status_text() -> String

返回任务状态文本（委托给 `GF_ThreadJobState.to_text()`）。

#### to_dict() -> Dictionary

转换为字典，便于 UI/日志展示。包含 job_id、name、tag、state、status_text、attempts、各时间戳、duration_ms、timeout_ms、cancel_reason、metadata 副本、以及结果的状态码和错误消息。

## 使用示例

```gdscript
# 配置
var result := threading_service.configure(app_config.threading, log_service)
if result.is_fail():
    return result

# 注册每帧泵送
scheduler.register(Scheduler.TickGroup.FRAME, "threading_pump",
    func(delta): threading_service.pump(delta))

# 提交任务
var options := GF_ThreadJobOptions.new()
options.name = "heavy_computation"
options.timeout_ms = 10000
options.max_retries = 3

var submit_result := threading_service.submit(_heavy_work, options)
if submit_result.is_fail():
    return submit_result

var handle: GF_ThreadJobHandle = submit_result.data

# 稍后查询
if handle.is_done():
    var summary := handle.get_summary()
    if summary.state == GF_ThreadJobState.Value.COMPLETED:
        print("结果: ", summary.result.data)

# 批量取消
threading_service.cancel_by_tag("batch_task")

# 查看统计
var stats := threading_service.get_stats()
print("已完成: %d | 运行峰值: %d" % [stats.completed, stats.running_peak])
```

## See Also

- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) -- 服务生命周期基类
- [GF_OperationResult](../core/gf_operation_result.md) -- 统一操作结果类型
- [GF_Scheduler](./gf_scheduler.md) -- 统一 Tick 驱动器（用于注册 pump 调用）
