## NodePool — 通用节点对象池（框架层）。
## 按 PackedScene 维护空闲节点池，避免频繁 instantiate / queue_free 造成性能尖峰。
##
## 用法：
##   var pool := NodePool.new()
##   var node := pool.acquire(tree_scene)    # 从池中取或新建
##   pool.release(node)                       # 归还（隐藏 + 移出树）
##
## 适用场景：地图上大量重复生成/销毁的实体（资源、建筑、单位等）。
class_name NodePool
extends RefCounted

## { scene.resource_path or uid → Array[Node] }
var _pools: Dictionary = {}


## 从池中获取指定场景的实例。池空时调用 instantiate。
func acquire(p_scene: PackedScene) -> Node:
	if p_scene == null:
		return null
	var key := _scene_key(p_scene)
	var pool: Array = _pools.get(key, [])
	while not pool.is_empty():
		var node: Node = pool.pop_back()
		if is_instance_valid(node):
			return node
	var instance: Node = p_scene.instantiate()
	return instance


## 归还节点到池中（自动隐藏并从父节点移除）。
func release(p_node: Node) -> void:
	if p_node == null or not is_instance_valid(p_node):
		return
	p_node.visible = false
	if p_node.get_parent() != null:
		p_node.get_parent().remove_child(p_node)


## 归还节点并关联到指定场景（用于节点已丢失原始场景引用时）。
func release_as(p_node: Node, p_scene: PackedScene) -> void:
	if p_node == null or p_scene == null or not is_instance_valid(p_node):
		return
	p_node.visible = false
	if p_node.get_parent() != null:
		p_node.get_parent().remove_child(p_node)
	var key := _scene_key(p_scene)
	var pool: Array = _pools.get(key, [])
	pool.append(p_node)
	_pools[key] = pool


## 清空所有池，可选释放节点。
func clear(p_free_nodes: bool = false) -> void:
	if p_free_nodes:
		for key in _pools.keys():
			for node in _pools[key]:
				if is_instance_valid(node):
					node.queue_free()
	_pools.clear()


## 获取池中空闲节点数。
func idle_count(p_scene: PackedScene = null) -> int:
	if p_scene != null:
		return (_pools.get(_scene_key(p_scene), []) as Array).size()
	var total := 0
	for pool in _pools.values():
		total += (pool as Array).size()
	return total


func _scene_key(p_scene: PackedScene) -> String:
	return p_scene.resource_path if not p_scene.resource_path.is_empty() else str(p_scene.get_rid())
