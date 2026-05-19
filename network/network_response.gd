## NetworkResponse
## 网络请求响应模型。
class_name NetworkResponse
extends RefCounted

var success: bool = false
var status_code: int = 0        # HTTP 状态码
var body: String = ""           # 响应体文本
var error_message: String = ""  # 错误描述
var headers: Dictionary = {}    # 响应头
