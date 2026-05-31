## EcsRuntimeBridge — ECS 运行时模式桥接。
## 根据 RuntimeMode（Local/Remote/Hybrid）选择不同的 ECS 命令执行策略，
## 支持预测（Prediction）、确认（Confirm）和回滚（Rollback）基础流程。
class_name EcsRuntimeBridge
extends RefCounted

enum ExecuteMode { LOCAL, REMOTE, HYBRID }

var _mode: int = ExecuteMode.LOCAL
var _ecb_pool: EcsCommandBufferPool = null
var _snapshot_builder: EcsSnapshotBuilder = null
var _snapshot_applier: EcsSnapshotApplier = null
## Hybrid 模式下的预测快照栈（用于回滚）
var _prediction_stack: Array[EcsWorldSnapshot] = []


func _init(p_mode: int = ExecuteMode.LOCAL) -> void:
	_mode = p_mode
	_ecb_pool = EcsCommandBufferPool.new()
	_snapshot_builder = EcsSnapshotBuilder.new()
	_snapshot_applier = EcsSnapshotApplier.new()


## 设置运行时模式。
func set_mode(p_mode: int) -> void:
	_mode = p_mode


## 获取当前模式。
func get_mode() -> int:
	return _mode


## 为 Hybrid 模式保存预测前快照。
func save_prediction_snapshot(p_world: EcsWorld) -> void:
	if _mode != ExecuteMode.HYBRID:
		return
	_prediction_stack.append(_snapshot_builder.build(p_world))


## Hybrid 模式：回滚到最近一次预测前状态。
func rollback_prediction(p_world: EcsWorld) -> OperationResult:
	if _prediction_stack.is_empty():
		return OperationResult.fail(OperationResult.ERR_PRECONDITION, "无可用预测快照", "EcsRuntimeBridge")
	var snapshot: Variant = _prediction_stack.pop_back()
	return _snapshot_applier.apply(p_world, snapshot)


## Hybrid 模式：确认预测（弹出栈顶快照，不恢复）。
func confirm_prediction() -> void:
	if not _prediction_stack.is_empty():
		_prediction_stack.pop_back()


## 清空预测栈。
func clear_predictions() -> void:
	_prediction_stack.clear()


## 是否为本地权威模式。
func is_local() -> bool:
	return _mode == ExecuteMode.LOCAL


## 是否为远程权威模式。
func is_remote() -> bool:
	return _mode == ExecuteMode.REMOTE


## 是否为混合预测模式。
func is_hybrid() -> bool:
	return _mode == ExecuteMode.HYBRID
