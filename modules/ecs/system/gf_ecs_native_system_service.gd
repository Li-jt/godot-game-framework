# modules/ecs/system/gf_ecs_native_system_service.gd
## GF_EcsNativeSystemService — 原生系统执行环境的调度接入（性能路线图 §1.7）。
## 包装 C++ 的 GF_EcsNativeSystemHost，接入框架 GF_Scheduler：
##   1. set_world(NATIVE 后端的 GF_EcsWorld)
##   2. register_system("工厂名", [组件 class_name...])——按名实例化使用方 C++ 系统
##   3. bind_to_scheduler()——挂 SIMULATION 组，每渲染帧 tick_all(delta)
##
## 原生系统本体（C++ 子类 + 工厂注册宏）由使用方编写并编进扩展，
## 见 gdextension/src/gf_ecs_native_system.h 与 docs 开发指南。
class_name GF_EcsNativeSystemService
extends GF_ModuleLifecycle

var _host: GF_EcsNativeSystemHost = null
var _world: GF_EcsWorld = null
var _tick_handle: GF_Scheduler.TickHandle = null


func _on_init() -> GF_OperationResult:
	_host = GF_EcsNativeSystemHost.new()
	return GF_OperationResult.ok()


func _on_dispose() -> GF_OperationResult:
	if _tick_handle != null and _bootstrap != null:
		var sched := _bootstrap.service(GF_Scheduler) as GF_Scheduler
		if sched != null:
			sched.unregister_by_handle(_tick_handle)
	_tick_handle = null
	_host = null
	return GF_OperationResult.ok()


## 关联世界。必须是 NATIVE 后端的 GF_EcsWorld（原生系统只作用于原生后端）。
func set_world(p_world: GF_EcsWorld) -> GF_OperationResult:
	if p_world == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "世界不能为 null", module_name)
	var backend: GF_EcsNativeBackend = p_world._get_native_backend()
	if backend == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST,
			"GF_EcsNativeSystemService 需要 NATIVE 后端的 GF_EcsWorld", module_name)
	_world = p_world
	_host.attach_world(backend.get_native_world())
	return GF_OperationResult.ok()


## 按名注册使用方原生系统。
## [param p_name] 工厂名（使用方 GF_NATIVE_SYSTEM_REGISTER 宏注册的名字）
## [param p_read_types] 系统读取的组件 class_name 列表；顺序决定 tick 内
## 列索引（field 0 = 第一个类型，依此类推——Flecs 4 字段索引 0-based）
func register_system(p_name: String, p_read_types: Array) -> GF_OperationResult:
	if _world == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_PRECONDITION, "先 set_world", module_name)
	var keys := PackedInt64Array()
	for p_type in p_read_types:
		var type_id: int = _world._get_registry().type_id_of(p_type)
		if type_id == 0:
			return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND,
				"组件类型未注册: %s" % str(p_type), module_name)
		keys.append(type_id)
	if not _host.register_system(p_name, keys):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND,
			"原生系统工厂未注册: '%s'（检查使用方宏注册与编译链接）" % p_name, module_name)
	return GF_OperationResult.ok()


## 绑定到框架调度器 SIMULATION 组（每渲染帧 tick，delta 为帧间隔）。
func bind_to_scheduler() -> GF_OperationResult:
	var sched := _bootstrap.service(GF_Scheduler) as GF_Scheduler
	if sched == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_PRECONDITION, "GF_Scheduler 未注册", module_name)
	_tick_handle = sched.register(GF_Scheduler.TickGroup.SIMULATION, "EcsNativeSystems", _on_tick)
	return GF_OperationResult.ok()


func _on_tick(p_delta: float) -> void:
	_host.tick_all(p_delta)
