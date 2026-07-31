# 统一错误处理：GF_OperationResult

**类比**：想象你去餐厅点餐。如果服务员只回答"不行"（`bool false`），你不知道是厨房关了、材料没了、还是你点的菜不在菜单上。好的服务员会告诉你具体原因和怎么办（`GF_OperationResult`）。

## 为什么不用 bool / null

### 反例 1：返回 bool 丢失错误信息

```gdscript
# ❌ 只返回 bool，调用方不知道失败原因
func load_config(path: String) -> bool:
    if not FileAccess.file_exists(path):
        printerr("文件不存在: " + path)
        return false
    # ...
    return true

# 调用方
if not load_config("res://config.json"):
    # 是文件不存在？格式错误？权限不够？无法判断
    print("配置加载失败")
```

### 反例 2：返回 null 表示"没找到"

```gdscript
# ❌ 返回 null，调用方无法区分"没找到"和"出错"
func get_entity(id: int) -> Variant:
    if not _entities.has(id):
        return null  # 到底是实体不存在，还是内部错误？
    return _entities[id]
```

### 反例 3：自定义错误返回方式不统一

```gdscript
# ❌ 模块 A 返回 int 错误码
func do_a() -> int: return -1

# ❌ 模块 B 返回带消息的 Dictionary
func do_b() -> Dictionary: return {"error": true, "msg": "出错了"}

# ❌ 模块 C 什么都不返回，只靠信号通知
```

### 统一方案

```gdscript
# ✅ 统一返回 GF_OperationResult
func load_config(path: String) -> GF_OperationResult:
    if not FileAccess.file_exists(path):
        return GF_OperationResult.fail(
            GF_OperationResult.ERR_NOT_FOUND,
            "配置文件不存在: %s" % path,
            "ConfigLoader"
        )
    return GF_OperationResult.ok({"loaded": true})
```

## 完整错误码表

### 2xx — 成功

| 常量 | 值 | 含义 | 适用场景 |
|---|---|---|---|
| `OK` | 200 | 操作成功 | 通用成功 |
| `CREATED` | 201 | 资源已创建 | 新建实体、注册类型、创建文件 |
| `ACCEPTED` | 202 | 请求已接受，异步处理中 | 提交后台任务、队列消息 |

### 4xx — 逻辑错误（调用方问题）

| 常量 | 值 | 含义 | 适用场景 |
|---|---|---|---|
| `ERR_BAD_REQUEST` | 400 | 请求格式错误 | 参数为 null、类型不匹配、必填字段缺失 |
| `ERR_UNAUTHORIZED` | 401 | 未授权 | 需要登录/认证的场景（预留） |
| `ERR_FORBIDDEN` | 403 | 无权限 | 权限不足（预留） |
| `ERR_NOT_FOUND` | 404 | 资源不存在 | 实体不存在、文件不存在、配置项缺失 |
| `ERR_CONFLICT` | 409 | 资源冲突 | 组件已存在、坐标被占用、ID 重复 |
| `ERR_VALIDATION` | 422 | 业务校验失败 | 数据不合规、字段值超出范围 |
| `ERR_PRECONDITION` | 428 | 前置条件不满足 | 状态不对、材料不足、依赖未就绪 |

### 5xx — 系统错误（服务端/内部问题）

| 常量 | 值 | 含义 | 适用场景 |
|---|---|---|---|
| `ERR_INTERNAL` | 500 | 内部未知错误 | 未预期的异常，无法归类 |
| `ERR_CONFIG` | 501 | 配置错误 | JSON 格式错误、配置项非法 |
| `ERR_IO` | 502 | 文件/IO 错误 | 读写失败、权限不足 |
| `ERR_NETWORK` | 503 | 网络请求失败 | API 调用超时、连接中断 |
| `ERR_TIMEOUT` | 504 | 操作超时 | 异步操作超时 |
| `ERR_DISPOSED` | 505 | 模块已释放 | 调用了已 dispose 的服务 |
| `ERR_MIGRATION` | 506 | 数据迁移失败 | 存档版本迁移出错 |

## 工厂方法

### ok() — 创建成功结果

```gdscript
# 不带数据
return GF_OperationResult.ok()

# 带数据
return GF_OperationResult.ok({"entity_id": 42})

# 带复杂数据
var result := GF_EcsQueryResult.new()
# ... 填充 result
return GF_OperationResult.ok(result)
```

### fail() — 创建失败结果

```gdscript
# 必须提供：错误码 + 错误消息；可选：来源模块名
return GF_OperationResult.fail(
    GF_OperationResult.ERR_NOT_FOUND,       # 错误码
    "实体不存在: %d" % entity_id,            # 错误消息
    "MyService"                             # 来源模块（可选，便于定位）
)
```

### created() — 创建资源成功

```gdscript
# 语义等同于 ok()，但状态码为 201
return GF_OperationResult.created(new_entity_id)
```

### wrap() — 包装已有错误

当你调用了一个底层方法，想在上层附加更多上下文时，使用 `wrap()` 保留原始错误链：

```gdscript
func high_level_operation() -> GF_OperationResult:
    var result := low_level_operation()
    if result.is_fail():
        return GF_OperationResult.wrap(
            result,
            "HighLevelService",
            "高层操作失败：底层 %s 执行出错" % low_operation_name
        )
    return GF_OperationResult.ok()
```

## 检查模式

### 基本检查

```gdscript
var result := service.do_something()
if result.is_ok():
    # 处理成功
    var data = result.data
    process_data(data)
else:
    # 处理失败
    _log.error("Service", "操作失败 [%d]: %s" % [result.status_code, result.error.message])
```

### 区分不同错误类型

```gdscript
var result := world.add_component(entity, &"Health", {"current": 100})

if result.is_ok():
    pass  # 添加成功
elif result.status_code == GF_OperationResult.ERR_CONFLICT:
    _log.warn("ECS", "实体 %d 已有 Health 组件，跳过" % entity)
elif result.status_code == GF_OperationResult.ERR_NOT_FOUND:
    _log.error("ECS", "实体 %d 不存在" % entity)
else:
    _log.error("ECS", "未知错误: %s" % result.error.message)
```

### 传播错误

```gdscript
func my_operation() -> GF_OperationResult:
    var result := service.configure(...)
    if result.is_fail():
        # 直接把错误传给上层
        return result

    # 或附加上下文再传
    return result.with_context("entity_id", 42)
```

## 错误链与 root_cause()

当错误在多层调用链中传播时，`wrap()` 会保留原始的 `cause`：

```gdscript
func layer3() -> GF_OperationResult:
    return GF_OperationResult.fail(GF_OperationResult.ERR_IO, "磁盘写入失败", "FileService")

func layer2() -> GF_OperationResult:
    var result := layer3()
    if result.is_fail():
        return GF_OperationResult.wrap(result, "SaveService", "存档写入失败")
    return GF_OperationResult.ok()

func layer1() -> GF_OperationResult:
    var result := layer2()
    if result.is_fail():
        # 打印错误链
        _log.error("Game", "操作失败: %s" % result.error.message)
        # 追溯到根因
        var root := result.root_cause()
        _log.error("Game", "根因: %s" % root.message)
        return result
    return GF_OperationResult.ok()
```

## with_context() — 附加调试信息

在失败结果上附加键值对上下文，用于调试：

```gdscript
var result := world.add_component(entity, &"Health", health_data)
if result.is_fail():
    result.with_context("entity_id", entity)
    result.with_context("component_type", "Health")
    result.with_context("data", health_data)
    return result
```

这使得调试日志可以输出完整的上下文信息。

## GF_ErrorInfo 结构

当 `is_fail()` 为 `true` 时，`result.error` 是一个 `GF_ErrorInfo` 实例：

| 字段 | 类型 | 说明 |
|---|---|---|
| `code` | `String` | 错误码字符串（如 `"404"`） |
| `message` | `String` | 面向开发者的错误描述 |
| `source_module` | `String` | 错误来源模块名 |
| `original_error` | `String` | 原始异常信息（可选） |
| `context` | `Dictionary` | 通过 `with_context()` 附加的键值对 |
| `cause` | `GF_ErrorInfo` | 通过 `wrap()` 保留的原始错误 |

---

**下一步**: [ECS 世界](ecs-world.md) — 理解实体管理和组件存储，或 [服务依赖注入](service-dependency.md) 学习如何组装服务。
