## ManhattanHeuristic — 曼哈顿距离启发式（Framework 层）。
## 适用于四方向网格移动。
class_name ManhattanHeuristic
extends IHeuristic


func estimate(p_from: Vector2i, p_to: Vector2i) -> int:
	return absi(p_from.x - p_to.x) + absi(p_from.y - p_to.y)
