## GF_IMapRepository — 地图/Tile 数据访问抽象。
##
## ⚠️ 预留接口：多人/网络模式（Remote / Hybrid Authority）。
## 当前 Local 模式不使用此接口，地图数据直接在 ECS 中管理。
##
## 计划用途：
##   - Remote Authority：服务端通过此接口管理格子世界的空间数据
##   - Hybrid Authority：客户端预测使用此接口做本地地图缓存
##
## 注意：此接口当前无实现，不要继承或使用。
class_name GF_IMapRepository
extends RefCounted

func get_tile(p_x: int, p_y: int) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_IMapRepository")


func set_tile(p_x: int, p_y: int, p_data: Dictionary) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_IMapRepository")


func get_region(p_x: int, p_y: int, p_width: int, p_height: int) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_IMapRepository")


func get_all_tiles() -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_IMapRepository")
