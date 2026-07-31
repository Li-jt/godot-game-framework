# GF_NetworkClient / GF_MockNetworkClient

> 适用版本: 0.3.0 | 继承: GF_NetworkClient → RefCounted | 继承: GF_MockNetworkClient → GF_NetworkClient

## 概述

**GF_NetworkClient** 是网络客户端的抽象基类，定义统一的 HTTP 请求接口。所有方法返回 `GF_OperationResult`，成功时 `result.data` 为 `GF_NetworkResponse` 实例。基类的所有方法默认返回 `ERR_INTERNAL "not implemented"`，由具体子类（如 Godot HTTP 客户端、Mock 客户端）实现实际逻辑。

**GF_MockNetworkClient** 是 Mock 实现，返回预设数据，供阶段 6-8 本地开发使用。不依赖真实网络，不会产生真实 HTTP 请求。

**适用场景**：
- GF_NetworkClient — 作为类型约束，确保所有网络实现遵循统一接口
- GF_MockNetworkClient — 本地开发、离线测试、CI 环境中替代真实网络请求

**不适用场景**：不要直接实例化 GF_NetworkClient（它是抽象基类）；生产环境不要使用 GF_MockNetworkClient。

---

## GF_NetworkClient

### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `base_url` | `String` | `""` | 服务器基础 URL，所有相对路径请求会拼接此前缀 |
| `timeout` | `float` | `8.0` | 请求超时时间，单位秒 |
| `auth_token` | `String` | `""` | Bearer 认证令牌，非空时自动添加 `Authorization: Bearer <token>` 请求头 |

### 公共方法

#### set_base_url(p_url: String) → void

设置服务器基础 URL。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_url` | `String` | 基础 URL，如 `"https://api.example.com"` |

**示例：**

```gdscript
client.set_base_url("https://api.example.com")
```

---

#### set_timeout(p_seconds: float) → void

设置请求超时时间。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_seconds` | `float` | 超时时间，单位秒。默认 8.0 |

**示例：**

```gdscript
client.set_timeout(15.0)  # 15 秒超时
```

---

#### set_auth_token(p_token: String) → void

设置 Bearer 认证令牌。设置后所有请求自动携带 `Authorization: Bearer <token>` 头。传入空字符串清空认证。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_token` | `String` | JWT 或其他 Bearer 令牌字符串 |

**示例：**

```gdscript
client.set_auth_token("eyJhbGciOi...")
# 后续请求自动带 Authorization 头
```

---

#### send(p_request: GF_NetworkRequest) → GF_OperationResult

发送任意网络请求。子类必须重写此方法实现实际发送逻辑。基类默认返回 `ERR_INTERNAL`。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_request` | `GF_NetworkRequest` | 完整的请求对象，包含 method、path、headers、body、timeout 等 |

**返回值：**

- `GF_OperationResult.ok(GF_NetworkResponse)` — 请求成功
- `GF_OperationResult.fail(ERR_INTERNAL, ...)` — 基类默认；子类失败时返回 `ERR_NETWORK`

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| `ERR_INTERNAL` | 基类默认，子类未重写 `send()` |
| `ERR_NETWORK` | 子类实现中发生网络错误（DNS 解析失败、连接超时、服务器不可达等） |

---

#### http_get(p_path: String, p_headers: Dictionary = {}) → GF_OperationResult

发送 GET 请求。基类返回 `ERR_INTERNAL`，由子类实现。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 请求路径。以 `http` 开头视为完整 URL，否则拼接 `base_url` |
| `p_headers` | `Dictionary` | 额外的请求头（会自动合并 `Authorization` 头） |

**返回值：** 同 `send()`。

**错误码：** 同 `send()`。

**示例：**

```gdscript
var result := client.http_get("/world/state", {"X-Request-Id": "abc123"})
if result.is_ok():
    var resp: GF_NetworkResponse = result.data
    print("状态码: %d, 响应: %s" % [resp.status_code, resp.body])
```

---

#### http_post(p_path: String, p_body: String = "", p_headers: Dictionary = {}) → GF_OperationResult

发送 POST 请求。基类返回 `ERR_INTERNAL`，由子类实现。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 请求路径 |
| `p_body` | `String` | 请求体，通常为 JSON 字符串 |
| `p_headers` | `Dictionary` | 额外的请求头 |

**返回值：** 同 `send()`。

**错误码：** 同 `send()`。

**示例：**

```gdscript
var body := JSON.stringify({"action": "build", "x": 10, "y": 20})
var result := client.http_post("/command/execute", body)
if result.is_ok():
    var resp: GF_NetworkResponse = result.data
    print("命令执行结果: %s" % resp.body)
```

---

#### http_put(p_path: String, p_body: String = "", p_headers: Dictionary = {}) → GF_OperationResult

发送 PUT 请求。基类返回 `ERR_INTERNAL`，由子类实现。

**参数：** 同 `http_post()`。

**返回值：** 同 `send()`。

**错误码：** 同 `send()`。

---

#### http_delete(p_path: String, p_headers: Dictionary = {}) → GF_OperationResult

发送 DELETE 请求。基类返回 `ERR_INTERNAL`，由子类实现。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 请求路径 |
| `p_headers` | `Dictionary` | 额外的请求头 |

**返回值：** 同 `send()`。

**错误码：** 同 `send()`。

---

## GF_MockNetworkClient

### 属性

继承 `GF_NetworkClient` 的所有属性，外加私有的 mock 存储字典。

### 公共方法

#### mock_get(p_path: String, p_body: String, p_status: int = 200) → void

预设一个 GET 请求的响应数据。后续对同一 path 的 `http_get()` 调用会返回此预设。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 请求路径，作为匹配键 |
| `p_body` | `String` | 响应体，通常为 JSON 字符串 |
| `p_status` | `int` | HTTP 状态码，默认 200 |

**示例：**

```gdscript
mock.mock_get("/world/state", '{"entities": [{"id": 1, "type": "tree"}]}', 200)
```

---

#### mock_post(p_path: String, p_body: String, p_status: int = 200) → void

预设一个 POST 请求的响应数据。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 请求路径 |
| `p_body` | `String` | 响应体 |
| `p_status` | `int` | HTTP 状态码，默认 200 |

**示例：**

```gdscript
mock.mock_post("/command/execute", '{"ok": true, "command_id": "cmd_001"}', 200)
mock.mock_post("/auth/login", '{"error": "invalid_credentials"}', 401)
```

---

#### mock_put(p_path: String, p_body: String, p_status: int = 200) → void

预设一个 PUT 请求的响应数据。

**参数：** 同 `mock_post()`。

---

#### mock_delete(p_path: String, p_body: String, p_status: int = 200) → void

预设一个 DELETE 请求的响应数据。

**参数：** 同 `mock_post()`。

---

#### simulate_error(p_enabled: bool) → void

开启或关闭模拟网络故障。开启后，所有 `http_get/post/put/delete` 调用均返回 `ERR_NETWORK` 错误，忽略已预设的响应。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_enabled` | `bool` | `true` 开启网络故障模拟，`false` 恢复正常 |

**示例：**

```gdscript
# 测试网络故障时的降级逻辑
mock.simulate_error(true)
var result := mock.http_get("/world/state")
assert(result.is_fail())
assert(result.error.code == GF_OperationResult.ERR_NETWORK)

# 恢复正常
mock.simulate_error(false)
```

---

#### clear_mocks() → void

清除所有预设的 mock 响应和网络故障模拟状态。清除后所有请求将返回 `ERR_NOT_FOUND`（路径未预设）。

**示例：**

```gdscript
# 在测试用例 tear_down 中清除
func after_each() -> void:
    mock.clear_mocks()
```

---

### 覆盖的方法（实现）

以下方法覆盖了基类的抽象方法，返回预设的 mock 数据：

- `http_get(p_path, p_headers)` → 从 `_mock_gets` 查找预设
- `http_post(p_path, p_body, p_headers)` → 从 `_mock_posts` 查找预设
- `http_put(p_path, p_body, p_headers)` → 从 `_mock_puts` 查找预设
- `http_delete(p_path, p_headers)` → 从 `_mock_deletes` 查找预设

每个方法的返回值规则：
- `_simulate_error` 为 `true` → 返回 `GF_OperationResult.fail(ERR_NETWORK, ...)`
- path 未在对应字典中预设 → 返回 `GF_OperationResult.fail(ERR_NOT_FOUND, ...)`
- 正常命中 → 返回 `GF_OperationResult.ok(GF_NetworkResponse)`，`success` 字段由状态码是否在 200-299 区间决定

---

## 相关类型

### GF_NetworkRequest

**继承：** RefCounted

| 字段 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `method` | `String` | `"GET"` | HTTP 方法：GET / POST / PUT / DELETE |
| `path` | `String` | `""` | 请求路径 |
| `headers` | `Dictionary` | `{}` | 请求头 |
| `body` | `String` | `""` | 请求体 |
| `timeout` | `float` | `8.0` | 超时（秒） |
| `retry_count` | `int` | `2` | 重试次数 |
| `idempotency_key` | `String` | `""` | 幂等键，防止重复提交 |

### GF_NetworkResponse

**继承：** RefCounted

| 字段 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `success` | `bool` | `false` | 请求是否成功 |
| `status_code` | `int` | `0` | HTTP 状态码 |
| `body` | `String` | `""` | 响应体文本 |
| `error_message` | `String` | `""` | 错误描述 |
| `headers` | `Dictionary` | `{}` | 响应头 |

---

## See Also

- [GF_OperationResult](../core/gf_operation_result.md) — 统一操作结果类型
- [GF_NetworkRequest](#gf_networkrequest) — 请求模型
- [GF_NetworkResponse](#gf_networkresponse) — 响应模型
