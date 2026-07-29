## GF_ModuleLifecycle
## 模块生命周期基类。
## 所有 Framework 服务模块应继承此类，统一生命周期管理。
##
## 子类使用方式：
##   [codeblock]
##   class_name MyService
##   extends GF_ModuleLifecycle
##
##   func _on_init() -> GF_OperationResult:
##       # 执行初始化逻辑
##       return GF_OperationResult.ok()
##
##   func _on_dispose() -> GF_OperationResult:
##       # 执行释放逻辑
##       return GF_OperationResult.ok()
##   [/codeblock]
##
## 外部使用方式：
##   [codeblock]
##   var service := MyService.new()
##   service.module_name = "MyService"
##   var result := service.init_module()
##   if result.is_fail():
##       printerr("初始化失败: ", result.error.message)
##   [/codeblock]
class_name GF_ModuleLifecycle
extends RefCounted

## 当前生命周期状态
var state: GF_CoreLifecycleState.State = GF_CoreLifecycleState.State.UNINITIALIZED

## 模块名称，初始化前由外部设置，用于日志和错误追踪
var module_name: String = ""

## 执行初始化。幂等：重复调用 READY 状态不会重新初始化。
## 失败后不允许再次调用，需由上层决定降级或退出。
func init_module() -> GF_OperationResult:
	if state == GF_CoreLifecycleState.State.READY:
		return GF_OperationResult.ok()
	if state == GF_CoreLifecycleState.State.DISPOSED:
		return GF_OperationResult.fail(GF_OperationResult.ERR_DISPOSED, "模块已释放: %s" % module_name, module_name)

	state = GF_CoreLifecycleState.State.INITIALIZING
	var result := _on_init()
	if result.success:
		state = GF_CoreLifecycleState.State.INITIALIZED
	else:
		state = GF_CoreLifecycleState.State.FAILED
	return result

## 释放模块资源。幂等：重复调用不会报错。
func dispose_module() -> GF_OperationResult:
	if state == GF_CoreLifecycleState.State.DISPOSED:
		return GF_OperationResult.ok()

	var result := _on_dispose()
	state = GF_CoreLifecycleState.State.DISPOSED
	return result

## 模块是否已就绪
func is_ready() -> bool:
	return state == GF_CoreLifecycleState.State.READY

## 模块是否已失败
func is_failed() -> bool:
	return state == GF_CoreLifecycleState.State.FAILED


## 标记配置完成，从 INITIALIZED 进入 READY。
## 由 GF_AppBootstrap._cfg_or_fail() 在 configure 成功后自动调用。
func finalize_configuration() -> GF_OperationResult:
	if state == GF_CoreLifecycleState.State.READY:
		return GF_OperationResult.ok()
	if state != GF_CoreLifecycleState.State.INITIALIZED:
		return GF_OperationResult.fail(GF_OperationResult.ERR_PRECONDITION, "只能在 INITIALIZED 状态调用: %d" % state, module_name)
	state = GF_CoreLifecycleState.State.CONFIGURING
	state = GF_CoreLifecycleState.State.READY
	return GF_OperationResult.ok()


func is_initialized() -> bool:
	return state == GF_CoreLifecycleState.State.INITIALIZED

# ============================================================
# 子类重写 —— 以下方法由子类实现具体逻辑
# ============================================================

## 子类重写：执行模块初始化逻辑，返回 GF_OperationResult
func _on_init() -> GF_OperationResult:
	return GF_OperationResult.ok()

## 子类重写：执行模块释放逻辑，返回 GF_OperationResult
func _on_dispose() -> GF_OperationResult:
	return GF_OperationResult.ok()
