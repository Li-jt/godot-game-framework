## EcsCommandBuffer — 命令缓冲。
## 收集本帧内的 ECS 写操作，帧末一次性 apply 到 EcsWorld。
## 系统 on_tick 中只写 ECB，不直接修改 world storage，避免迭代冲突。
class_name EcsCommandBuffer
extends RefCounted

var _commands: Array[EcsCommand] = []
var _temp_counter: int = EcsCommand.TEMP_ENTITY_START


## 在缓冲中创建一个临时实体，apply 时转为真实实体。
## 返回临时实体 ID（负数），调用方可在后续操作中引用。
func spawn() -> int:
	var temp_id := _temp_counter
	_temp_counter -= 1
	_commands.append(EcsCommand.new(EcsCommand.SPAWN, temp_id))
	return temp_id


## 在缓冲中记录添加组件操作。
func add_component(p_entity: int, p_type: StringName, p_data: Variant) -> void:
	_commands.append(EcsCommand.new(EcsCommand.ADD_COMPONENT, p_entity, p_type, p_data))


## 在缓冲中记录设置组件操作（存在则覆盖，不存在则新增）。
func set_component(p_entity: int, p_type: StringName, p_data: Variant) -> void:
	_commands.append(EcsCommand.new(EcsCommand.SET_COMPONENT, p_entity, p_type, p_data))


## 在缓冲中记录移除组件操作。
func remove_component(p_entity: int, p_type: StringName) -> void:
	_commands.append(EcsCommand.new(EcsCommand.REMOVE_COMPONENT, p_entity, p_type))


## 在缓冲中记录销毁实体操作。
func despawn(p_entity: int) -> void:
	_commands.append(EcsCommand.new(EcsCommand.DESPAWN, p_entity))


## 将缓冲中的所有命令应用到指定世界。返回失败时已执行的操作不回滚。
func apply_to(p_world: EcsWorld) -> OperationResult:
	var temp_to_real: Dictionary = {}  # temp_id -> real_id

	for cmd in _commands:
		match cmd.type:
			EcsCommand.SPAWN:
				var real_id := p_world.spawn()
				temp_to_real[cmd.entity] = real_id

			EcsCommand.DESPAWN:
				var actual_id := _resolve(temp_to_real, cmd.entity)
				if actual_id > 0 and p_world.has_entity(actual_id):
					p_world.despawn(actual_id)

			EcsCommand.ADD_COMPONENT:
				var actual_id := _resolve(temp_to_real, cmd.entity)
				if actual_id > 0:
					var result := p_world.add_component(actual_id, cmd.component_type, cmd.data)
					if result.is_fail() and result.status_code != OperationResult.ERR_CONFLICT:
						return result

			EcsCommand.SET_COMPONENT:
				var actual_id := _resolve(temp_to_real, cmd.entity)
				if actual_id > 0:
					var result := p_world.set_component(actual_id, cmd.component_type, cmd.data)
					if result.is_fail():
						return result

			EcsCommand.REMOVE_COMPONENT:
				var actual_id := _resolve(temp_to_real, cmd.entity)
				if actual_id > 0:
					p_world.remove_component(actual_id, cmd.component_type)

	_commands.clear()
	return OperationResult.ok(temp_to_real)


## 当前缓冲中的命令数量。
func count() -> int:
	return _commands.size()


## 清空缓冲（不执行）。
func clear() -> void:
	_commands.clear()
	_temp_counter = EcsCommand.TEMP_ENTITY_START


## 将临时实体 ID 解析为真实 ID。
func _resolve(p_map: Dictionary, p_entity: int) -> int:
	if p_entity < 0 and p_map.has(p_entity):
		return p_map[p_entity]
	return p_entity
