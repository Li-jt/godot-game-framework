## GF_EventDef — 类型化事件定义。
## 将事件名和可选的 payload 校验器封装在一起，替代裸字符串。
## 编译时检查拼写，运行时校验 payload 结构。
##
## 使用方式：
##   [codeblock]
##   const FLOW_CHANGED := GF_EventDef.new(&"flow_state_changed")
##   const HEALTH_CHANGED := GF_EventDef.new(&"health_changed",
##       func(p): return p.has("hp") and p.has("max_hp"))
##
##   event_bus.publish(FLOW_CHANGED, {"from": "menu", "to": "game"})
##   event_bus.subscribe(HEALTH_CHANGED, _on_health_changed)
##   [/codeblock]
class_name GF_EventDef
extends RefCounted

## 事件名
var event_name: String = ""
## Payload 校验器（可选）。签名为 func(p_data) -> bool。
var _validator: Callable = Callable()


func _init(p_name: String, p_validator: Callable = Callable()) -> void:
	event_name = p_name
	_validator = p_validator


## 校验 payload。未设置校验器时始终返回 true。
func validate(p_data) -> bool:
	if not _validator.is_valid():
		return true
	return _validator.call(p_data)
