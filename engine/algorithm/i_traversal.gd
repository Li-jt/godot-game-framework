## ITraversal — 寻路通行规则接口（Framework 层）。
## 判断节点是否可行走。每次寻路可传入不同实现（地面/飞行/水路）。
class_name ITraversal
extends RefCounted


func is_walkable(p_pos: Vector2i) -> bool:
	push_error("ITraversal.is_walkable() 必须由子类重写")
	return false
