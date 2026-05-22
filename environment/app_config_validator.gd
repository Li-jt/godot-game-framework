## AppConfigValidator
## 配置校验器。检查合并后的 AppConfig 是否满足运行要求。
## 一次校验收集全部错误，不遇第一个就返回，方便开发者一次修完。
##
## 校验规则来源：设计文档 6.10 节 / 30.3 节
class_name AppConfigValidator
extends RefCounted

# 合法的运行时模式
const VALID_RUNTIME_MODES := ["Local", "Remote", "Hybrid"]
const VALID_SAVE_PROVIDERS := ["Local", "Remote", "Hybrid"]
const VALID_ENVIRONMENTS := ["dev", "test", "prod"]


## 校验 AppConfig，通过返回 OperationResult.ok()
## 不通过返回 OperationResult.fail()，error.context["errors"] 包含逐条错误字符串
func validate(p_config: AppConfig) -> OperationResult:
	var errors: Array[String] = []

	_validate_app(p_config.app, errors)
	_validate_runtime(p_config.runtime, errors)
	_validate_network(p_config.network, p_config.runtime, errors)
	_validate_save(p_config.save, errors)
	_validate_resource(p_config.resource, errors)
	_validate_logging(p_config.logging, errors)
	_validate_threading(p_config.threading, errors)

	if errors.is_empty():
		return OperationResult.ok()

	var msg := "配置校验失败，共 %d 个错误" % errors.size()
	var result := OperationResult.fail(OperationResult.ERR_CONFIG, msg, "AppConfigValidator")
	result.error.context["errors"] = errors
	return result


# ============================================================
# 各段校验
# ============================================================

func _validate_app(p: AppConfig.AppSection, p_errors: Array[String]) -> void:
	if p.name.is_empty():
		p_errors.append("app.name 不能为空")

	if not p.environment in VALID_ENVIRONMENTS:
		p_errors.append("app.environment 值非法: '%s'，合法值: %s" % [p.environment, str(VALID_ENVIRONMENTS)])


func _validate_runtime(p: AppConfig.RuntimeSection, p_errors: Array[String]) -> void:
	if not p.mode in VALID_RUNTIME_MODES:
		p_errors.append("runtime.mode 值非法: '%s'，合法值: %s" % [p.mode, str(VALID_RUNTIME_MODES)])


func _validate_network(p: AppConfig.NetworkSection, p_runtime: AppConfig.RuntimeSection, p_errors: Array[String]) -> void:
	# 非 Mock 模式下，Remote/Hybrid 必须有真实 API 地址
	if p.use_mock_api:
		return

	var need_real_api := p_runtime.mode == "Remote" or p_runtime.mode == "Hybrid"
	if need_real_api and p.api_base_url.is_empty():
		p_errors.append("network.apiBaseUrl 不能为空：runtime.mode 为 %s 且 useMockApi 为 false" % p_runtime.mode)
	if need_real_api and p.ws_url.is_empty():
		p_errors.append("network.wsUrl 不能为空：runtime.mode 为 %s 且 useMockApi 为 false" % p_runtime.mode)

	if p.request_timeout_ms <= 0:
		p_errors.append("network.requestTimeoutMs 必须大于 0，当前值: %d" % p.request_timeout_ms)
	if p.retry_count < 0:
		p_errors.append("network.retryCount 不能为负数，当前值: %d" % p.retry_count)


func _validate_save(p: AppConfig.SaveSection, p_errors: Array[String]) -> void:
	if not p.provider in VALID_SAVE_PROVIDERS:
		p_errors.append("save.provider 值非法: '%s'，合法值: %s" % [p.provider, str(VALID_SAVE_PROVIDERS)])

	# 本地存档路径不能为空（所有 Provider 都需要本地兜底）
	if p.local_save_root.is_empty():
		p_errors.append("save.localSaveRoot 不能为空")

	# Remote / Hybrid 需要远程 endpoint
	if p.provider in ["Remote", "Hybrid"] and p.remote_save_endpoint.is_empty():
		p_errors.append("save.remoteSaveEndpoint 不能为空：save.provider 为 %s" % p.provider)

	if p.auto_save_interval_seconds <= 0:
		p_errors.append("save.autoSaveIntervalSeconds 必须大于 0，当前值: %d" % p.auto_save_interval_seconds)


func _validate_resource(p: AppConfig.ResourceSection, p_errors: Array[String]) -> void:
	if p.base_path.is_empty():
		p_errors.append("resource.basePath 不能为空")


func _validate_logging(p: AppConfig.LoggingSection, p_errors: Array[String]) -> void:
	if p.write_to_file and p.log_root.is_empty():
		p_errors.append("logging.logRoot 不能为空：logging.writeToFile 为 true")


func _validate_threading(p: AppConfig.ThreadingSection, p_errors: Array[String]) -> void:
	if p.max_active_jobs <= 0:
		p_errors.append("threading.maxActiveJobs 必须大于 0，当前值: %d" % p.max_active_jobs)
	if p.max_dispatch_per_tick <= 0:
		p_errors.append("threading.maxDispatchPerTick 必须大于 0，当前值: %d" % p.max_dispatch_per_tick)
	if p.default_timeout_ms <= 0:
		p_errors.append("threading.defaultTimeoutMs 必须大于 0，当前值: %d" % p.default_timeout_ms)
	if p.slow_job_warn_ms <= 0:
		p_errors.append("threading.slowJobWarnMs 必须大于 0，当前值: %d" % p.slow_job_warn_ms)
	if p.history_limit < 32:
		p_errors.append("threading.historyLimit 必须大于等于 32，当前值: %d" % p.history_limit)
