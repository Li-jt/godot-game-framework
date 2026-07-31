# 错误码完整对照表

GF_OperationResult 使用 HTTP 风格的状态码来统一表示操作结果。本文档列出全部 17 个错误码的含义、触发场景和建议处理方式。

## 状态码分类

| 范围 | 分类 | 含义 |
|------|------|------|
| 2xx | 成功 | 操作成功完成 |
| 4xx | 客户端/逻辑错误 | 调用方的问题（参数无效、资源不存在、权限不足等） |
| 5xx | 内部/系统错误 | 框架或环境的问题（配置错误、IO 失败、超时等） |

## 完整对照表

### 2xx 成功

| 错误码 | 数值 | 含义 | 常见触发场景 | 建议处理 |
|--------|------|------|-------------|---------|
| `OK` | 200 | 操作成功 | 所有正常完成的同步操作 | 读取 `result.data` 获取返回值 |
| `CREATED` | 201 | 资源已创建 | 实体创建、面板实例化、文件新建 | 读取 `result.data` 获取新建资源的标识 |
| `ACCEPTED` | 202 | 请求已接受 | 异步任务提交成功、消息已入队 | 等待异步回调，不要立即读取结果 |

### 4xx 逻辑错误

| 错误码 | 数值 | 含义 | 常见触发场景 | 建议处理 |
|--------|------|------|-------------|---------|
| `ERR_BAD_REQUEST` | 400 | 请求格式错误 | 参数为 null、key 为空字符串、类型不匹配 | 检查调用参数，添加前置校验 |
| `ERR_UNAUTHORIZED` | 401 | 未授权/未登录 | 需要登录才能访问的功能 | 引导用户登录 |
| `ERR_FORBIDDEN` | 403 | 无权限 | 尝试覆盖更高优先级的服务注册、无权卸载其他 owner 的服务 | 检查调用权限，确认操作合法性 |
| `ERR_NOT_FOUND` | 404 | 资源不存在 | 实体不存在、面板未注册、存档槽位为空、服务未注册 | 添加存在性检查，检查名称拼写 |
| `ERR_CONFLICT` | 409 | 资源冲突 | Tile 已被占用、同名 key 已被低优先级服务注册 | 选择其他位置/名称，或提升优先级 |
| `ERR_VALIDATION` | 422 | 业务校验失败 | 存档数据格式错误、配置值不在允许范围 | 提供有效的输入数据 |
| `ERR_PRECONDITION` | 428 | 前置条件不满足 | 材料/金币不足、模块未 ready 就调用方法、configure() 前使用服务 | 检查前置条件，等待模块就绪 |

### 5xx 内部/系统错误

| 错误码 | 数值 | 含义 | 常见触发场景 | 建议处理 |
|--------|------|------|-------------|---------|
| `ERR_INTERNAL` | 500 | 内部未知错误 | 未分类的运行时异常、Remote/Hybrid 策略尚未实现 | 上报 bug，添加防御性处理 |
| `ERR_CONFIG` | 501 | 配置错误 | app_config.json 格式错误、必需字段缺失 | 检查配置文件，使用 ConfigValidator 校验 |
| `ERR_IO` | 502 | 文件/IO 错误 | FileAccess 读写失败、目录不存在 | 检查文件路径和权限 |
| `ERR_NETWORK` | 503 | 网络请求失败 | HTTP 请求超时、连接拒绝 | 重试或降级处理 |
| `ERR_TIMEOUT` | 504 | 操作超时 | 线程任务执行超时、网络请求超时 | 增加超时时间或优化任务 |
| `ERR_DISPOSED` | 505 | 模块已释放 | 对已 dispose 的模块调用 init_module() | 检查模块生命周期状态 |
| `ERR_MIGRATION` | 506 | 数据迁移失败 | 存档版本高于当前版本、缺少迁移器、迁移过程中数据转换失败 | 检查存档版本兼容性，注册对应迁移器 |

## 使用示例

### 检查结果

```gdscript
var result := save_service.load_slot(1)

# 方式 1：直接判断成功/失败
if result.is_fail():
    match result.status_code:
        GF_OperationResult.ERR_NOT_FOUND:
            print("存档槽位为空")
        GF_OperationResult.ERR_IO:
            print("存档文件读取失败")
        GF_OperationResult.ERR_MIGRATION:
            print("存档版本不兼容")
        _:
            print("未知错误: %s" % result.error.message)
    return

var data: Dictionary = result.data
```

### 创建结果

```gdscript
# 成功
return GF_OperationResult.ok()
return GF_OperationResult.ok({"entity_id": 42})

# 失败 — 参数无效
return GF_OperationResult.fail(
    GF_OperationResult.ERR_BAD_REQUEST,
    "provider 不能为 null",
    "SaveService"
)

# 失败 — 资源不存在
return GF_OperationResult.fail(
    GF_OperationResult.ERR_NOT_FOUND,
    "未找到实体: %d" % entity_id,
    "EntityManager"
)

# 失败 — 前置条件不满足
return GF_OperationResult.fail(
    GF_OperationResult.ERR_PRECONDITION,
    "模块未 ready，请先调用 configure()",
    "MyService"
)
```

### 包装错误

将底层错误包装为上层可读的错误信息：

```gdscript
var result := file_system.read_json(path)
if result.is_fail():
    return GF_OperationResult.wrap(
        result,
        "ConfigLoader",
        "配置文件读取失败: %s" % path
    )
```

### 错误链追踪

通过 `root_cause()` 追溯到最底层的错误原因：

```gdscript
if result.is_fail():
    var cause := result.root_cause()
    _log.error("Game", "根本原因: [%s] %s" % [cause.code, cause.message])
```

### 添加上下文

使用 `with_context()` 链式追加调试信息：

```gdscript
return GF_OperationResult.fail(ERR_VALIDATION, "坐标校验失败", "PlacementValidator")
    .with_context("x", p_x)
    .with_context("y", p_y)
    .with_context("map_bounds", map.get_bounds())
```
