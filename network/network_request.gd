## NetworkRequest
## 网络请求模型。统一描述 HTTP 请求的参数。
class_name NetworkRequest
extends RefCounted

var method: String = "GET"          # GET / POST / PUT / DELETE
var path: String = ""               # 请求路径
var headers: Dictionary = {}        # 请求头
var body: String = ""               # 请求体
var timeout: float = 8.0            # 超时（秒）
var retry_count: int = 2            # 重试次数
var idempotency_key: String = ""    # 幂等键（防止重复提交）
