## EcsCommandBuffer — 命令缓冲。
## 收集本帧内的 ECS 写操作，apply 前预校验（P2-3），帧末统一 apply 到 EcsWorld。
## 系统 on_tick 中只写 ECB，不直接修改 world storage，避免迭代冲突。
class_name EcsCommandBuffer
extends IEcsCommandBuffer

var _commands: Array[EcsCommand] = []
var _temp_counter: int = EcsCommand.TEMP_ENTITY_START
var _spawned_temps: Array[int] = []  # 本缓冲中已 spawn 的临时 ID


func spawn() -> int:
	var temp_id: int = _temp_counter
	_temp_counter -= 1
	_spawned_temps.append(temp_id)
	_commands.append(EcsCommand.new(EcsCommand.SPAWN, temp_id))
	return temp_id


func add_component(p_entity: int, p_type: StringName, p_data: Variant) -> void:
	_commands.append(EcsCommand.new(EcsCommand.ADD_COMPONENT, p_entity, p_type, p_data))


func set_component(p_entity: int, p_type: StringName, p_data: Variant) -> void:
	_commands.append(EcsCommand.new(EcsCommand.SET_COMPONENT, p_entity, p_type, p_data))


func remove_component(p_entity: int, p_type: StringName) -> void:
	_commands.append(EcsCommand.new(EcsCommand.REMOVE_COMPONENT, p_entity, p_type))


func despawn(p_entity: int) -> void:
	_commands.append(EcsCommand.new(EcsCommand.DESPAWN, p_entity))


## 预校验 + 应用全部命令。预校验失败时不执行任何操作。
func apply_to(p_world: EcsWorld) -> OperationResult:
	# P2-4 + P2-3: 先预校验全部命令
	var validate_result: OperationResult = _validate_all()
	if validate_result.is_fail():
		_commands.clear()
		_spawned_temps.clear()
		return validate_result

	var temp_to_real: Dictionary = {}

	for cmd in _commands:
		match cmd.type:
			EcsCommand.SPAWN:
				var real_id: int = p_world.spawn()
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
						push_error("[EcsCommandBuffer] add_component 失败: %s" % result.error.message if result.error != null else "未知错误")

			EcsCommand.SET_COMPONENT:
				var actual_id := _resolve(temp_to_real, cmd.entity)
				if actual_id > 0:
					var result := p_world.set_component(actual_id, cmd.component_type, cmd.data)
					if result.is_fail():
						push_error("[EcsCommandBuffer] set_component 失败: %s" % result.error.message if result.error != null else "未知错误")

			EcsCommand.REMOVE_COMPONENT:
				var actual_id := _resolve(temp_to_real, cmd.entity)
				if actual_id > 0:
					p_world.remove_component(actual_id, cmd.component_type)

	_commands.clear()
	_spawned_temps.clear()
	return OperationResult.ok(temp_to_real)


func count() -> int:
	return _commands.size()


func clear() -> void:
	_commands.clear()
	_temp_counter = EcsCommand.TEMP_ENTITY_START
	_spawned_temps.clear()


## 预校验阶段：检查所有临时实体引用是否合法。
func _validate_all() -> OperationResult:
	for cmd in _commands:
		if cmd.entity < 0 and cmd.type != EcsCommand.SPAWN:
			if not _spawned_temps.has(cmd.entity):
				return OperationResult.fail(
					OperationResult.ERR_PRECONDITION,
					"临时实体 %d 在 spawn 之前被引用" % cmd.entity,
					"EcsCommandBuffer"
				)
	return OperationResult.ok()


func _resolve(p_map: Dictionary, p_entity: int) -> int:
	if p_entity < 0 and p_map.has(p_entity):
		return p_map[p_entity]
	return p_entity
