# GF_OperationResult

> 适用版本: 0.3.0 | 继承: GF_OperationResult -> RefCounted

## 概述

统一操作结果类型，使用 HTTP 风格的状态码（2xx 成功 / 4xx 逻辑错误 / 5xx 内部错误）。所有可能失败的操作必须返回此类型，禁止只返回 `bool` 或 `null`。

GF_ErrorInfo 是其关联的错误信息结构，由 `GF_OperationResult.fail()` 自动创建。调用方可通过 `result.error` 访问详细错误信息，并通过 `root_cause()` 追踪跨层包装的根因。

## 状态码常量（共 17 个）

### 2xx 成功

| 常量 | 值 | 含义 |
|------|-----|------|
| `OK` | 200 | 操作成功 |
| `CREATED` | 201 | 资源已创建 |
| `ACCEPTED` | 202 | 请求已接受，异步处理中 |

### 4xx 逻辑错误

| 常量 | 值 | 含义 |
|------|-----|------|
| `ERR_BAD_REQUEST` | 400 | 请求格式或参数错误 |
| `ERR_UNAUTHORIZED` | 401 | 未授权/未登录（预留） |
| `ERR_FORBIDDEN` | 403 | 无权限（预留） |
| `ERR_NOT_FOUND` | 404 | 资源不存在 |
| `ERR_CONFLICT` | 409 | 资源冲突（如组件已存在） |
| `ERR_VALIDATION` | 422 | 业务校验失败 |
| `ERR_PRECONDITION` | 428 | 前置条件不满足 |

### 5xx 内部/系统错误

| 常量 | 值 | 含义 |
|------|-----|------|
| `ERR_INTERNAL` | 500 | 内部未知错误 |
| `ERR_CONFIG` | 501 | 配置错误 |
| `ERR_IO` | 502 | 文件/IO 错误 |
| `ERR_NETWORK` | 503 | 网络请求失败 |
| `ERR_TIMEOUT` | 504 | 操作超时 |
| `ERR_DISPOSED` | 505 | 模块已释放 |
| `ERR_MIGRATION` | 506 | 数据迁移失败 |

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `status_code` | `int` | `200` | 状态码 |
| `success` | `bool` | `true` | 快捷判断：是否在 2xx 范围内 |
| `error` | `GF_ErrorInfo` | `null` | 失败时的详细错误信息，成功时为 null |
| `data` | `Variant` | `null` | 成功时附带的返回数据 |

## GF_ErrorInfo 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `code` | `String` | `""` | 错误码字符串 |
| `message` | `String` | `""` | 面向开发者的错误描述 |
| `source_module` | `String` | `""` | 错误来源模块名 |
| `original_error` | `String` | `""` | 原始异常信息，用于调试 |
| `context` | `Dictionary` | `{}` | 附加的上下文键值对 |
| `cause` | `GF_ErrorInfo` | `null` | 原始错误引用，用于跨层包装时保留根因 |

## 静态工厂方法

### ok(p_data: Variant = null) -> GF_OperationResult

创建成功结果（状态码 200），可选附带返回数据。

```gdscript
return GF_OperationResult.ok()
return GF_OperationResult.ok({"entity_id": 42})
```

### created(p_data: Variant = null) -> GF_OperationResult

创建成功结果（状态码 201），表示资源已创建，可选附带返回数据。

```gdscript
return GF_OperationResult.created(type_id)
```

### fail(p_code: int, p_message: String, p_source_module: String = "") -> GF_OperationResult

创建失败结果，必须提供状态码和错误描述。可选指定来源模块名。

```gdscript
return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "实体不存在: %d" % entity_id)
return GF_OperationResult.fail(GF_OperationResult.ERR_VALIDATION, "坐标已被占用", "CommandExecutor")
```

### wrap(p_result: GF_OperationResult, p_source_module: String, p_message: String) -> GF_OperationResult

包装已有错误，保留原始 error 作为 cause，生成新的 fail 结果。用于在调用链上层添加模块上下文。

```gdscript
var result := inner_service.do_something()
if result.is_fail():
    return GF_OperationResult.wrap(result, "MyService", "内部服务调用失败")
```

## 实例方法

### is_ok() -> bool

是否成功（status_code 在 2xx 范围）。

### is_fail() -> bool

是否失败。

### with_context(p_key: String, p_value: Variant) -> GF_OperationResult

追加错误上下文，返回自身以支持链式调用。仅在 error 不为 null 时生效。

```gdscript
return GF_OperationResult.fail(...).with_context("entity_id", 42).with_context("action", "move")
```

### root_cause() -> GF_ErrorInfo

从错误链中查找根因，沿 cause 链一直追溯到最底层。没有 cause 时返回 error 自身。

```gdscript
var root := result.root_cause()
print("根因: [%s] %s" % [root.source_module, root.message])
```

### status_text() -> String

获取状态码对应的描述文本（英文）。

```gdscript
print(result.status_text())  # "Not Found" / "OK" / "Conflict"
```

## 完整使用示例

```gdscript
# 生产者
func find_entity(p_id: int) -> GF_OperationResult:
    if p_id <= 0:
        return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "ID 无效: %d" % p_id, "EntityService")
    var entity := _entities.get(p_id, null)
    if entity == null:
        return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "实体不存在: %d" % p_id, "EntityService")
    return GF_OperationResult.ok(entity)

# 调用方
var result := find_entity(42)
if result.is_ok():
    print(result.data)
else:
    printerr("[%d] %s" % [result.status_code, result.error.message])
```

## See Also

- [GF_ModuleLifecycle](./gf_module_lifecycle.md) -- 模块生命周期基类
