## GF_Events — 框架内置事件的集中定义。
## Game 层可以照此模式定义自己的事件集合类（如 GameEvents）。
##
## 使用方式：
##   [codeblock]
##   _event_bus.publish(GF_Events.FLOW_STATE_CHANGED, {"from": "menu", "to": "game"})
##   _event_bus.subscribe(GF_Events.FLOW_STATE_CHANGED, _on_flow_changed)
##   [/codeblock]
##
## 注意：GDScript 的 const 不能存 GF_EventDef.new()（非编译期常量），
## 因此使用 static var——类首次加载时初始化一次，行为与 const 等价。
class_name GF_Events
extends RefCounted

## AppFlow 状态变化。payload: {from: String, to: String, payload: Variant}
static var FLOW_STATE_CHANGED := GF_EventDef.new("flow_state_changed")
