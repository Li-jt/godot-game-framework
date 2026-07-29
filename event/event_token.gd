## GF_EventToken
## 订阅令牌。由 GF_EventBus.subscribe() 返回，用于取消订阅。
class_name GF_EventToken
extends RefCounted

var id: String = ""
var _bus_ref: WeakRef = null

## 取消此订阅
func unsubscribe() -> void:
	var bus: GF_EventBus = _bus_ref.get_ref() if _bus_ref != null else null
	if bus != null:
		bus.unsubscribe_token(id)
