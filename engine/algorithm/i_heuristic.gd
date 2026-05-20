## IHeuristic — 寻路启发式函数接口（Framework 层）。
## 估算两节点间距离。不同实现对应不同移动规则。
class_name IHeuristic
extends RefCounted


func estimate(p_from: Vector2i, p_to: Vector2i) -> int:
	push_error("IHeuristic.estimate() 必须由子类重写")
	return 0
