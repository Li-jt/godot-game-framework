## EcsEntityId — 实体 ID 工具类。
## 提供静态校验方法，ID 分配由 EcsWorld 实例管理，避免多 World 冲突。
class_name EcsEntityId
extends RefCounted

## 校验实体 ID 是否有效（大于 0 即为有效）。
static func is_valid(p_id: int) -> bool:
	return p_id > 0
