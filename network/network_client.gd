## NetworkClient
## 网络客户端抽象基类。所有方法返回 OperationResult。
## 成功：OperationResult.ok(NetworkResponse)
## 失败：OperationResult.fail(ERR_NETWORK, ...)
##
## 使用方式：
##   [codeblock]
##   var client: NetworkClient = GodotHttpClient.new()  # TODO 阶段9
##   client.set_base_url("https://api.example.com")
##   client.set_timeout(8.0)
##   var result := client.http_get("/world/state")
##   if result.is_ok():
##       var resp: NetworkResponse = result.data
##       print(resp.body)
##   [/codeblock]
class_name NetworkClient
extends RefCounted

var base_url: String = ""
var timeout: float = 8.0
var auth_token: String = ""


func set_base_url(p_url: String) -> void:
	base_url = p_url


func set_timeout(p_seconds: float) -> void:
	timeout = p_seconds


func set_auth_token(p_token: String) -> void:
	auth_token = p_token


## 发送请求。子类重写。
func send(p_request: NetworkRequest) -> OperationResult:
	return _not_impl(p_request.method)


func http_get(p_path: String, p_headers: Dictionary = {}) -> OperationResult:
	return _not_impl("GET")


func http_post(p_path: String, p_body: String = "", p_headers: Dictionary = {}) -> OperationResult:
	return _not_impl("POST")


func http_put(p_path: String, p_body: String = "", p_headers: Dictionary = {}) -> OperationResult:
	return _not_impl("PUT")


func http_delete(p_path: String, p_headers: Dictionary = {}) -> OperationResult:
	return _not_impl("DELETE")


func _not_impl(p_method: String) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "%s 未实现" % p_method, "NetworkClient")


func _build_url(p_path: String) -> String:
	if p_path.begins_with("http"):
		return p_path
	return base_url.path_join(p_path)


func _auth_header() -> Dictionary:
	if auth_token.is_empty():
		return {}
	return {"Authorization": "Bearer " + auth_token}
