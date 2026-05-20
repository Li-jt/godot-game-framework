## Pathfinder — A* 寻路算法（Framework 层）。
## 纯静态，无状态，不依赖具体游戏类型。输入 WorldQuery 接口即可工作。
class_name Pathfinder
extends RefCounted


static func find_path(p_from: Vector2i, p_to: Vector2i, p_query: WorldQuery) -> Array[Vector2i]:
	if not p_query.is_in_bounds(p_from) or not p_query.is_in_bounds(p_to):
		return []
	if not p_query.is_walkable(p_to):
		return []
	if p_from == p_to:
		return [p_from]

	var open: Array = [_make_node(p_from, null, 0, _heuristic(p_from, p_to))]
	var closed: Dictionary = {}

	while not open.is_empty():
		open.sort_custom(func(a, b): return a.f < b.f)
		var current: Dictionary = open.pop_front()
		var cur_pos: Vector2i = current.pos
		var key := _key(cur_pos)

		if cur_pos == p_to:
			return _rebuild_path(current)

		closed[key] = true

		for nb in p_query.get_neighbors(cur_pos):
			if closed.has(_key(nb)):
				continue
			if not p_query.is_walkable(nb) and nb != p_to:
				continue

			var g: int = current.g + 1
			var idx: int = _find_in_open(open, nb)
			if idx >= 0:
				var existing: Dictionary = open[idx]
				if g < existing.g:
					existing.g = g
					existing.f = g + existing.h
					existing.parent = current
			else:
				var h: int = _heuristic(nb, p_to)
				open.append(_make_node(nb, current, g, h))

	return []


static func _heuristic(p_a: Vector2i, p_b: Vector2i) -> int:
	return absi(p_a.x - p_b.x) + absi(p_a.y - p_b.y)


static func _key(p_pos: Vector2i) -> String:
	return "%d,%d" % [p_pos.x, p_pos.y]


static func _make_node(p_pos: Vector2i, p_parent, p_g: int, p_h: int) -> Dictionary:
	return {"pos": p_pos, "parent": p_parent, "g": p_g, "h": p_h, "f": p_g + p_h}


static func _find_in_open(p_open: Array, p_pos: Vector2i) -> int:
	for i in p_open.size():
		if (p_open[i] as Dictionary).pos == p_pos:
			return i
	return -1


static func _rebuild_path(p_node: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur = p_node
	while cur != null:
		path.push_front(cur.pos)
		cur = cur.get("parent", null)
	return path
