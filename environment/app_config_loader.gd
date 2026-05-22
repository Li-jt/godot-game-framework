## AppConfigLoader
## 配置加载器。按优先级加载所有配置来源，合并为最终 AppConfig。
##
## 加载优先级（从低到高）：
##   1. Framework 默认值（AppConfig 各字段的初始值）
##   2. config/app_config.json
##   3. config/app_config.{env}.json
##   4. config/feature_flags.json（独立功能开关文件）
##   5. .env
##   6. .env.{env}
##   7. 命令行覆盖（预留）
##   8. 编辑器覆盖（预留）
class_name AppConfigLoader
extends RefCounted


func load(p_project_root: String, p_env_override: String = "") -> OperationResult:
	var config := AppConfig.new()
	var env := _resolve_env(p_env_override)

	# --- app_config.json（必须存在） ---
	var base_json := _load_json(p_project_root + "config/app_config.json")
	if base_json.is_fail():
		return base_json
	_apply_json(config, base_json.data)

	# --- app_config.{env}.json（可选） ---
	var env_json := _load_json(p_project_root + "config/app_config.%s.json" % env)
	if env_json.is_ok():
		_apply_json(config, env_json.data)
	elif env_json.status_code != OperationResult.ERR_NOT_FOUND:
		return env_json

	# --- feature_flags.json（可选） ---
	var flags_json := _load_json(p_project_root + "config/feature_flags.json")
	if flags_json.is_ok():
		_merge_feature_flags(config.feature_flags, flags_json.data)
	elif flags_json.status_code != OperationResult.ERR_NOT_FOUND:
		return flags_json

	# --- .env ---
	var dot_env := _load_text(p_project_root + ".env")
	if not dot_env.is_empty():
		_apply_env(config, EnvParser.parse(dot_env))

	# --- .env.{env} ---
	var dot_env_env := _load_text(p_project_root + ".env.%s" % env)
	if not dot_env_env.is_empty():
		_apply_env(config, EnvParser.parse(dot_env_env))

	var validation = AppConfigValidator.new().validate(config)
	if validation.is_fail():
		return validation

	return OperationResult.ok(config)


# ============================================================
# 内部
# ============================================================

func _resolve_env(p_override: String) -> String:
	if not p_override.is_empty():
		return p_override
	var os_env := OS.get_environment("APP_ENV")
	if not os_env.is_empty():
		return os_env
	return "dev"


# NOTE: 此处直接使用 FileAccess 是合法的 bootstrap 例外（在 FileSystemService 创建之前运行）。
func _load_text(p_path: String) -> String:
	if not FileAccess.file_exists(p_path):
		return ""
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		return ""
	var content := f.get_as_text()
	f.close()
	return content


# NOTE: 此处直接使用 FileAccess 是合法的 bootstrap 例外（在 FileSystemService 创建之前运行）。
func _load_json(p_path: String) -> OperationResult:
	if not FileAccess.file_exists(p_path):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "配置文件不存在: %s" % p_path, "AppConfigLoader")
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		return OperationResult.fail(OperationResult.ERR_IO, "无法打开配置文件: %s" % p_path, "AppConfigLoader")
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return OperationResult.fail(OperationResult.ERR_IO, "JSON 解析失败: %s" % p_path, "AppConfigLoader")
	return OperationResult.ok(parsed)


func _apply_json(p_config: AppConfig, p_dict: Dictionary) -> void:
	for section_key in p_dict.keys():
		var section_value = p_dict[section_key]
		if not section_value is Dictionary:
			continue
		match section_key:
			"app":         _merge_app(p_config.app, section_value)
			"runtime":     _merge_runtime(p_config.runtime, section_value)
			"network":     _merge_network(p_config.network, section_value)
			"save":        _merge_save(p_config.save, section_value)
			"resource":    _merge_resource(p_config.resource, section_value)
			"logging":     _merge_logging(p_config.logging, section_value)
			"threading":   _merge_threading(p_config.threading, section_value)
			"debug":       _merge_debug(p_config.debug, section_value)
			"featureFlags": _merge_feature_flags(p_config.feature_flags, section_value)


func _apply_env(p_config: AppConfig, p_env: Dictionary) -> void:
	_str_field(p_config.app, "name", p_env, "APP_NAME")
	_str_field(p_config.app, "environment", p_env, "APP_ENV")
	_str_field(p_config.app, "version", p_env, "APP_VERSION")

	_str_field(p_config.runtime, "mode", p_env, "RUNTIME_MODE")
	_bool_field(p_config.runtime, "enable_prediction", p_env, "ENABLE_PREDICTION")
	_bool_field(p_config.runtime, "enable_rollback", p_env, "ENABLE_ROLLBACK")

	_str_field(p_config.network, "api_base_url", p_env, "API_BASE_URL")
	_str_field(p_config.network, "ws_url", p_env, "WS_URL")
	_int_field(p_config.network, "request_timeout_ms", p_env, "REQUEST_TIMEOUT_MS")
	_int_field(p_config.network, "retry_count", p_env, "RETRY_COUNT")
	_bool_field(p_config.network, "use_mock_api", p_env, "USE_MOCK_API")

	_str_field(p_config.save, "provider", p_env, "SAVE_PROVIDER")
	_str_field(p_config.save, "local_save_root", p_env, "LOCAL_SAVE_ROOT")
	_str_field(p_config.save, "local_cache_root", p_env, "LOCAL_CACHE_ROOT")
	_bool_field(p_config.save, "auto_save_enabled", p_env, "AUTO_SAVE_ENABLED")
	_int_field(p_config.save, "auto_save_interval_seconds", p_env, "AUTO_SAVE_INTERVAL_SECONDS")

	_str_field(p_config.resource, "mode", p_env, "RESOURCE_MODE")
	_str_field(p_config.resource, "base_path", p_env, "RESOURCE_BASE_PATH")

	_str_field(p_config.logging, "level", p_env, "LOG_LEVEL")
	_bool_field(p_config.logging, "write_to_file", p_env, "LOG_WRITE_TO_FILE")
	_str_field(p_config.logging, "log_root", p_env, "LOG_ROOT")

	_bool_field(p_config.threading, "enabled", p_env, "THREADING_ENABLED")
	_int_field(p_config.threading, "max_active_jobs", p_env, "THREADING_MAX_ACTIVE_JOBS")
	_int_field(p_config.threading, "max_dispatch_per_tick", p_env, "THREADING_MAX_DISPATCH_PER_TICK")
	_int_field(p_config.threading, "default_timeout_ms", p_env, "THREADING_DEFAULT_TIMEOUT_MS")
	_int_field(p_config.threading, "slow_job_warn_ms", p_env, "THREADING_SLOW_JOB_WARN_MS")
	_int_field(p_config.threading, "history_limit", p_env, "THREADING_HISTORY_LIMIT")

	_bool_field(p_config.debug, "enable_debug_panel", p_env, "ENABLE_DEBUG_PANEL")
	_bool_field(p_config.debug, "show_prediction_state", p_env, "SHOW_PREDICTION_STATE")
	_bool_field(p_config.debug, "show_network_stats", p_env, "SHOW_NETWORK_STATS")


# ============================================================
# JSON 子段合并
# ============================================================

func _merge_app(p_target: AppConfig.AppSection, p_dict: Dictionary) -> void:
	_str(p_target, "name", p_dict, "name")
	_str(p_target, "environment", p_dict, "environment")
	_str(p_target, "version", p_dict, "version")


func _merge_runtime(p_target: AppConfig.RuntimeSection, p_dict: Dictionary) -> void:
	_str(p_target, "mode", p_dict, "mode")
	_bool(p_target, "enable_prediction", p_dict, "enablePrediction")
	_bool(p_target, "enable_rollback", p_dict, "enableRollback")
	_bool(p_target, "enable_reconciliation", p_dict, "enableReconciliation")


func _merge_network(p_target: AppConfig.NetworkSection, p_dict: Dictionary) -> void:
	_str(p_target, "api_base_url", p_dict, "apiBaseUrl")
	_str(p_target, "ws_url", p_dict, "wsUrl")
	_int(p_target, "request_timeout_ms", p_dict, "requestTimeoutMs")
	_int(p_target, "retry_count", p_dict, "retryCount")
	_bool(p_target, "use_mock_api", p_dict, "useMockApi")


func _merge_save(p_target: AppConfig.SaveSection, p_dict: Dictionary) -> void:
	_str(p_target, "provider", p_dict, "provider")
	_str(p_target, "local_save_root", p_dict, "localSaveRoot")
	_str(p_target, "local_cache_root", p_dict, "localCacheRoot")
	_bool(p_target, "auto_save_enabled", p_dict, "autoSaveEnabled")
	_int(p_target, "auto_save_interval_seconds", p_dict, "autoSaveIntervalSeconds")
	_str(p_target, "remote_save_endpoint", p_dict, "remoteSaveEndpoint")


func _merge_resource(p_target: AppConfig.ResourceSection, p_dict: Dictionary) -> void:
	_str(p_target, "mode", p_dict, "mode")
	_str(p_target, "base_path", p_dict, "basePath")
	_bool(p_target, "enable_cache", p_dict, "enableCache")


func _merge_logging(p_target: AppConfig.LoggingSection, p_dict: Dictionary) -> void:
	_str(p_target, "level", p_dict, "level")
	_bool(p_target, "write_to_file", p_dict, "writeToFile")
	_str(p_target, "log_root", p_dict, "logRoot")


func _merge_threading(p_target: AppConfig.ThreadingSection, p_dict: Dictionary) -> void:
	_bool(p_target, "enabled", p_dict, "enabled")
	_int(p_target, "max_active_jobs", p_dict, "maxActiveJobs")
	_int(p_target, "max_dispatch_per_tick", p_dict, "maxDispatchPerTick")
	_int(p_target, "default_timeout_ms", p_dict, "defaultTimeoutMs")
	_int(p_target, "slow_job_warn_ms", p_dict, "slowJobWarnMs")
	_int(p_target, "history_limit", p_dict, "historyLimit")


func _merge_debug(p_target: AppConfig.DebugSection, p_dict: Dictionary) -> void:
	_bool(p_target, "enable_debug_panel", p_dict, "enableDebugPanel")
	_bool(p_target, "show_prediction_state", p_dict, "showPredictionState")
	_bool(p_target, "show_network_stats", p_dict, "showNetworkStats")


func _merge_feature_flags(p_target: AppConfig.FeatureFlagsSection, p_dict: Dictionary) -> void:
	_bool(p_target, "enable_remote_authority", p_dict, "enableRemoteAuthority")
	_bool(p_target, "enable_cloud_save", p_dict, "enableCloudSave")
	_bool(p_target, "enable_local_fallback", p_dict, "enableLocalFallback")
	_bool(p_target, "enable_prediction", p_dict, "enablePrediction")
	_bool(p_target, "enable_rollback", p_dict, "enableRollback")
	_bool(p_target, "enable_debug_panel", p_dict, "enableDebugPanel")
	_bool(p_target, "enable_network_stats", p_dict, "enableNetworkStats")
	_bool(p_target, "enable_auto_save", p_dict, "enableAutoSave")
	_bool(p_target, "enable_tutorial", p_dict, "enableTutorial")


# ============================================================
# 通用字段设置辅助
# ============================================================

func _str(p_obj: Object, p_field: String, p_dict: Dictionary, p_key: String) -> void:
	if p_dict.has(p_key):
		p_obj.set(p_field, str(p_dict[p_key]))

func _bool(p_obj: Object, p_field: String, p_dict: Dictionary, p_key: String) -> void:
	if p_dict.has(p_key):
		p_obj.set(p_field, bool(p_dict[p_key]))

func _int(p_obj: Object, p_field: String, p_dict: Dictionary, p_key: String) -> void:
	if p_dict.has(p_key):
		p_obj.set(p_field, int(p_dict[p_key]))

func _str_field(p_obj: Object, p_field: String, p_env: Dictionary, p_key: String) -> void:
	if p_env.has(p_key):
		p_obj.set(p_field, p_env[p_key])

func _bool_field(p_obj: Object, p_field: String, p_env: Dictionary, p_key: String) -> void:
	if p_env.has(p_key):
		var v = p_env[p_key].to_lower()
		p_obj.set(p_field, v == "true" or v == "1" or v == "yes")

func _int_field(p_obj: Object, p_field: String, p_env: Dictionary, p_key: String) -> void:
	if p_env.has(p_key):
		p_obj.set(p_field, int(p_env[p_key]))
