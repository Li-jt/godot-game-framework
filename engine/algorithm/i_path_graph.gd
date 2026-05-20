## IPathGraph — 寻路地图结构接口（Framework 层）。
## 提供节点的邻居列表和移动代价。Game 层让 WorldQuery 实现此接口。
class_name IPathGraph
extends RefCounted


func get_neighbors(p_pos: Vector2i) -> Array:
	push_error("IPathGraph.get_neighbors() 必须由子类重写")
	return []


func get_cost(p_from: Vector2i, p_to: Vector2i) -> float:
	return 1.0
