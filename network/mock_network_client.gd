## MockNetworkClient
## Mock 网络客户端。返回预设数据，供阶段 6-8 本地开发使用。
## 不依赖真实网络，不会产生真实请求。
##
## 使用方式：
##   [codeblock]
##   var client := MockNetworkClient.new()
##   client.mock_get("/world/state", '{"entities": []}', 200)
##   client.mock_post("/command/execute", '{"ok": true}', 200)
##
##   var result := client.http_get("/world/state")
##   if result.is_ok():
##       var resp: NetworkResponse = result.data
##   [/codeblock]
class_name MockNetworkClient
extends NetworkClient

var _mock_gets: Dictionary = {}     # path -> {status, body}
var _mock_posts: Dictionary = {}    # path -> {status, body}
var _mock_puts: Dictionary = {}     # path -> {status, body}
var _mock_deletes: Dictionary = {}  # path -> {status, body}
var _simulate_error: bool = false   # 设为 true 模拟网络故障


## 预设 GET 响应
func mock_get(p_path: String, p_body: String, p_status: int = 200) -> void:
	_mock_gets[p_path] = {"status": p_status, "body": p_body}


## 预设 POST 响应
func mock_post(p_path: String, p_body: String, p_status: int = 200) -> void:
	_mock_posts[p_path] = {"status": p_status, "body": p_body}


## 预设 PUT 响应
func mock_put(p_path: String, p_body: String, p_status: int = 200) -> void:
	_mock_puts[p_path] = {"status": p_status, "body": p_body}


## 预设 DELETE 响应
func mock_delete(p_path: String, p_body: String, p_status: int = 200) -> void:
	_mock_deletes[p_path] = {"status": p_status, "body": p_body}


## 模拟网络故障
func simulate_error(p_enabled: bool) -> void:
	_simulate_error = p_enabled


## 清除所有预设响应
func clear_mocks() -> void:
	_mock_gets.clear()
	_mock_posts.clear()
	_mock_puts.clear()
	_mock_deletes.clear()
	_simulate_error = false


# ============================================================
# 实现
# ============================================================

func http_get(p_path: String, p_headers: Dictionary = {}) -> OperationResult:
	return _mock_response(p_path, _mock_gets)


func http_post(p_path: String, p_body: String = "", p_headers: Dictionary = {}) -> OperationResult:
	return _mock_response(p_path, _mock_posts)


func http_put(p_path: String, p_body: String = "", p_headers: Dictionary = {}) -> OperationResult:
	return _mock_response(p_path, _mock_puts)


func http_delete(p_path: String, p_headers: Dictionary = {}) -> OperationResult:
	return _mock_response(p_path, _mock_deletes)


func _mock_response(p_path: String, p_store: Dictionary) -> OperationResult:
	if _simulate_error:
		return OperationResult.fail(OperationResult.ERR_NETWORK, "Mock 模拟网络故障: %s" % p_path, "MockNetworkClient")

	if not p_store.has(p_path):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "Mock 未预设: %s" % p_path, "MockNetworkClient")

	var preset: Dictionary = p_store[p_path]
	var resp := NetworkResponse.new()
	resp.success = preset.status >= 200 and preset.status < 300
	resp.status_code = preset.status
	resp.body = preset.body
	return OperationResult.ok(resp)
