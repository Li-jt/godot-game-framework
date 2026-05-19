## IMapRepository
## 地图/ Tile 数据访问抽象。管理格子世界的空间数据。
class_name IMapRepository
extends RefCounted

func get_tile(p_x: int, p_y: int) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IMapRepository")


func set_tile(p_x: int, p_y: int, p_data: Dictionary) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IMapRepository")


func get_region(p_x: int, p_y: int, p_width: int, p_height: int) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IMapRepository")


func get_all_tiles() -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "IMapRepository")
