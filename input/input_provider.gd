## InputProvider — 输入事件收集器 Node（v3.0）。
## _unhandled_input 收集事件 → ActionResolver 匹配绑定。
## _process 调用 end_frame 合成输出值。
## begin_frame 在每帧第一个 _unhandled_input 事件时执行，清零上帧残留。
class_name InputProvider
extends Node

var _resolver: ActionResolver = null
var _last_frame: int = -1


func configure(p_resolver: ActionResolver) -> void:
	_resolver = p_resolver
	set_process_input(true)
	set_process(true)


func _ready() -> void:
	if _resolver != null:
		set_process_input(true)
		set_process(true)


func _unhandled_input(p_event: InputEvent) -> void:
	if _resolver == null:
		return
	var current_frame := Engine.get_process_frames()
	if current_frame != _last_frame:
		_last_frame = current_frame
		for state in _resolver._states.values():
			state.begin_frame()
	_resolver.process_event(p_event)


func _process(p_delta: float) -> void:
	if _resolver == null:
		return
	for state in _resolver._states.values():
		state.end_frame(p_delta)
