## ThreadJobToken
## 线程任务取消令牌。用于运行中任务的协作式取消。
## 任务函数应周期性检查 token.is_cancel_requested() 并尽快退出。
class_name ThreadJobToken
extends RefCounted

var _cancel_requested: bool = false
var _cancel_reason: String = ""
var _mutex: Mutex = Mutex.new()


## 请求取消任务。重复调用会保留第一次取消原因。
func request_cancel(p_reason: String = "cancelled_by_request") -> void:
	_mutex.lock()
	if not _cancel_requested:
		_cancel_requested = true
		_cancel_reason = p_reason
	_mutex.unlock()


## 查询任务是否已收到取消请求。
func is_cancel_requested() -> bool:
	_mutex.lock()
	var value := _cancel_requested
	_mutex.unlock()
	return value


## 获取取消原因。
func cancel_reason() -> String:
	_mutex.lock()
	var reason := _cancel_reason
	_mutex.unlock()
	return reason

