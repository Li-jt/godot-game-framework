## GF_AppBootstrap
## 框架启动入口。Game 层继承此类，在 _assemble() 中按需注册服务。
class_name GF_AppBootstrap
extends Node

var focus_navigation_default_mode: Control.FocusMode = Control.FOCUS_ALL
var _services: Array = []
var _builtins_installed: bool = false


func _ready() -> void:
	_ensure_builtins()
	_assemble()
	_init_all()
	_on_ready()


func _ensure_builtins() -> void:
	if _builtins_installed:
		return
	_install_builtins()
	_builtins_installed = true


# ============================================================
# 子类重写
# ============================================================

func _assemble() -> void:
	pass


func _on_ready() -> void:
	pass


# ============================================================
# 公开 API
# ============================================================

func register(p_what) -> GF_OperationResult:
	_ensure_builtins()
	if p_what is Array:
		for item in p_what:
			var r: GF_OperationResult = register(item)
			if r.is_fail(): return r
		return GF_OperationResult.ok()

	if p_what == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "服务不能为 null", "GF_AppBootstrap")
	var cls: Variant = p_what.get_script()
	for svc: Variant in _services:
		if svc.get_script() == cls:
			return GF_OperationResult.fail(
				GF_OperationResult.ERR_CONFLICT,
				"服务已注册: %s" % cls.resource_path,
				"GF_AppBootstrap"
			)
	_services.append(p_what)
	if p_what.has_method("_set_bootstrap"):
		p_what._set_bootstrap(self)
	return GF_OperationResult.ok()


func service(p_class) -> Variant:
	_ensure_builtins()
	for svc in _services:
		if is_instance_of(svc, p_class):
			return svc
	return null


## 发送命令。Command 是改变状态的一等公民入口。
## 内部委托给 GF_RuntimeService 的策略执行。
## 用法：var r := send_command(MyCommand.new())
func send_command(p_command, p_context: Dictionary = {}) -> GF_OperationResult:
	var runtime: GF_RuntimeService = service(GF_RuntimeService) as GF_RuntimeService
	if runtime == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_PRECONDITION, "GF_RuntimeService 未就绪", "GF_AppBootstrap")
	var strategy_result: GF_OperationResult = runtime.get_command_strategy()
	if strategy_result.is_fail():
		return strategy_result
	var strategy = strategy_result.data
	return strategy.execute(p_command, p_context)


# ============================================================
# 内部
# ============================================================

func _install_builtins() -> void:
	_add_builtin(GF_LogService.new())
	_add_builtin(GF_EventBus.new())
	_add_builtin(GF_PathResolver.new())

	var scheduler: GF_Scheduler = GF_Scheduler.new()
	scheduler.name = "GF_Scheduler"
	add_child(scheduler)
	_add_builtin(scheduler)

	_add_builtin(GF_FileSystemService.new())
	_add_builtin(GF_RuntimeService.new())


func _add_builtin(p_service) -> void:
	_services.append(p_service)
	if p_service.has_method("_set_bootstrap"):
		p_service._set_bootstrap(self)


func _init_all() -> void:
	for svc: Variant in _services:
		if svc is GF_ModuleLifecycle and not svc.is_ready():
			var r: GF_OperationResult = svc.init_module()
			if r.is_fail():
				push_error("GF_AppBootstrap: init 失败")

	var sorted: Array = _topo_sort()

	for svc: Variant in sorted:
		if svc is GF_ModuleLifecycle:
			if svc.has_method("configure"):
				svc.configure()
			svc.finalize_configuration()


func _topo_sort() -> Array:
	var in_degree: Dictionary = {}
	var deps_graph: Dictionary = {}

	for svc: Variant in _services:
		var deps: Array = svc.dependencies() if svc.has_method("dependencies") else []
		deps_graph[svc] = deps
		if not in_degree.has(svc):
			in_degree[svc] = 0

		for dep_class in deps:
			var dep_svc: Variant = _find_svc_by_class(dep_class)
			if dep_svc == null:
				push_warning("GF_AppBootstrap: dep missing")
				continue
			in_degree[svc] = in_degree.get(svc, 0) + 1

	var queue: Array = []
	for svc: Variant in _services:
		if in_degree.get(svc, 0) == 0:
			queue.append(svc)

	var result: Array = []
	while not queue.is_empty():
		var svc: Variant = queue.pop_front()
		result.append(svc)

		for other in deps_graph:
			var other_deps: Array = deps_graph[other]
			for dep_class in other_deps:
				if is_instance_of(svc, dep_class):
					in_degree[other] = in_degree[other] - 1
					if in_degree[other] == 0:
						queue.append(other)

	return result


func _find_svc_by_class(p_class) -> Variant:
	for s: Variant in _services:
		if is_instance_of(s, p_class):
			return s
	return null
