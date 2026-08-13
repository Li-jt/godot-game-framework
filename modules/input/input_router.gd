## GF_InputRouter — 输入路由器 Node。
## 使用 _unhandled_input 接收事件：GUI 消费的事件不会到达此处，
## Godot 原生 mouse_filter 自动生效，框架无需手动模拟 GUI hit-test。
class_name GF_InputRouter
extends Node

var _resolver: GF_ActionResolver = null
var _enabled: bool = true


func configure(p_resolver: GF_ActionResolver) -> void:
	_resolver = p_resolver
	set_process(true)


func _ready() -> void:
	if _resolver != null:
		set_process(true)


## GUI 未消费的事件在此处理。按钮点击等已被 Godot GUI 消费的事件不会到达。
## 事件阶段永远在 _process 之前，本帧事件累积完由 _process 统一结算。
func _unhandled_input(p_event: InputEvent) -> void:
	if _resolver == null or not _enabled:
		return
	_resolver.feed_event(p_event)


## 每帧结算：finalize 本帧累积 → 立即重置状态供下一帧累积。
## begin_frame 必须每帧执行：仅在事件帧 begin 会让 just_pressed
## 在无事件帧粘住（残留 accum 被反复 finalize → 按住键每帧重复触发）。
func _process(p_delta: float) -> void:
	if _resolver == null or not _enabled:
		return
	_resolver.end_frame(p_delta)
	_resolver.begin_frame()


func set_enabled(p_enabled: bool) -> void:
	_enabled = p_enabled
