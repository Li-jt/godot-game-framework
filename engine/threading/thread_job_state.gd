## ThreadJobState
## 线程任务状态枚举与文本映射工具。
## 用于 ThreadingService、ThreadJobHandle、调试输出统一状态语义。
class_name ThreadJobState
extends RefCounted

enum Value {
	QUEUED = 0,
	RUNNING = 1,
	RETRY_WAIT = 2,
	COMPLETED = 3,
	FAILED = 4,
	CANCELLED = 5,
	TIMEOUT = 6,
}


## 判断任务是否处于终态。
static func is_terminal(p_state: int) -> bool:
	return p_state in [Value.COMPLETED, Value.FAILED, Value.CANCELLED, Value.TIMEOUT]


## 将任务状态转换为可读文本。
static func to_text(p_state: int) -> String:
	match p_state:
		Value.QUEUED: return "queued"
		Value.RUNNING: return "running"
		Value.RETRY_WAIT: return "retry_wait"
		Value.COMPLETED: return "completed"
		Value.FAILED: return "failed"
		Value.CANCELLED: return "cancelled"
		Value.TIMEOUT: return "timeout"
		_: return "unknown"

