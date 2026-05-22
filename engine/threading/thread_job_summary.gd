## ThreadJobSummary
## 线程任务执行摘要。用于句柄查询、日志输出、回调参数与调试面板展示。
class_name ThreadJobSummary
extends RefCounted

var job_id: int = 0
var name: String = ""
var tag: String = ""
var state: int = ThreadJobState.Value.QUEUED
var attempts: int = 0
var submitted_at_ms: int = 0
var started_at_ms: int = -1
var finished_at_ms: int = -1
var timeout_ms: int = 0
var cancel_reason: String = ""
var metadata: Dictionary = {}
var result: OperationResult = null


## 计算任务总耗时（毫秒）。
func duration_ms() -> int:
	if started_at_ms < 0 or finished_at_ms < 0:
		return -1
	return maxi(0, finished_at_ms - started_at_ms)


## 返回任务状态文本。
func status_text() -> String:
	return ThreadJobState.to_text(state)


## 转换为字典，便于 UI/日志展示。
func to_dict() -> Dictionary:
	return {
		"job_id": job_id,
		"name": name,
		"tag": tag,
		"state": state,
		"status_text": status_text(),
		"attempts": attempts,
		"submitted_at_ms": submitted_at_ms,
		"started_at_ms": started_at_ms,
		"finished_at_ms": finished_at_ms,
		"duration_ms": duration_ms(),
		"timeout_ms": timeout_ms,
		"cancel_reason": cancel_reason,
		"metadata": metadata.duplicate(true),
		"status_code": result.status_code if result != null else 0,
		"error_message": result.error.message if result != null and result.error != null else "",
	}

