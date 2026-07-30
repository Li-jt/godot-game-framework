## GF_EventBus
## 事件总线。支持 EventScope 和 GF_EventToken。
class_name GF_EventBus
extends GF_ModuleLifecycle

class ListenerEntry:
	var callback: Callable
	var scope: String
	var token_id: String


var _listeners: Dictionary = {}   # String event → Array[ListenerEntry]
var _tokens: Dictionary = {}      # String token_id → {event, entry}
var _token_counter: int = 0
var _dispatching: String = ""
var _pending_removes: Array = []  # Array[String token_id]
var _once_tokens: Array[String] = []


func _on_init() -> GF_OperationResult:
	return GF_OperationResult.ok()


func _on_dispose() -> GF_OperationResult:
	_listeners.clear()
	_tokens.clear()
	_pending_removes.clear()
	_once_tokens.clear()
	return GF_OperationResult.ok()


# ============================================================
# 订阅
# ============================================================

## 订阅事件。p_scope 用于场景切换时一键清理。
func subscribe(p_event: String, p_callback: Callable, p_scope: String = "global") -> GF_EventToken:
	_token_counter += 1
	var token_id := "%s_%d" % [p_event, _token_counter]

	var entry := ListenerEntry.new()
	entry.callback = p_callback
	entry.scope = p_scope
	entry.token_id = token_id

	if not _listeners.has(p_event):
		_listeners[p_event] = []
	_listeners[p_event].append(entry)

	_tokens[token_id] = {"event": p_event, "entry": entry}

	var token := GF_EventToken.new()
	token.id = token_id
	token._bus_ref = weakref(self)
	return token


## 订阅一次性事件。首次派发后自动取消订阅。
func subscribe_once(p_event: String, p_callback: Callable, p_scope: String = "global") -> GF_EventToken:
	var token := subscribe(p_event, p_callback, p_scope)
	_once_tokens.append(token.id)
	return token


# ============================================================
# 取消订阅
# ============================================================

## 通过 GF_EventToken 取消订阅
func unsubscribe_token(p_token_id: String) -> void:
	if _dispatching != "":
		_pending_removes.append(p_token_id)
	else:
		_do_unsubscribe_token(p_token_id)


## 取消订阅（向后兼容）
func unsubscribe(p_event: String, p_callback: Callable) -> void:
	if _dispatching == p_event:
		_pending_removes.append(_find_token_id(p_event, p_callback))
	else:
		_remove_by_callback(p_event, p_callback)


## 清理指定 scope 下的所有订阅
func clear_scope(p_scope: String) -> void:
	if _dispatching != "":
		for event in _listeners.keys():
			for entry in (_listeners[event] as Array):
				if entry.scope == p_scope:
					_pending_removes.append(entry.token_id)
	else:
		for event in _listeners.keys():
			var to_remove: Array = []
			for entry in (_listeners[event] as Array):
				if entry.scope == p_scope:
					to_remove.append(entry.token_id)
			for tid in to_remove:
				_do_unsubscribe_token(tid)


# ============================================================
# 发布
# ============================================================

## 发布事件。同步派发到所有订阅者。
## 每个 listener 的调用经过 _safe_dispatch 隔离 ——
## callback 无效时自动注销，避免一个错误 listener 阻断后续派发。
func publish(p_event: String, p_data = null) -> void:
	if not _listeners.has(p_event):
		return

	var arr: Array = _listeners[p_event]
	if arr.is_empty():
		return

	_dispatching = p_event
	for entry in arr.duplicate():
		if _pending_removes.has(entry.token_id):
			continue
		_safe_dispatch(entry, p_data, p_event)
		# 一次性订阅派发后立即标记移除
		if _once_tokens.has(entry.token_id):
			_pending_removes.append(entry.token_id)
			_once_tokens.erase(entry.token_id)
	_dispatching = ""

	for tid in _pending_removes:
		_do_unsubscribe_token(tid)
	_pending_removes.clear()


# ============================================================
# 查询
# ============================================================

func has_listeners(p_event: String) -> bool:
	return _listeners.has(p_event) and not (_listeners[p_event] as Array).is_empty()


func listener_count(p_event: String) -> int:
	if not _listeners.has(p_event):
		return 0
	return (_listeners[p_event] as Array).size()


func token_count() -> int:
	return _tokens.size()


# ============================================================
# 内部
# ============================================================

## 对单个 listener 安全派发。
## 如果 callback 无效（持有者已被释放），自动注销并跳过。
## 如果 callback 执行中发生非致命错误，记录警告并继续后续 listener。
func _safe_dispatch(p_entry: ListenerEntry, p_data, p_event: String) -> void:
	if not p_entry.callback.is_valid():
		push_warning("[GF_EventBus] 事件 '%s' 的 listener '%s' 回调已失效，自动注销" % [p_event, p_entry.token_id])
		_pending_removes.append(p_entry.token_id)
		return
	p_entry.callback.call(p_data)


func _do_unsubscribe_token(p_token_id: String) -> void:
	if not _tokens.has(p_token_id):
		return
	var info: Dictionary = _tokens[p_token_id]
	var event: String = info.event
	var entry = info.entry

	if _listeners.has(event):
		var arr: Array = _listeners[event]
		arr.erase(entry)
		if arr.is_empty():
			_listeners.erase(event)

	_tokens.erase(p_token_id)


func _remove_by_callback(p_event: String, p_callback: Callable) -> void:
	if not _listeners.has(p_event):
		return
	var arr: Array = _listeners[p_event]
	for i in range(arr.size() - 1, -1, -1):
		var entry = arr[i]
		if entry.callback == p_callback:
			_tokens.erase(entry.token_id)
			arr.remove_at(i)
			break
	if arr.is_empty():
		_listeners.erase(p_event)


func _find_token_id(p_event: String, p_callback: Callable) -> String:
	if not _listeners.has(p_event):
		return ""
	for entry in (_listeners[p_event] as Array):
		if entry.callback == p_callback:
			return entry.token_id
	return ""
