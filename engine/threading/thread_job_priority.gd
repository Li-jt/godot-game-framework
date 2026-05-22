## ThreadJobPriority
## 线程任务优先级定义。数值越小优先级越高。
## 统一用于 ThreadingService 的任务排队与调度。
class_name ThreadJobPriority
extends RefCounted

enum Level {
	CRITICAL = 0,
	HIGH = 10,
	NORMAL = 50,
	LOW = 100,
	BACKGROUND = 200,
}


## 判断当前优先级是否应映射到 WorkerThreadPool 的高优先级通道。
static func is_high_priority(p_priority: int) -> bool:
	return p_priority <= Level.HIGH

