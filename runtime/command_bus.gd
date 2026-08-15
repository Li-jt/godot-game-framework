## GF_CommandBus
## 框架级命令总线（最小版）。负责：
## 1) 命令校验调用
## 2) 命令键路由到 Handler
## 3) Handler 缺失时回退到命令对象 execute()
##
## 设计目标：先提供稳定入口，不绑定具体游戏语义；
## 后续 Remote / Hybrid 可在 RuntimeStrategy 中复用同一入口。
class_name GF_CommandBus
extends RefCounted

var _handlers: Dictionary = {}  # String command_key -> handler

## 可选命令日志（性能路线图 §3.3）。attach_command_log 接线后，
## execute 时自动记录确定性命令（validate 通过后、执行前）。
var command_log: GF_CommandLog = null


## 注册命令处理器。重复注册会覆盖旧处理器。
func register_handler(p_handler) -> GF_OperationResult:
	if p_handler == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "handler 不能为 null", "GF_CommandBus")
	if not p_handler.has_method("command_key") or not p_handler.has_method("handle"):
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "handler 必须实现 command_key()/handle()", "GF_CommandBus")
	var key: String = str(p_handler.command_key())
	if key.is_empty():
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "handler.command_key 不能为空", "GF_CommandBus")
	_handlers[key] = p_handler
	return GF_OperationResult.ok()


## 注销指定命令键的处理器。
func unregister_handler(p_command_key: String) -> void:
	_handlers.erase(p_command_key)


## 清空全部处理器。
func clear_handlers() -> void:
	_handlers.clear()


## 执行命令。优先走 Handler，若无 Handler 则回退到命令对象 execute。
func execute(p_command, p_context: Dictionary) -> GF_OperationResult:
	if p_command == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "command 不能为 null", "GF_CommandBus")

	var validate_result := _validate_command(p_command, p_context)
	if validate_result.is_fail():
		return validate_result

	var key := _resolve_command_key(p_command)
	if command_log != null and command_log.is_enabled():
		command_log.record_command(p_command, key)

	if not key.is_empty() and _handlers.has(key):
		return _handlers[key].handle(p_command, p_context)

	if p_command.has_method("execute"):
		return p_command.execute(p_context)

	return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "未找到命令处理器且命令不可直接执行: %s" % key, "GF_CommandBus")


## 接线命令日志。execute 时自动记录确定性命令。
func attach_command_log(p_log: GF_CommandLog) -> void:
	command_log = p_log


## 查询命令键是否已注册处理器。
func has_handler(p_command_key: String) -> bool:
	return _handlers.has(p_command_key)


## 返回当前已注册命令键列表。
func get_registered_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in _handlers.keys():
		keys.append(key)
	return keys


## 命令总线内部校验入口：命令实现了 validate() 时执行。
func _validate_command(p_command, p_context: Dictionary) -> GF_OperationResult:
	if p_command.has_method("validate"):
		var result = p_command.validate(p_context)
		if result is GF_OperationResult:
			return result
		return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "validate() 必须返回 GF_OperationResult", "GF_CommandBus")
	return GF_OperationResult.ok()


## 解析命令键。优先 command_key()，兼容旧命令的 command_type()。
func _resolve_command_key(p_command) -> String:
	if p_command.has_method("command_key"):
		var key = p_command.command_key()
		return "" if key == null else str(key)
	if p_command.has_method("command_type"):
		var type = p_command.command_type()
		return "" if type == null else str(type)
	return ""
