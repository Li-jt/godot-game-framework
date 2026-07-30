# tests/helpers/dynamic_traversal.gd
## 动态 ITraversal 测试替身。指定格子不可通行。
extends GF_ITraversal

var blocked_cells: Array[Vector2i] = []


func is_walkable(p_pos) -> bool:
	for b in blocked_cells:
		if b == p_pos:
			return false
	return true
