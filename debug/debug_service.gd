## DebugService
## 调试服务。管理调试面板注册、运行时统计、命令追踪。
## 仅在 config.debug.enable_debug_panel = true 时启用。
class_name DebugService
extends ModuleLifecycle

var enabled: bool = false
var _log: LogService = null

# 面板注册: name -> factory（无参返回 Node）
var panels: Dictionary = {}

# 运行时统计
var fps: float = 0.0
var frame_time_ms: float = 0.0
var _frame_count: int = 0
var _elapsed: float = 0.0

# 命令追踪
var command_trace_enabled: bool = false
var _command_history: Array = []    # Array[Dictionary]
const MAX_COMMAND_HISTORY: int = 200

# 网络统计
var network_requests: int = 0
var network_errors: int = 0


func _on_init() -> OperationResult:
	return OperationResult.ok()


func configure(p_config: AppConfig.DebugSection, p_log: LogService) -> OperationResult:
	if p_config == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "debug_config 不能为 null", module_name)
	if p_log == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "log 不能为 null", module_name)
	enabled = p_config.enable_debug_panel
	command_trace_enabled = p_config.show_prediction_state
	_log = p_log
	return OperationResult.ok()


# ============================================================
# 面板管理
# ============================================================

func register_panel(p_name: String, p_factory: Callable) -> void:
	panels[p_name] = p_factory


func get_panel_names() -> Array[String]:
	var names: Array[String] = []
	names.assign(panels.keys())
	return names


# ============================================================
# 运行时统计
# ============================================================

## 由 Scheduler TickGroup.DEBUG 每帧调用
func tick_stats(p_delta: float) -> void:
	if not enabled:
		return
	_frame_count += 1
	_elapsed += p_delta
	if _elapsed >= 1.0:
		fps = _frame_count / _elapsed
		frame_time_ms = (_elapsed / _frame_count) * 1000.0
		_frame_count = 0
		_elapsed = 0.0


# ============================================================
# 命令追踪
# ============================================================

func trace_command(p_id: String, p_type: String, p_state: String = "executed") -> void:
	if not command_trace_enabled:
		return
	_command_history.append({
		"id": p_id,
		"type": p_type,
		"state": p_state,
		"time": Time.get_datetime_string_from_system(false, true),
	})
	while _command_history.size() > MAX_COMMAND_HISTORY:
		_command_history.pop_front()


func get_command_history() -> Array:
	return _command_history


# ============================================================
# 网络统计
# ============================================================

func record_network_request(p_success: bool) -> void:
	network_requests += 1
	if not p_success:
		network_errors += 1


func reset_network_stats() -> void:
	network_requests = 0
	network_errors = 0
