## ConfigSummary
## 配置摘要工具。将当前生效配置格式化输出到日志。
## 启动时自动调用一次，运行时也可随时调用用于调试。
class_name ConfigSummary
extends RefCounted


## 将 AppConfig 的完整摘要输出到 LogService
static func print_to_log(p_config: AppConfig, p_log: LogService) -> void:
	p_log.info("ConfigSummary", "========== 运行配置 ==========")
	p_log.info("ConfigSummary", _kv("Environment", p_config.app.environment))
	p_log.info("ConfigSummary", _kv("App Name", p_config.app.name))
	p_log.info("ConfigSummary", _kv("Version", p_config.app.version))
	p_log.info("ConfigSummary", "")
	p_log.info("ConfigSummary", "--- 运行模式 ---")
	p_log.info("ConfigSummary", _kv("RuntimeMode", p_config.runtime.mode))
	p_log.info("ConfigSummary", _kv("Prediction", p_config.runtime.enable_prediction))
	p_log.info("ConfigSummary", _kv("Rollback", p_config.runtime.enable_rollback))
	p_log.info("ConfigSummary", _kv("Reconciliation", p_config.runtime.enable_reconciliation))
	p_log.info("ConfigSummary", "")
	p_log.info("ConfigSummary", "--- 网络 ---")
	p_log.info("ConfigSummary", _kv("API Base URL", p_config.network.api_base_url))
	p_log.info("ConfigSummary", _kv("WS URL", p_config.network.ws_url))
	p_log.info("ConfigSummary", _kv("Timeout (ms)", p_config.network.request_timeout_ms))
	p_log.info("ConfigSummary", _kv("Retry Count", p_config.network.retry_count))
	p_log.info("ConfigSummary", _kv("Mock API", p_config.network.use_mock_api))
	p_log.info("ConfigSummary", "")
	p_log.info("ConfigSummary", "--- 存档 ---")
	p_log.info("ConfigSummary", _kv("SaveProvider", p_config.save.provider))
	p_log.info("ConfigSummary", _kv("Local Save Root", p_config.save.local_save_root))
	p_log.info("ConfigSummary", _kv("Local Cache Root", p_config.save.local_cache_root))
	p_log.info("ConfigSummary", _kv("Auto Save", p_config.save.auto_save_enabled))
	p_log.info("ConfigSummary", _kv("Auto Save Interval", p_config.save.auto_save_interval_seconds))
	p_log.info("ConfigSummary", "")
	p_log.info("ConfigSummary", "--- 日志 ---")
	p_log.info("ConfigSummary", _kv("Log Level", p_config.logging.level))
	p_log.info("ConfigSummary", _kv("Write To File", p_config.logging.write_to_file))
	p_log.info("ConfigSummary", _kv("Log Root", p_config.logging.log_root))
	p_log.info("ConfigSummary", "")
	p_log.info("ConfigSummary", "--- 调试 ---")
	p_log.info("ConfigSummary", _kv("Debug Panel", p_config.debug.enable_debug_panel))
	p_log.info("ConfigSummary", _kv("Show Prediction", p_config.debug.show_prediction_state))
	p_log.info("ConfigSummary", _kv("Show Network Stats", p_config.debug.show_network_stats))
	p_log.info("ConfigSummary", "")
	p_log.info("ConfigSummary", "--- 功能开关 ---")
	p_log.info("ConfigSummary", _kv("Remote Authority", p_config.feature_flags.enable_remote_authority))
	p_log.info("ConfigSummary", _kv("Cloud Save", p_config.feature_flags.enable_cloud_save))
	p_log.info("ConfigSummary", _kv("Local Fallback", p_config.feature_flags.enable_local_fallback))
	p_log.info("ConfigSummary", _kv("Auto Save", p_config.feature_flags.enable_auto_save))
	p_log.info("ConfigSummary", _kv("Tutorial", p_config.feature_flags.enable_tutorial))
	p_log.info("ConfigSummary", "========================================")


static func _kv(p_key: String, p_value) -> String:
	return "  %-20s  %s" % [p_key, str(p_value)]
