# 子线程任务

## 概述

GF_ThreadingService 提供框架级的线程任务管理，支持优先级调度、超时处理、重试机制和主线程回调。业务层提交"纯数据计算任务"，在子线程执行后通过 `pump()` 在主线程回收结果。

## 架构概览

```
Game 层                     GF_ThreadingService               WorkerThreadPool
  │                              │                                │
  ├─ submit(work, options) ──────┤                                │
  │                              ├─ 入队 → 排序                   │
  │                              │                                │
  │  pump(delta) ────────────────┤                                │
  │                              ├─ dispatch ────────────────────→│
  │                              │                                ├─ 执行 work(token)
  │                              │                                │
  │  pump(delta) ────────────────┤                                │
  │                              ├─ collect ←─────────────────────┤
  │                              ├─ 触发 callbacks                │
  │                              │                                │
  │  (通过 handle/callback) ←────┤                                │
```

## 关键类

| 类 | 职责 |
|---|------|
| `GF_ThreadingService` | 任务队列管理、调度、统计、取消 |
| `GF_ThreadJobOptions` | 任务配置：优先级、超时、重试、标签、回调 |
| `GF_ThreadJobToken` | 运行中任务的协作式取消令牌 |
| `GF_ThreadJobHandle` | `submit()` 返回的句柄，用于查询和取消 |
| `GF_ThreadJobCallbacks` | 主线程回调集合 |
| `GF_ThreadJobSummary` | 任务完成后的摘要快照 |

## ThreadJobOptions 配置详解

```gdscript
var options := GF_ThreadJobOptions.new()
options.name = "pathfinding_batch"           # 调试名称
options.priority = GF_ThreadJobPriority.Level.NORMAL  # LOW / NORMAL / HIGH / CRITICAL
options.tag = "ai"                           # 用于批量取消/统计分组
options.timeout_ms = 5000                    # 超时（-1 使用默认值，默认 30000ms）
options.max_retries = 2                      # 失败后重试次数
options.retry_backoff_ms = 200               # 重试等待基数
options.metadata = {"map_id": "forest_01"}   # 调试元数据
```

### 优先级说明

| 级别 | 常量 | 说明 |
|------|------|------|
| 低 | `GF_ThreadJobPriority.Level.LOW` | 非关键计算（统计数据） |
| 普通 | `GF_ThreadJobPriority.Level.NORMAL` | 常规计算任务 |
| 高 | `GF_ThreadJobPriority.Level.HIGH` | 影响体验的及时任务 |
| 关键 | `GF_ThreadJobPriority.Level.CRITICAL` | 阻塞性关键任务 |

## submit() 提交任务

任务函数签名为 `func(token: GF_ThreadJobToken) -> Variant | GF_OperationResult`。

如果函数无参数，框架不会传入 token（跳过取消检查）。如果需要支持取消，函数应接收一个 token 参数。

```gdscript
# 通过 scheduler 在每帧主循环中调用 pump
func _on_frame(delta: float) -> void:
    services.threading.pump(delta)


# 提交任务
func request_pathfinding(p_start: Vector2, p_end: Vector2) -> GF_ThreadJobHandle:
    var options := GF_ThreadJobOptions.new()
    options.name = "pathfinding"
    options.priority = GF_ThreadJobPriority.Level.HIGH
    options.timeout_ms = 3000
    options.callbacks.on_completed = _on_path_found
    options.callbacks.on_failed = _on_path_failed

    # 捕获数据（子线程不能直接使用闭包捕获的外部变量）
    var task_data := {"start": p_start, "end": p_end, "map": _current_map_data}

    var result := services.threading.submit(
        func(token: GF_ThreadJobToken) -> Variant:
            return _compute_path(task_data, token),
        options
    )

    if result.is_fail():
        _log.error("Pathfinding", "任务提交失败: %s" % result.error.message)
        return null
    return result.data as GF_ThreadJobHandle
```

## pump() 主线程回收结果

`pump()` 必须在主线程每帧调用。它完成以下工作：

1. 收集已完成的后台任务
2. 处理运行中任务的超时
3. 按优先级和预算分发新任务
4. 触发主线程回调（`on_completed` / `on_failed` / `on_cancelled` / `on_timeout`）

推荐通过 GF_Scheduler 注册一个 FRAME 组的回调来驱动 pump：

```gdscript
scheduler.register_frame_callback(Callable(services.threading, "pump"), "threading_pump")
```

## ThreadJobToken 合作式取消

取消是**合作式**的：调用 `cancel_job()` 后，框架设置取消标志，子线程任务需要定期检查 `token.is_cancel_requested()` 并自行退出。

```gdscript
func _compute_path(p_data: Dictionary, p_token: GF_ThreadJobToken) -> Array:
    var path: Array = []
    var max_iterations := 10000

    for i in max_iterations:
        # 周期性检查取消
        if i % 100 == 0:
            if p_token != null and p_token.is_cancel_requested():
                return []  # 被取消，返回空路径

        # 寻路单步
        var next := _step_pathfinding(p_data, path)
        if next == Vector2.INF:
            break
        path.append(next)

    return path
```

### 取消 API

```gdscript
# 取消单个任务
threading.cancel_job(job_id, "不再需要该路径")

# 按标签批量取消
threading.cancel_by_tag("ai", "AI 系统重置")

# 取消全部未完成任务
threading.cancel_all("场景切换")
```

## 线程安全的约束

子线程任务是纯数据计算，**绝对不能**做以下操作：

| 禁止操作 | 原因 |
|---------|------|
| 访问 Node / 场景树 | Godot 场景树不是线程安全的 |
| 读写 ECS World | ECS 数据只在主线程修改 |
| 操作 UI 控件 | UI 必须在主线程 |
| 调用 `queue_free()` | Node 操作必须在主线程 |
| 加载资源 (`load()`) | 资源加载不是线程安全的 |
| 使用 `call_deferred()` | 此方法依赖场景树 |

**允许的操作：**
- 纯数学计算（路径搜索、几何运算、数据转换）
- 读写 Dictionary / Array（仅限任务创建的独立数据）
- 字符串处理
- 数据序列化/反序列化

## 最佳实践

1. **任务数据打包传递。** 子线程任务函数不应该捕获外部变量，应将所需数据打包传入。

2. **设置合理的超时。** 寻路等算法应设置超时，避免一个任务卡死整个线程池。

3. **使用 tag 分组管理。** 场景切换时按标签批量取消，避免僵尸任务。

4. **结果在主线程消费。** 通过 `on_completed` 回调，在主线程安全地更新 ECS World 或 UI。

5. **检查 token 取消。** 长时间运行的任务应周期性检查 `token.is_cancel_requested()`。

6. **失败重试要有上限。** 避免无限重试耗尽资源。

## 完整示例：后台 A* 寻路 + 主线程应用结果

```gdscript
# pathfinding_manager.gd
class_name PathfindingManager
extends RefCounted

var _threading: GF_ThreadingService = null
var _ecs_world: GF_EcsWorld = null
var _log: GF_LogService = null
var _pathfinder: GF_Pathfinder = null
var _pending_jobs: Dictionary = {}  # {job_id: entity}


func configure(p_services: GF_GameServices) -> void:
    _threading = p_services.threading
    _ecs_world = p_services.ecs_world
    _log = p_services.log
    _pathfinder = GF_Pathfinder.new()


func request_path(p_entity: int, p_target: Vector2) -> void:
    var start: Vector2 = _get_entity_position(p_entity)
    var map := _build_map_snapshot()  # 打包地图数据用于子线程

    var options := GF_ThreadJobOptions.new()
    options.name = "path_%d" % p_entity
    options.priority = GF_ThreadJobPriority.Level.NORMAL
    options.timeout_ms = 2000
    options.metadata = {"entity": p_entity}
    options.callbacks.on_completed = func(summary: GF_ThreadJobSummary):
        _on_path_completed(summary)

    var result := _threading.submit(
        func(token: GF_ThreadJobToken) -> Array:
            return _find_path(map, start, p_target, token),
        options
    )

    if result.is_ok():
        var handle := result.data as GF_ThreadJobHandle
        _pending_jobs[handle.job_id] = p_entity


## 核心寻路算法（在子线程执行）
func _find_path(p_map: Dictionary, p_start: Vector2, p_end: Vector2, p_token: GF_ThreadJobToken) -> Array:
    # 传入的是地图快照的副本，线程安全
    var open_list: Array = []
    var closed: Dictionary = {}
    # ... A* 实现 ...

    var iterations := 0
    while not open_list.is_empty():
        iterations += 1
        if iterations % 50 == 0:
            if p_token != null and p_token.is_cancel_requested():
                return []

        # ... 寻路步骤 ...

    return _reconstruct_path(closed, p_end)


## 主线程回调：将路径写入 ECS
func _on_path_completed(p_summary: GF_ThreadJobSummary) -> void:
    var entity: int = _pending_jobs.get(p_summary.job_id, 0)
    _pending_jobs.erase(p_summary.job_id)

    if entity == 0:
        return

    if p_summary.result.is_ok():
        var path: Array = p_summary.result.data
        var ecb := _ecs_world.create_command_buffer()
        ecb.set_component(entity, &"Path", {"waypoints": path, "index": 0})
        ecb.apply(_ecs_world)
        _log.info("Pathfinding", "寻路完成 entity=%d, 路径点数=%d" % [entity, path.size()])
    else:
        _log.warning("Pathfinding", "寻路失败 entity=%d: %s" % [entity, p_summary.result.error.message])
```

## 查看运行状态

```gdscript
# 获取统计快照
var stats := threading.get_stats()
print("已完成: %d, 失败: %d, 取消: %d, 超时: %d" % [
    stats["completed"], stats["failed"], stats["cancelled"], stats["timed_out"]
])

# 获取最近完成的任务
var recent := threading.get_recent_history(10)
for summary in recent:
    print("%s: %s (%d ms)" % [summary.name, summary.status_text(), summary.duration_ms()])
```
