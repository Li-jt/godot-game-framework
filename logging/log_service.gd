## LogService
## 统一日志服务。所有模块通过此服务输出日志，禁止直接使用 print()。
##
## 文件输出按「级别 / 日期 / 小时段」分层存储：
##   {log_root}/
##   ├── ERROR/2026-05-13/15:00:00-16:00:00.log
##   ├── WARNING/...
##   ├── INFO/...
##   └── DEBUG/...
##
## 使用方式：
##   var log: LogService = injected_log
##   log.info("Bootstrap", "应用启动")
class_name LogService
extends ModuleLifecycle

var _level: LogLevel.Level = LogLevel.Level.DEBUG
var _write_to_file: bool = false
var _log_root: String = "./logs"
var _sinks: Array[LogSink] = []
var _memory_sink: MemoryLogSink = null

var _active_files: Dictionary = {}
var _active_file_paths: Dictionary = {}
var _active_hour: int = -1


## 配置日志服务。
## p_path_resolver 可选：传入时使用其 get_log_root() 解析路径，
## 否则回退到 AppConfig 原始值（bootstrap 场景兼容）。
func configure(p_config: AppConfig.LoggingSection, p_path_resolver: PathResolver = null) -> OperationResult:
	if p_config == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: config 不能为 null", module_name)

	_level = LogLevel.parse(p_config.level)
	_write_to_file = p_config.write_to_file
	_log_root = p_path_resolver.get_log_root() if p_path_resolver != null else p_config.log_root
	return OperationResult.ok()


func _on_dispose() -> OperationResult:
	_close_all_files()
	return OperationResult.ok()


# ============================================================
# Sink 管理
# ============================================================

## 注册外部 Sink。启动时注册 MemoryLogSink 供 Debug 面板使用。
func register_sink(p_sink: LogSink) -> void:
	_sinks.append(p_sink)


## 获取内置 MemorySink（懒初始化）
func get_memory_sink() -> MemoryLogSink:
	if _memory_sink == null:
		_memory_sink = MemoryLogSink.new(500)
		_sinks.append(_memory_sink)
	return _memory_sink


## 移除注册的 Sink
func remove_sink(p_sink: LogSink) -> void:
	_sinks.erase(p_sink)


# ============================================================
# 公开日志方法
# ============================================================

func debug(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void:
	_log(LogLevel.Level.DEBUG, p_tag, p_message, p_context)


func info(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void:
	_log(LogLevel.Level.INFO, p_tag, p_message, p_context)


func warning(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void:
	_log(LogLevel.Level.WARNING, p_tag, p_message, p_context)


func error(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void:
	_log(LogLevel.Level.ERROR, p_tag, p_message, p_context)


# ============================================================
# 内部
# ============================================================

func _log(p_level: LogLevel.Level, p_tag: String, p_message: String, p_context: Dictionary) -> void:
	if p_level < _level:
		return

	var time_str := Time.get_datetime_string_from_system(false, true)
	var plain := "[%s] [%s] [%s] %s" % [time_str, LogLevel.level_name(p_level), p_tag, p_message]

	# 控制台输出
	_print_rich_line(p_level, plain)

	# 文件输出
	if _write_to_file:
		_write_line_to_file(p_level, plain)

	# Sink 分发
	for sink in _sinks:
		if p_level >= sink.min_level:
			sink.write(p_level, p_tag, p_message, p_context)


func _print_rich_line(p_level: LogLevel.Level, p_line: String) -> void:
	match p_level:
		LogLevel.Level.DEBUG:
			print_rich("[color=#787878]%s[/color]" % p_line)
		LogLevel.Level.INFO:
			print_rich(p_line)
		LogLevel.Level.WARNING:
			print_rich("[bgcolor=#ef6c00][color=black]%s[/color][/bgcolor]" % p_line)
			push_warning(p_line)
		LogLevel.Level.ERROR:
			print_rich("[bgcolor=#c62828][color=white]%s[/color][/bgcolor]" % p_line)
			push_error(p_line)


# ============================================================
# 文件写入（级别/日期/小时 分层）
# ============================================================

func _write_line_to_file(p_level: LogLevel.Level, p_line: String) -> void:
	var now := Time.get_datetime_dict_from_system()
	var hour = now.hour

	if hour != _active_hour:
		_close_all_files()
		_active_hour = hour

	var level_key: int = p_level
	var path := _build_file_path(p_level, now)

	if not _active_files.has(level_key) or _active_file_paths.get(level_key, "") != path:
		_close_file(level_key)
		var fa := _open_or_create(path)
		if fa != null:
			_active_files[level_key] = fa
			_active_file_paths[level_key] = path

	var fa: FileAccess = _active_files.get(level_key, null)
	if fa != null:
		fa.store_line(p_line)


func _build_file_path(p_level: LogLevel.Level, p_now: Dictionary) -> String:
	var date_dir := "%04d-%02d-%02d" % [p_now.year, p_now.month, p_now.day]
	var hour_start := "%02d:00:00" % p_now.hour
	var hour_end := "%02d:00:00" % (p_now.hour + 1)
	var file_name := "%s-%s.log" % [hour_start, hour_end]

	return _log_root\
		.path_join(LogLevel.level_name(p_level))\
		.path_join(date_dir)\
		.path_join(file_name)


# NOTE: 此处直接使用 DirAccess/FileAccess 是合法的 bootstrap 例外。
# LogService 可能在没有 FileSystemService 的场景下运行（配置加载失败仍需输出日志）。
func _open_or_create(p_path: String) -> FileAccess:
	var dir := p_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var err := DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			push_warning("LogService: 无法创建日志目录: %s" % dir)
			return null

	var fa := FileAccess.open(p_path, FileAccess.READ_WRITE)
	if fa == null:
		push_warning("LogService: 无法打开日志文件: %s" % p_path)
		return null
	fa.seek_end()
	return fa


func _close_file(p_level: int) -> void:
	var fa: FileAccess = _active_files.get(p_level, null)
	if fa != null:
		fa.close()
	_active_files.erase(p_level)
	_active_file_paths.erase(p_level)


func _close_all_files() -> void:
	for key in _active_files.keys():
		var fa: FileAccess = _active_files[key]
		if fa != null:
			fa.close()
	_active_files.clear()
	_active_file_paths.clear()
