## InputRouter — 输入路由器 Node（v4.0）。
## 统一入口：_input 采集所有 Godot 事件，_process 驱动每帧合成。
## 替代 v3.0 的 InputProvider。
class_name InputRouter
extends Node

var _resolver: ActionResolver = null
var _last_frame: int = -1
var _enabled: bool = true


func configure(p_resolver: ActionResolver) -> void:
	_resolver = p_resolver
	set_process(true)


func _ready() -> void:
	if _resolver != null:
		set_process(true)


## 所有原始事件在此采集。UI 消费不影响 _input 触发。
func _input(p_event: InputEvent) -> void:
	if _resolver == null or not _enabled:
		return

	var frame: int = Engine.get_process_frames()
	if frame != _last_frame:
		_last_frame = frame
		_resolver.begin_frame()

	_resolver.feed_event(p_event)


## 每帧结算：poll → gesture → compose → finalize。
func _process(p_delta: float) -> void:
	if _resolver == null or not _enabled:
		return
	_resolver.end_frame(p_delta)


func set_enabled(p_enabled: bool) -> void:
	_enabled = p_enabled
