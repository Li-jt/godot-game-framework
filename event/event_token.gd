## EventToken
## 订阅令牌。由 EventBus.subscribe() 返回，用于取消订阅。
class_name EventToken
extends RefCounted

var id: String = ""
var _bus_ref: WeakRef = null

## 取消此订阅
func unsubscribe() -> void:
	var bus: EventBus = _bus_ref.get_ref() if _bus_ref != null else null
	if bus != null:
		bus.unsubscribe_token(id)
