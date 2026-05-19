## OperationResult
## 统一操作结果类型，使用 HTTP 风格的状态码。
## 所有可能失败的操作必须返回此类型，禁止只返回 bool 或 null。
##
## 状态码规则：
##   2xx      成功（OK 200、Created 201、Accepted 202）
##   4xx      客户端/逻辑错误（参数无效、未找到、冲突、校验失败）
##   5xx      内部/系统错误（配置错误、IO 错误、网络错误、未知异常）
##
## 使用示例：
##   [codeblock]
##   # 成功
##   return OperationResult.ok()
##   return OperationResult.ok(some_data)
##
##   # 失败
##   return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "实体不存在: %s" % entity_id)
##   return OperationResult.fail(OperationResult.ERR_VALIDATION, "坐标已被占用", "CommandExecutor")
##
##   # 调用方
##   var result := some_service.do_something()
##   if result.is_ok():
##       print(result.data)
##   else:
##       printerr("[%d] %s" % [result.status_code, result.error.message])
##   [/codeblock]
class_name OperationResult
extends RefCounted

# ============================================================
# 状态码常量（HTTP 风格）
# ============================================================

# --- 2xx 成功 ---
const OK := 200              # 操作成功
const CREATED := 201         # 资源已创建
const ACCEPTED := 202        # 请求已接受，异步处理中

# --- 4xx 逻辑错误 ---
const ERR_BAD_REQUEST := 400      # 请求格式错误
const ERR_UNAUTHORIZED := 401     # 未授权/未登录
const ERR_FORBIDDEN := 403        # 无权限
const ERR_NOT_FOUND := 404        # 资源不存在
const ERR_CONFLICT := 409         # 资源冲突（如 Tile 已被占用）
const ERR_VALIDATION := 422       # 业务校验失败
const ERR_PRECONDITION := 428     # 前置条件不满足（如材料不足）

# --- 5xx 内部/系统错误 ---
const ERR_INTERNAL := 500         # 内部未知错误
const ERR_CONFIG := 501           # 配置错误
const ERR_IO := 502               # 文件/IO 错误
const ERR_NETWORK := 503          # 网络请求失败
const ERR_TIMEOUT := 504          # 操作超时
const ERR_DISPOSED := 505         # 模块已释放
const ERR_MIGRATION := 506        # 数据迁移失败

# ============================================================
# 实例字段
# ============================================================

## 状态码，如 200 / 404 / 422 / 500
var status_code: int = OK

## 快捷判断：status_code 是否在 2xx 范围内
var success: bool = true

## 失败时的详细错误信息，成功时为 null
var error: ErrorInfo = null

## 成功时附带的返回数据
var data = null

# ============================================================
# 静态工厂方法
# ============================================================

## 创建成功结果（默认 200），可选附带数据
static func ok(p_data = null) -> OperationResult:
	var r := OperationResult.new()
	r.status_code = OK
	r.success = true
	r.data = p_data
	return r

## 创建成功结果，指定成功状态码
static func created(p_data = null) -> OperationResult:
	var r := OperationResult.new()
	r.status_code = CREATED
	r.success = true
	r.data = p_data
	return r

## 创建失败结果，必须提供状态码和错误描述
static func fail(p_code: int, p_message: String, p_source_module: String = "") -> OperationResult:
	var r := OperationResult.new()
	r.status_code = p_code
	r.success = false
	r.error = ErrorInfo.new()
	r.error.code = str(p_code)
	r.error.message = p_message
	r.error.source_module = p_source_module
	return r

# ============================================================
# 便捷判断
# ============================================================

## 是否成功（status_code 在 2xx 范围）
func is_ok() -> bool:
	return success

## 是否失败
func is_fail() -> bool:
	return not success

## 追加错误上下文，返回自身以支持链式调用
func with_context(p_key: String, p_value) -> OperationResult:
	if error != null:
		error.context[p_key] = p_value
	return self


## 包装已有错误，保留原始 error 作为 cause，生成新的 fail 结果
static func wrap(p_result: OperationResult, p_source_module: String, p_message: String) -> OperationResult:
	var r := OperationResult.new()
	r.status_code = p_result.status_code
	r.success = false
	r.error = ErrorInfo.new()
	r.error.code = str(p_result.status_code)
	r.error.message = p_message
	r.error.source_module = p_source_module
	r.error.cause = p_result.error
	return r


## 从错误链中查找根因
func root_cause() -> ErrorInfo:
	if error == null or error.cause == null:
		return error
	var c := error.cause
	while c.cause != null:
		c = c.cause
	return c


## 获取状态码对应的描述文本
func status_text() -> String:
	match status_code:
		OK: return "OK"
		CREATED: return "Created"
		ACCEPTED: return "Accepted"
		ERR_BAD_REQUEST: return "Bad Request"
		ERR_UNAUTHORIZED: return "Unauthorized"
		ERR_FORBIDDEN: return "Forbidden"
		ERR_NOT_FOUND: return "Not Found"
		ERR_CONFLICT: return "Conflict"
		ERR_VALIDATION: return "Validation Failed"
		ERR_PRECONDITION: return "Precondition Failed"
		ERR_INTERNAL: return "Internal Error"
		ERR_CONFIG: return "Config Error"
		ERR_IO: return "IO Error"
		ERR_NETWORK: return "Network Error"
		ERR_TIMEOUT: return "Timeout"
		ERR_DISPOSED: return "Disposed"
		ERR_MIGRATION: return "Migration Error"
		_: return "Unknown"
