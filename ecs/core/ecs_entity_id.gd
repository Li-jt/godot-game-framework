## EcsEntityId — 实体 ID 生成器与校验工具。
## 保证单世界内运行时唯一，使用静态原子计数器递增。
class_name EcsEntityId
extends RefCounted

static var _next_id: int = 1


## 生成一个新的唯一实体 ID。
static func create() -> int:
	var id := _next_id
	_next_id += 1
	return id


## 校验实体 ID 是否有效（大于 0 即为有效）。
static func is_valid(p_id: int) -> bool:
	return p_id > 0


## 重置计数器（仅用于测试或世界重置）。
static func reset() -> void:
	_next_id = 1
