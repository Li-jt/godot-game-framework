## Pathfinder — A* 寻路算法（Framework 层）。纯静态。
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


static func find_path(p_from: Vector2i, p_to: Vector2i, p_query: WorldQuery) -> Array[Vector2i]:
	if not p_query.is_in_bounds(p_from) or not p_query.is_in_bounds(p_to):
		return []
	if not p_query.is_walkable(p_to):
		return []
	if p_from == p_to:
		return [p_from]

	var open: Array[PathNode] = [PathNode.new(p_from, null, 0, _heuristic(p_from, p_to))]
	var closed: Dictionary = {}

	while not open.is_empty():
		open.sort_custom(func(a: PathNode, b: PathNode): return a.f < b.f)
		var current: PathNode = open.pop_front()
		var key := _key(current.pos)

		if current.pos == p_to:
			return _rebuild_path(current)

		closed[key] = true

		for nb in p_query.get_neighbors(current.pos):
			if closed.has(_key(nb)):
				continue
			if not p_query.is_walkable(nb) and nb != p_to:
				continue

			var g: int = current.g + 1
			var idx := _find_in_open(open, nb)
			if idx >= 0:
				var existing := open[idx]
				if g < existing.g:
					existing.g = g
					existing.f = g + existing.h
					existing.parent = current
			else:
				var h: int = _heuristic(nb, p_to)
				open.append(PathNode.new(nb, current, g, h))

	return []


static func _heuristic(p_a: Vector2i, p_b: Vector2i) -> int:
	return absi(p_a.x - p_b.x) + absi(p_a.y - p_b.y)


static func _key(p_pos: Vector2i) -> String:
	return "%d,%d" % [p_pos.x, p_pos.y]


static func _find_in_open(p_open: Array[PathNode], p_pos: Vector2i) -> int:
	for i in p_open.size():
		if p_open[i].pos == p_pos:
			return i
	return -1


static func _rebuild_path(p_node: PathNode) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur: PathNode = p_node
	while cur != null:
		path.push_front(cur.pos)
		cur = cur.parent
	return path
