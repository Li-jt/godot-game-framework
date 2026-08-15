# 纯数据任务（后台线程）提交模式

> 适用版本: 0.3.0 | 对应服务: `GF_ThreadingService` | 路线图: 性能优化路线图 §6

## 模式

把可并行的纯计算搬到后台线程，主线程只做调度与结果回收：

```
主线程                         子线程
──────                        ──────
submit(work_fn)  ──────────►  执行 work_fn(token)
（立即返回 job_id）
  ...
pump() 每帧调用  ◄──────────  结果进入完成队列
（分发新任务 + 回收结果）
```

适用：存档序列化、气候/生态计算、地图数据预处理、路径图重建等
**无主线程依赖的纯计算**。

## 装配

```gdscript
# _assemble() 中注册 ThreadingService，并把 pump 挂到 Scheduler FRAME 组
register(GF_ThreadingService.new())

# _on_ready() 中
var threading := service(GF_ThreadingService)
var scheduler := service(GF_Scheduler)
scheduler.register(GF_Scheduler.TickGroup.FRAME, "ThreadingPump",
    func(_d: float): threading.pump(0.0))

# 可选：线程统计接入性能面板（性能路线图 §6 一代收尾）
service(GF_DebugService).attach_threading_service(threading)
```

## 提交与回收

```gdscript
## 提交纯数据任务。work 签名: func(token: GF_ThreadJobToken) -> Variant
var result := threading.submit(func(token: GF_ThreadJobToken) -> Variant:
    # 只在子线程做纯数据计算——禁止碰 ECS World、Node、UI
    return _serialize_chunk_data(chunk_id)
)
if result.is_fail():
    _log.error("Threading", "任务提交失败: %s" % result.error.message)
    return

var job_id: int = result.data
# 结果如何回传由 GF_ThreadJobOptions 决定（回调 / 查询 get_job_result）
```

## 硬约束（违反即数据竞争）

1. **子线程只做纯数据计算**：不读写真 ECS World、不碰 Node 树、不改 UI；
2. **ECS 世界写入必须在主线程**（系统 tick / ECB apply 路径）；
3. **跨线程边界传递快照**：传进子线程的数据应是独立副本（或只读且
   主线程在任务期间不修改）；回传结果经 Mutex 或完成队列回主线程；
4. **异步回调中检查对象有效性**：`is_instance_valid()` 后再访问 Node。

## 统计观测

`attach_threading_service` 接线后，DebugService 每帧自动记录
`threading.submitted` / `threading.queue_peak` / `threading.avg_duration_ms` 等
子系统项，性能面板可见——定位「队列堆积」或「单任务过重」用
`queue_peak`（堆积）与 `avg_duration_ms`（过重）两个指标。
