## InputProvider — 输入事件收集器 Node（v3.0）。
## _unhandled_input 在某些场景树结构下不触发鼠标事件（Godot 4 已知问题）。
## 改用 _input 处理所有事件，空间 UI 检测后续版本完善。
class_name InputProvider
extends Node

var _resolver: ActionResolver = null


func configure(p_resolver: ActionResolver) -> void:
	_resolver = p_resolver
	set_process(true)


func _ready() -> void:
	set_process(true)


## _input 在 GUI 处理前接收所有原始事件。
func _input(p_event: InputEvent) -> void:
	if _resolver != null:
		_resolver.process_event(p_event)


## 每帧结束所有动作的合成计算。
func _process(p_delta: float) -> void:
	if _resolver != null:
		_resolver.end_frame(p_delta)
