## ThreadJobCallbacks
## 线程任务回调集合。所有回调均在主线程触发。
## 回调签名统一为：func(summary: ThreadJobSummary) -> void
class_name ThreadJobCallbacks
extends RefCounted

## 任务成功时触发。
var on_completed: Callable = Callable()
## 任务失败时触发。
var on_failed: Callable = Callable()
## 任务取消时触发。
var on_cancelled: Callable = Callable()
## 任务超时时触发。
var on_timeout: Callable = Callable()
## 任务进入任意终态时触发。
var on_finished: Callable = Callable()

