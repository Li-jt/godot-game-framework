## GF_NodePool — 节点对象池。
## 按 PackedScene 维护子池，避免频繁 instantiate / queue_free。
##
## 内部使用 GF_ObjectPool，对外保持原有 API 兼容。
class_name GF_NodePool
extends RefCounted

var _pools: Dictionary = {}


func acquire(p_scene: PackedScene) -> Node:
	if p_scene == null:
		return null
	var key := _scene_key(p_scene)
	var sub: GF_ObjectPool = _pools.get(key, null)
	if sub == null:
		sub = _make_scene_pool(p_scene)
		_pools[key] = sub
	return sub.acquire() as Node


func release(p_node: Node) -> void:
	if p_node == null or not is_instance_valid(p_node):
		return
	p_node.visible = false
	if p_node.get_parent() != null:
		p_node.get_parent().remove_child(p_node)


func release_as(p_node: Node, p_scene: PackedScene) -> void:
	if p_node == null or p_scene == null or not is_instance_valid(p_node):
		return
	p_node.visible = false
	if p_node.get_parent() != null:
		p_node.get_parent().remove_child(p_node)
	var key := _scene_key(p_scene)
	var sub: GF_ObjectPool = _pools.get(key, null)
	if sub == null:
		sub = _make_scene_pool(p_scene)
		_pools[key] = sub
	sub.release(p_node)


func clear(p_free_nodes: bool = false) -> void:
	if p_free_nodes:
		for sub in _pools.values():
			(sub as GF_ObjectPool).clear(func(n): (n as Node).queue_free())
	_pools.clear()


func idle_count(p_scene: PackedScene = null) -> int:
	if p_scene != null:
		var sub: GF_ObjectPool = _pools.get(_scene_key(p_scene), null)
		return sub.available() if sub else 0
	var total := 0
	for sub in _pools.values():
		total += (sub as GF_ObjectPool).available()
	return total


func _make_scene_pool(p_scene: PackedScene) -> GF_ObjectPool:
	var pool := GF_ObjectPool.new()
	pool.create_fn = func(): return p_scene.instantiate()
	pool.validate_fn = func(n): return is_instance_valid(n)
	return pool


func _scene_key(p_scene: PackedScene) -> String:
	return p_scene.resource_path if not p_scene.resource_path.is_empty() else str(p_scene.get_rid())
