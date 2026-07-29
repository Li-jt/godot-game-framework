## GF_ConfigSummary
## 配置摘要工具。将当前生效配置格式化输出到日志。
## 启动时自动调用一次，运行时也可随时调用用于调试。
class_name GF_ConfigSummary
extends RefCounted


## 将 GF_AppConfig 的完整摘要输出到 GF_LogService
static func print_to_log(p_config: GF_AppConfig, p_log: GF_LogService) -> void:
	p_log.info("GF_ConfigSummary", "========== 运行配置 ==========")
	p_log.info("GF_ConfigSummary", _kv("Environment", p_config.app.environment))
	p_log.info("GF_ConfigSummary", _kv("App Name", p_config.app.name))
	p_log.info("GF_ConfigSummary", _kv("Version", p_config.app.version))
	p_log.info("GF_ConfigSummary", "")
	p_log.info("GF_ConfigSummary", "--- 运行模式 ---")
	p_log.info("GF_ConfigSummary", _kv("GF_RuntimeMode", p_config.runtime.mode))
	p_log.info("GF_ConfigSummary", _kv("Prediction", p_config.runtime.enable_prediction))
	p_log.info("GF_ConfigSummary", _kv("Rollback", p_config.runtime.enable_rollback))
	p_log.info("GF_ConfigSummary", _kv("Reconciliation", p_config.runtime.enable_reconciliation))
	p_log.info("GF_ConfigSummary", "")
	p_log.info("GF_ConfigSummary", "--- 网络 ---")
	p_log.info("GF_ConfigSummary", _kv("API Base URL", p_config.network.api_base_url))
	p_log.info("GF_ConfigSummary", _kv("WS URL", p_config.network.ws_url))
	p_log.info("GF_ConfigSummary", _kv("Timeout (ms)", p_config.network.request_timeout_ms))
	p_log.info("GF_ConfigSummary", _kv("Retry Count", p_config.network.retry_count))
	p_log.info("GF_ConfigSummary", _kv("Mock API", p_config.network.use_mock_api))
	p_log.info("GF_ConfigSummary", "")
	p_log.info("GF_ConfigSummary", "--- 存档 ---")
	p_log.info("GF_ConfigSummary", _kv("GF_SaveProvider", p_config.save.provider))
	p_log.info("GF_ConfigSummary", _kv("Local Save Root", p_config.save.local_save_root))
	p_log.info("GF_ConfigSummary", _kv("Local Cache Root", p_config.save.local_cache_root))
	p_log.info("GF_ConfigSummary", _kv("Auto Save", p_config.save.auto_save_enabled))
	p_log.info("GF_ConfigSummary", _kv("Auto Save Interval", p_config.save.auto_save_interval_seconds))
	p_log.info("GF_ConfigSummary", "")
	p_log.info("GF_ConfigSummary", "--- 日志 ---")
	p_log.info("GF_ConfigSummary", _kv("Log Level", p_config.logging.level))
	p_log.info("GF_ConfigSummary", _kv("Write To File", p_config.logging.write_to_file))
	p_log.info("GF_ConfigSummary", _kv("Log Root", p_config.logging.log_root))
	p_log.info("GF_ConfigSummary", "")
	p_log.info("GF_ConfigSummary", "--- 线程 ---")
	p_log.info("GF_ConfigSummary", _kv("Threading Enabled", p_config.threading.enabled))
	p_log.info("GF_ConfigSummary", _kv("Max Active Jobs", p_config.threading.max_active_jobs))
	p_log.info("GF_ConfigSummary", _kv("Dispatch Per Tick", p_config.threading.max_dispatch_per_tick))
	p_log.info("GF_ConfigSummary", _kv("Default Timeout (ms)", p_config.threading.default_timeout_ms))
	p_log.info("GF_ConfigSummary", _kv("Slow Warn (ms)", p_config.threading.slow_job_warn_ms))
	p_log.info("GF_ConfigSummary", _kv("History Limit", p_config.threading.history_limit))
	p_log.info("GF_ConfigSummary", "")
	p_log.info("GF_ConfigSummary", "--- 调试 ---")
	p_log.info("GF_ConfigSummary", _kv("Debug Panel", p_config.debug.enable_debug_panel))
	p_log.info("GF_ConfigSummary", _kv("Show Prediction", p_config.debug.show_prediction_state))
	p_log.info("GF_ConfigSummary", _kv("Show Network Stats", p_config.debug.show_network_stats))
	p_log.info("GF_ConfigSummary", "")
	p_log.info("GF_ConfigSummary", "--- 功能开关 ---")
	p_log.info("GF_ConfigSummary", _kv("Remote Authority", p_config.feature_flags.enable_remote_authority))
	p_log.info("GF_ConfigSummary", _kv("Cloud Save", p_config.feature_flags.enable_cloud_save))
	p_log.info("GF_ConfigSummary", _kv("Local Fallback", p_config.feature_flags.enable_local_fallback))
	p_log.info("GF_ConfigSummary", _kv("Auto Save", p_config.feature_flags.enable_auto_save))
	p_log.info("GF_ConfigSummary", _kv("Tutorial", p_config.feature_flags.enable_tutorial))
	p_log.info("GF_ConfigSummary", "========================================")


static func _kv(p_key: String, p_value) -> String:
	return "  %-20s  %s" % [p_key, str(p_value)]
