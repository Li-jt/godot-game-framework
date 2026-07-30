# tests/helpers/dynamic_path_graph.gd
## 动态 IPathGraph 测试替身。矩形网格图。
extends GF_IPathGraph

var grid_size: int = 5


func get_neighbors(p_node) -> Array:
	var neighbors: Array = []
	var cell: Vector2i = p_node as Vector2i
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var next_pos: Vector2i = cell + d
		if next_pos.x >= 0 and next_pos.x < grid_size and next_pos.y >= 0 and next_pos.y < grid_size:
			neighbors.append(next_pos)
	return neighbors


func cost(_a, _b) -> float:
	return 1.0
