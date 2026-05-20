## IPathQuery — 寻路所需的地图查询接口（Framework 层）。
## Pathfinder 依赖此接口，不依赖具体游戏类型。
## Game 层让 WorldQuery 继承此类即可。
class_name IPathQuery
extends RefCounted


func is_in_bounds(p_pos: Vector2i) -> bool:
	push_error("IPathQuery.is_in_bounds() 必须由子类重写")
	return false


func is_walkable(p_pos: Vector2i) -> bool:
	push_error("IPathQuery.is_walkable() 必须由子类重写")
	return false


func get_neighbors(p_pos: Vector2i) -> Array[Vector2i]:
	push_error("IPathQuery.get_neighbors() 必须由子类重写")
	return []
