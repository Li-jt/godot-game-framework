## GF_SaveProvider
## 存档提供者抽象基类。Local/Remote/Hybrid Provider 继承此类。
## GF_SaveService 通过此接口操作存档，不关心底层存储方式。
class_name GF_SaveProvider
extends RefCounted

## 保存数据到指定槽位。p_data 为 Game 层构建的序列化字典。
func save(p_slot: int, p_data: Dictionary, p_meta: GF_SaveMeta) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_SaveProvider")


## 从指定槽位读取数据。返回 Ok，data 为 Dictionary。
func load(p_slot: int) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_SaveProvider")


## 读取完整存档（meta + data wrapper），供 GF_SaveService 做版本检测和迁移。
func load_full(p_slot: int) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_SaveProvider")


## 列出所有有效槽位的元数据。返回 Ok，data 为 Array[GF_SaveMeta]。
func list_slots() -> GF_OperationResult:
	return GF_OperationResult.ok([])


## 删除指定槽位的存档
func delete(p_slot: int) -> GF_OperationResult:
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "未实现", "GF_SaveProvider")
