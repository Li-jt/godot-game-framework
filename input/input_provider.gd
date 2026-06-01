## InputProvider — 输入事件收集器 Node（v3.0）。
## 挂到场景树，通过 _unhandled_input 收集所有未被 GUI 消费的原始事件，
## 交给 ActionResolver 解析。
##
## UI/游戏输入冲突自动解决：
##   Godot GUI 系统先处理事件 → Control（如 ScrollContainer）消费 → 事件标记已处理
##   → _unhandled_input 不会被调用 → 游戏动作不会触发
##   鼠标在游戏世界时 → 无 Control 消费 → _unhandled_input 触发 → 游戏动作生效
class_name InputProvider
extends Node

var _resolver: ActionResolver = null


## 注入 ActionResolver（由 InputService 提供）。
func configure(p_resolver: ActionResolver) -> void:
	_resolver = p_resolver
	if not is_inside_tree():
		await tree_entered
	set_process_input(true)
	set_process(true)


func _ready() -> void:
	if _resolver != null:
		set_process_input(true)
		set_process(true)


var _debug_count: int = 0

## 收集所有未被 GUI 消费的原始输入事件。
func _unhandled_input(p_event: InputEvent) -> void:
	if _resolver != null:
		_resolver.process_event(p_event)
		if _debug_count < 5:
			_debug_count += 1
			print("[InputProvider] unhandled: ", p_event.as_text())


## 每帧结束所有动作的合成计算。
func _process(p_delta: float) -> void:
	if _resolver != null:
		_resolver.end_frame(p_delta)
