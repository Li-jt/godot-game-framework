## Pathfinder — A* 寻路（Framework 层）。可实例化，支持注入启发式。
## 每次 find_path() 传入不同的 graph 和 traversal，同一实例可服务多种单位类型。
class_name Pathfinder
extends RefCounted

class PathNode:
	var pos: Vector2i
	var parent: PathNode = null
	var g: int = 0
	var h: int = 0
	var f: int = 0

	func _init(p_pos: Vector2i, p_parent, p_g: int, p_h: int) -> void:
		pos = p_pos; parent = p_parent; g = p_g; h = p_h; f = p_g + p_h


var _heuristic: IHeuristic


func _init(p_heuristic: IHeuristic = null) -> void:
	_heuristic = p_heuristic if p_heuristic != null else ManhattanHeuristic.new()


func find_path(p_from: Vector2i, p_to: Vector2i, p_graph: IPathGraph, p_traversal: ITraversal) -> Array:
	if not p_traversal.is_walkable(p_to):
		return []
	if p_from == p_to:
		return [p_from]

	var open: Array[PathNode] = [PathNode.new(p_from, null, 0, _heuristic.estimate(p_from, p_to))]
	var closed: Dictionary = {}

	while not open.is_empty():
		open.sort_custom(func(a: PathNode, b: PathNode): return a.f < b.f)
		var current: PathNode = open.pop_front()
		var key := _key(current.pos)

		if current.pos == p_to:
			return _rebuild_path(current)

		closed[key] = true

		for nb in p_graph.get_neighbors(current.pos):
			var nb_pos: Vector2i = nb
			if closed.has(_key(nb_pos)):
				continue
			if not p_traversal.is_walkable(nb_pos) and nb_pos != p_to:
				continue

			var g: int = current.g + int(p_graph.get_cost(current.pos, nb_pos))
			var idx := _find_in_open(open, nb_pos)
			if idx >= 0:
				var existing := open[idx]
				if g < existing.g:
					existing.g = g
					existing.f = g + existing.h
					existing.parent = current
			else:
				var h: int = _heuristic.estimate(nb_pos, p_to)
				open.append(PathNode.new(nb_pos, current, g, h))

	return []


func _key(p_pos: Vector2i) -> String:
	return "%d,%d" % [p_pos.x, p_pos.y]


func _find_in_open(p_open: Array[PathNode], p_pos: Vector2i) -> int:
	for i in p_open.size():
		if p_open[i].pos == p_pos:
			return i
	return -1


func _rebuild_path(p_node: PathNode) -> Array:
	var path: Array = []
	var cur: PathNode = p_node
	while cur != null:
		path.push_front(cur.pos)
		cur = cur.parent
	return path
