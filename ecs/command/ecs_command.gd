## EcsCommand — ECS 命令缓冲中的操作类型常量。
## 定义 spawn / despawn / add_component / set_component / remove_component 五种标准操作。
class_name EcsCommand
extends RefCounted

# 操作类型
const SPAWN: int = 1
const DESPAWN: int = 2
const ADD_COMPONENT: int = 3
const SET_COMPONENT: int = 4
const REMOVE_COMPONENT: int = 5

# 内部：临时实体 ID 起始值（负数，用于缓冲中暂未提交的实体）
const TEMP_ENTITY_START: int = -1000000

var type: int = 0
var entity: int = 0
var component_type: StringName = &""
var data: Variant = null


## 创建一条命令记录。
func _init(p_type: int, p_entity: int, p_component_type: StringName = &"", p_data = null) -> void:
	type = p_type
	entity = p_entity
	component_type = p_component_type
	data = p_data
