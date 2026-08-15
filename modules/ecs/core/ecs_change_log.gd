# modules/ecs/core/ecs_change_log.gd
## GF_EcsChangeLog — 世界级变更日志（单帧生命周期）。
## 记录一帧内的所有 ECS mutation：实体增删、组件增改删。
## GF_EcsWorld 的每次 mutation 自动追加；消费方在 tick 边界读取后调用
## clear()（框架不定义消费时序，消费语义由使用方决定）。
##
## 三种消费模式示例：
## 1. 增量索引维护：消费 added/removed 实体列表，维护空间索引等外部结构；
## 2. 脏标记收集：消费 component_changes 的 (entity, type_id) 对，避免全量扫描；
## 3. 存档 delta 累计：消费 component_changes 的 (entity, component) 快照，
##    构建增量存档（见性能优化路线图 §3.1）。
##
## 容量保护：超过 max_entries 时置 overflowed 并丢弃后续记录——
## 消费方看到 overflowed 应降级为全量处理（如全量重建索引）。
class_name GF_EcsChangeLog
extends RefCounted

## 组件变更类型
enum ChangeKind { COMPONENT_ADDED, COMPONENT_CHANGED, COMPONENT_REMOVED }

## 容量上限（防极端帧内存驻留；测试可调小验证溢出）
var max_entries: int = 100000

## 本帧新增实体 ID
var added_entities: PackedInt64Array = PackedInt64Array()
## 本帧销毁实体 ID
var removed_entities: PackedInt64Array = PackedInt64Array()
## 本帧组件变更: {entity, type_id, kind, component}
## component 为变更时的组件数据快照引用（add/set 时有值，remove 时为 null），
## 引用仅在单帧内有效——不要存留越过下一次 clear()。
var component_changes: Array[Dictionary] = []
## 溢出标记：容量耗尽后置 true，消费方应降级为全量处理
var overflowed: bool = false


## 记录新增实体。
func record_added_entity(p_entity: int) -> void:
	if added_entities.size() >= max_entries:
		overflowed = true
		return
	added_entities.append(p_entity)


## 记录销毁实体。
func record_removed_entity(p_entity: int) -> void:
	if removed_entities.size() >= max_entries:
		overflowed = true
		return
	removed_entities.append(p_entity)


## 记录组件变更。
## [param p_component] 组件数据快照（remove 时传 null）
func record_component_change(p_entity: int, p_type_id: int, p_kind: ChangeKind, p_component: Variant = null) -> void:
	if component_changes.size() >= max_entries:
		overflowed = true
		return
	component_changes.append({
		"entity": p_entity,
		"type_id": p_type_id,
		"kind": p_kind,
		"component": p_component,
	})


## 本帧是否有任何变更。
func has_changes() -> bool:
	return not added_entities.is_empty() \
		or not removed_entities.is_empty() \
		or not component_changes.is_empty()


## 清空全部记录（下一帧开始）。消费方在读取后调用。
func clear() -> void:
	added_entities.clear()
	removed_entities.clear()
	component_changes.clear()
	overflowed = false
