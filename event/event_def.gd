## GF_EventDef — 类型化事件定义。
## 事件标识的唯一形式。GF_EventBus 的所有 API 接受此类型，
## 不接受裸字符串——拼写错误在编译期暴露。
##
## 定义事件时可通过 p_validator 声明 payload 结构校验，
## GF_EventBus.publish() 会自动执行，校验失败 fail fast 中止派发。
##
## 使用方式：
##   [codeblock]
##   # 框架事件集中在 GF_Events，Game 层照此模式建 GameEvents
##   static var FLOW_CHANGED := GF_EventDef.new("flow_state_changed")
##   static var HEALTH_CHANGED := GF_EventDef.new("health_changed",
##       func(p): return p is Dictionary and p.has("hp") and p.has("max_hp"))
##
##   event_bus.publish(FLOW_CHANGED, {"from": "menu", "to": "game"})
##   event_bus.subscribe(HEALTH_CHANGED, _on_health_changed)
##   [/codeblock]
class_name GF_EventDef
extends RefCounted

## 事件名（内部字典 key、日志、token_id 使用）
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
