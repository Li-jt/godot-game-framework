## ThreadJobOptions
## 线程任务提交参数。用于控制优先级、超时、重试、标签与回调。
class_name ThreadJobOptions
extends RefCounted

## 任务名称（用于日志与调试）。
var name: String = ""
## 任务优先级（使用 ThreadJobPriority.Level）。
var priority: int = ThreadJobPriority.Level.NORMAL
## 任务标签（用于批量取消/统计分组）。
var tag: String = ""
## 超时时间（毫秒）。<= 0 时使用 ThreadingService 默认值。
var timeout_ms: int = -1
## 最大重试次数（失败后自动重试，不含首次执行）。
var max_retries: int = 0
## 重试退避基准（毫秒）。实际等待 = retry_backoff_ms * 当前重试序号。
var retry_backoff_ms: int = 150
## 调试元数据（仅主线程读取）。
var metadata: Dictionary = {}
## 回调集合（全部在主线程触发）。
var callbacks: ThreadJobCallbacks = ThreadJobCallbacks.new()


## 解析最终超时时间。
func resolve_timeout_ms(p_default_timeout_ms: int) -> int:
	return timeout_ms if timeout_ms > 0 else p_default_timeout_ms

