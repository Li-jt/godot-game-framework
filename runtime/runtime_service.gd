## GF_RuntimeService
## 运行时模式服务。Framework 各模块（Command、Save、Network）通过此服务判断行为分支。
##
## GF_RuntimeService 通过 Installer 注入到 GF_ServiceRegistry，Game 层通过 GF_GameServices.runtime 访问。
##
## 使用方式：
##   [codeblock]
##   if runtime.is_local():
##       execute_locally(command)
##   elif runtime.is_hybrid():
##       predict_then_confirm(command)
##   [/codeblock]
class_name GF_RuntimeService
extends GF_ModuleLifecycle

var _mode: GF_RuntimeMode.Mode = GF_RuntimeMode.Mode.LOCAL
var _prediction_enabled: bool = false
var _rollback_enabled: bool = false
var _command_bus: Variant = null


func _on_init() -> GF_OperationResult:
	_command_bus = GF_CommandBus.new()
	return GF_OperationResult.ok()


## 配置运行时模式。默认 LOCAL。
## Game 层可通过 Bootstrap Hook 覆盖：
##   runtime_svc.configure(GF_RuntimeMode.Mode.REMOTE)

func dependencies() -> Array:
	return []

func configure() -> GF_OperationResult:
	return GF_OperationResult.ok()


# ============================================================
# 模式查询
# ============================================================

func is_local() -> bool:
	return _mode == GF_RuntimeMode.Mode.LOCAL


func is_remote() -> bool:
	return _mode == GF_RuntimeMode.Mode.REMOTE


func is_hybrid() -> bool:
	return _mode == GF_RuntimeMode.Mode.HYBRID


func get_mode() -> GF_RuntimeMode.Mode:
	return _mode


func get_mode_name() -> String:
	match _mode:
		GF_RuntimeMode.Mode.LOCAL: return "Local"
		GF_RuntimeMode.Mode.REMOTE: return "Remote"
		GF_RuntimeMode.Mode.HYBRID: return "Hybrid"
		_: return "Unknown"


# ============================================================
# 特性查询
# ============================================================

## 是否需要远程确认（Remote 或 Hybrid）
func requires_remote_confirm() -> bool:
	return _mode == GF_RuntimeMode.Mode.REMOTE or _mode == GF_RuntimeMode.Mode.HYBRID


## 本地是否为最终权威
func is_local_authority() -> bool:
	return _mode == GF_RuntimeMode.Mode.LOCAL


## 预测功能是否启用
func is_prediction_enabled() -> bool:
	return _prediction_enabled and _mode == GF_RuntimeMode.Mode.HYBRID


## 回滚功能是否启用
func is_rollback_enabled() -> bool:
	return _rollback_enabled and _mode == GF_RuntimeMode.Mode.HYBRID


# ============================================================
# 命令总线
# ============================================================

## 配置框架级命令总线。Local 策略会优先通过命令总线执行命令。
func set_command_bus(p_command_bus) -> void:
	_command_bus = p_command_bus


## 获取当前命令总线。用于注册/注销命令处理器。
func get_command_bus():
	return _command_bus


# ============================================================
# 策略入口（CommandExecutor / GF_SaveService 通过此方法获取策略）
# ============================================================

## 获取当前模式的命令执行策略。返回 GF_OperationResult，data 为 GF_CommandStrategy。
## Remote/Hybrid 未实现时返回 fail。
func get_command_strategy() -> GF_OperationResult:
	if _mode == GF_RuntimeMode.Mode.LOCAL:
		var s := GF_LocalCommandStrategy.new()
		if _command_bus != null:
			s.configure_command_bus(_command_bus)
		return GF_OperationResult.ok(s)
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "Remote/Hybrid 命令策略尚未实现", module_name)


## 获取当前模式的存档策略。返回 GF_OperationResult，data 为 GF_SaveStrategy。
func get_save_strategy() -> GF_OperationResult:
	if _mode == GF_RuntimeMode.Mode.LOCAL:
		return GF_OperationResult.ok(GF_SaveStrategy.new())
	return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "Remote/Hybrid 存档策略尚未实现", module_name)
