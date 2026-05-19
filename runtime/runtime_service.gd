## RuntimeService
## 运行时模式服务。根据 AppConfig 确定当前运行模式，
## Framework 各模块（Command、Save、Network）通过此服务判断行为分支。
##
## 使用方式：
##   [codeblock]
##   # RuntimeService 由 Framework 内部通过 ServiceRegistry.instance 获取
##   if runtime.is_local():
##       execute_locally(command)
##   elif runtime.is_hybrid():
##       predict_then_confirm(command)
##   [/codeblock]
class_name RuntimeService
extends ModuleLifecycle

var _mode: RuntimeMode.Mode = RuntimeMode.Mode.LOCAL
var _prediction_enabled: bool = false
var _rollback_enabled: bool = false


func _on_init() -> OperationResult:
	return OperationResult.ok()


func configure(p_config: AppConfig.RuntimeSection) -> OperationResult:
	if p_config == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: config 不能为 null", module_name)
	_mode = RuntimeMode.from_string(p_config.mode)
	_prediction_enabled = p_config.enable_prediction
	_rollback_enabled = p_config.enable_rollback
	return OperationResult.ok()


# ============================================================
# 模式查询
# ============================================================

func is_local() -> bool:
	return _mode == RuntimeMode.Mode.LOCAL


func is_remote() -> bool:
	return _mode == RuntimeMode.Mode.REMOTE


func is_hybrid() -> bool:
	return _mode == RuntimeMode.Mode.HYBRID


func get_mode() -> RuntimeMode.Mode:
	return _mode


func get_mode_name() -> String:
	match _mode:
		RuntimeMode.Mode.LOCAL: return "Local"
		RuntimeMode.Mode.REMOTE: return "Remote"
		RuntimeMode.Mode.HYBRID: return "Hybrid"
		_: return "Unknown"


# ============================================================
# 特性查询
# ============================================================

## 是否需要远程确认（Remote 或 Hybrid）
func requires_remote_confirm() -> bool:
	return _mode == RuntimeMode.Mode.REMOTE or _mode == RuntimeMode.Mode.HYBRID


## 本地是否为最终权威
func is_local_authority() -> bool:
	return _mode == RuntimeMode.Mode.LOCAL


## 预测功能是否启用
func is_prediction_enabled() -> bool:
	return _prediction_enabled and _mode == RuntimeMode.Mode.HYBRID


## 回滚功能是否启用
func is_rollback_enabled() -> bool:
	return _rollback_enabled and _mode == RuntimeMode.Mode.HYBRID


# ============================================================
# 策略入口（CommandExecutor / SaveService 通过此方法获取策略）
# ============================================================

## 获取当前模式的命令执行策略。返回 OperationResult，data 为 CommandStrategy。
## Remote/Hybrid 未实现时返回 fail。
func get_command_strategy() -> OperationResult:
	if _mode == RuntimeMode.Mode.LOCAL:
		var s := LocalCommandStrategy.new()
		return OperationResult.ok(s)
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "Remote/Hybrid 命令策略尚未实现", module_name)


## 获取当前模式的存档策略。返回 OperationResult，data 为 SaveStrategy。
func get_save_strategy() -> OperationResult:
	if _mode == RuntimeMode.Mode.LOCAL:
		return OperationResult.ok(SaveStrategy.new())
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "Remote/Hybrid 存档策略尚未实现", module_name)
