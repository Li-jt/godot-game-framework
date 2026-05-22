## ThreadJobHandle
## 线程任务句柄。对外提供取消、状态查询、结果读取等主线程接口。
class_name ThreadJobHandle
extends RefCounted

var job_id: int = 0
var job_name: String = ""
var _service_ref: WeakRef = null


## 绑定服务引用。仅 ThreadingService 内部使用。
func bind(p_service: ThreadingService) -> void:
	_service_ref = weakref(p_service)


## 请求取消当前任务。
func cancel(p_reason: String = "cancelled_by_handle") -> OperationResult:
	var service := _get_service()
	if service == null:
		return OperationResult.fail(OperationResult.ERR_DISPOSED, "ThreadingService 不可用", "ThreadJobHandle")
	return service.cancel_job(job_id, p_reason)


## 查询任务状态枚举值（ThreadJobState.Value）。
func get_state() -> int:
	var service := _get_service()
	if service == null:
		return ThreadJobState.Value.FAILED
	return service.get_job_state(job_id)


## 查询任务是否结束（成功/失败/取消/超时）。
func is_done() -> bool:
	return ThreadJobState.is_terminal(get_state())


## 查询任务摘要。
func get_summary() -> ThreadJobSummary:
	var service := _get_service()
	if service == null:
		return null
	return service.get_job_summary(job_id)


## 查询任务最终结果（若未完成返回 null）。
func get_result() -> OperationResult:
	var summary := get_summary()
	if summary == null:
		return null
	if not ThreadJobState.is_terminal(summary.state):
		return null
	return summary.result


## 内部：解析 ThreadingService 实例。
func _get_service() -> ThreadingService:
	if _service_ref == null:
		return null
	return _service_ref.get_ref() as ThreadingService

