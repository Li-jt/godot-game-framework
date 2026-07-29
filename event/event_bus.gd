## GF_EventBus
## 事件总线。支持 EventScope、GF_EventToken 和 GF_EventDef。
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


func _on_init() -> GF_OperationResult:
	return GF_OperationResult.ok()


func _on_dispose() -> GF_OperationResult:
	_listeners.clear()
	_tokens.clear()
	_pending_removes.clear()
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


## 订阅一次性事件
func subscribe_once(p_event: String, p_callback: Callable, p_scope: String = "global") -> GF_EventToken:
	var token: GF_EventToken
	var wrapper := func(p_data = null):
		unsubscribe_token(token.id)
		p_callback.call(p_data)
	token = subscribe(p_event, wrapper, p_scope)
	return token


## 订阅事件（GF_EventDef，类型安全）。
func subscribe_def(p_def: GF_EventDef, p_callback: Callable, p_scope: String = "global") -> GF_EventToken:
	return subscribe(p_def.event_name, p_callback, p_scope)


## 一次性订阅（GF_EventDef）。
func subscribe_once_def(p_def: GF_EventDef, p_callback: Callable, p_scope: String = "global") -> GF_EventToken:
	return subscribe_once(p_def.event_name, p_callback, p_scope)


## 事件是否有监听者（GF_EventDef）。
func has_listeners_def(p_def: GF_EventDef) -> bool:
	return has_listeners(p_def.event_name)


## 事件监听者数量（GF_EventDef）。
func listener_count_def(p_def: GF_EventDef) -> int:
	return listener_count(p_def.event_name)


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

## 发布事件（字符串名，向后兼容）。
func publish(p_event: String, p_data = null) -> void:
	_dispatch(p_event, null, p_data)


## 发布事件（GF_EventDef，类型安全）。
func publish_def(p_def: GF_EventDef, p_data = null) -> void:
	_dispatch(p_def.event_name, p_def, p_data)


func _dispatch(p_event: String, p_def: GF_EventDef, p_data) -> void:
	if not _listeners.has(p_event):
		return

	var arr: Array = _listeners[p_event]
	if arr.is_empty():
		return

	# Payload 校验（仅在设置了校验器时）
	if p_def != null and not p_def.validate(p_data):
		push_warning("GF_EventBus: payload 校验失败 — %s" % p_event)

	_dispatching = p_event
	for entry in arr.duplicate():
		if _pending_removes.has(entry.token_id):
			continue
		entry.callback.call(p_data)
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
