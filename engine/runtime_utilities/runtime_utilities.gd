## RuntimeUtilities
## Godot 运行时工具集。纯静态方法，不注册为服务，不存储状态。
##
## 提供：
##   - 主线程调度（call_deferred 封装）
##   - 延迟执行
##   - 节点安全操作（有效性检查、安全释放）
##   - 场景树访问辅助
class_name RuntimeUtilities
extends RefCounted


# ============================================================
# 主线程调度
# ============================================================

## 将回调调度到主线程下一帧执行。
## 异步回调（网络/文件 IO 完成后）必须用此方法回到主线程再操作节点。
##
##   [codeblock]
##   RuntimeUtilities.defer(func(): my_node.visible = true)
##   [/codeblock]
static func defer(p_callable: Callable) -> void:
	(p_callable as Callable).call_deferred()


## 将带参数的回调调度到主线程下一帧执行
static func defer_with(p_callable: Callable, p_arg1 = null) -> void:
	p_callable.call_deferred(p_arg1)


# ============================================================
# 延迟执行
# ============================================================

## 延迟 p_seconds 秒后执行回调。
## 需要传入场景树中的任意节点来创建 Timer。
##
##   [codeblock]
##   RuntimeUtilities.delay(some_node, 2.0, func(): print("2秒后执行"))
##   [/codeblock]
static func delay(p_host: Node, p_seconds: float, p_callable: Callable) -> void:
	var timer := p_host.get_tree().create_timer(p_seconds)
	timer.timeout.connect(p_callable, CONNECT_ONE_SHOT)


## 延迟一帧执行（等效于 defer）
static func next_frame(p_host: Node, p_callable: Callable) -> void:
	p_host.get_tree().process_frame.connect(_wrap_one_shot(p_callable), CONNECT_ONE_SHOT)


# ============================================================
# 节点安全操作
# ============================================================

## 检查节点是否仍然有效（未被 queue_free 且未从树中移除）
static func is_node_valid(p_node: Node) -> bool:
	return is_instance_valid(p_node) and not p_node.is_queued_for_deletion()


## 安全释放节点（先检查有效性）
static func safe_free(p_node: Node) -> void:
	if is_node_valid(p_node):
		p_node.queue_free()


## 安全释放节点的所有子节点
static func safe_free_children(p_parent: Node) -> void:
	for child in p_parent.get_children():
		safe_free(child)


# ============================================================
# 场景树辅助
# ============================================================

## 获取场景树根节点，失败返回 null
static func get_tree_root() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root


## 获取当前场景根节点，失败返回 null
static func get_current_scene() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene


# ============================================================
# 内部
# ============================================================

static func _wrap_one_shot(p_callable: Callable) -> Callable:
	return func():
		p_callable.call()
