# 日志与调试

## 场景描述

开发和运维需要结构化日志来追踪问题，运行时需要查看 FPS、命令历史和网络统计。框架的 `GF_LogService` 提供四级日志输出、文件分层存储和 Sink 扩展机制；`GF_DebugService` 提供运行时统计和命令追踪。

本章覆盖：四级日志、文件输出、MemoryLogSink、DebugService 统计、生产环境日志配置。

---

## 最小示例

```gdscript
# 使用 LogService（禁止使用 print()）
_log.info("Bootstrap", "应用启动完成")
_log.debug("Network", "请求延迟: %dms" % latency)
_log.warning("Save", "存档槽位 %d 数据不完整" % slot_id)
_log.error("Config", "加载失败: %s" % error_message)
```

---

## 逐步解释

### 第一步：四级日志

| 级别 | 常量 | 用途 | 生产环境 |
|------|------|------|---------|
| DEBUG | `GF_LogLevel.Level.DEBUG` | 开发调试信息 | 关闭 |
| INFO | `GF_LogLevel.Level.INFO` | 关键流程节点 | 开启 |
| WARNING | `GF_LogLevel.Level.WARNING` | 非致命异常、降级 | 开启 |
| ERROR | `GF_LogLevel.Level.ERROR` | 错误、操作失败 | 开启 |

设置某个级别后，只输出该级别及更高级别的日志。例如设为 `WARNING` 时只输出 WARNING 和 ERROR。

```gdscript
# 配置日志级别
log_service.configure(config.logging_section, path_resolver)
# 级别从 config.logging_section.level 读取（"DEBUG"/"INFO"/"WARNING"/"ERROR"）
```

### 第二步：日志输出格式

```gdscript
_log.info("ModuleName", "操作描述")
_log.info("ModuleName", "带参数: id=%s count=%d" % [entity_id, count])
_log.warning("ModuleName", "降级处理: 原因", {"context_key": "value"})
_log.error("ModuleName", "操作失败: %s" % reason, {"error_code": 404})
```

每个日志方法签名：`func debug/info/warning/error(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void`

- `p_tag`：模块标签，便于检索（如 `"Bootstrap"`、`"Save"`、`"Audio"`）
- `p_message`：日志消息主体
- `p_context`：可选的结构化上下文字典

控制台输出使用 `print_rich` 带颜色：
- DEBUG：灰色 `[color=#787878]`
- INFO：默认色
- WARNING：橙色背景 `[bgcolor=#ef6c00]` + `push_warning()`
- ERROR：红色背景 `[bgcolor=#c62828]` + `push_error()`

注意：框架禁止使用 Godot 的 `print()` 和 `printerr()`。所有日志必须通过 `GF_LogService` 输出。

### 第三步：文件输出

启用文件输出后，日志按"级别 / 日期 / 小时段"分层存储：

```
{log_root}/
├── DEBUG/
│   └── 2026-07-31/
│       ├── 08:00:00-09:00:00.log
│       ├── 09:00:00-10:00:00.log
│       └── ...
├── INFO/
│   └── 2026-07-31/
│       └── ...
├── WARNING/
│   └── 2026-07-31/
│       └── ...
└── ERROR/
    └── 2026-07-31/
        └── ...
```

每小时自动切换文件。`_on_dispose()` 时关闭所有打开的文件。

```gdscript
# 配置中启用文件输出
# app_config.json → logging.write_to_file = true
```

### 第四步：LogSink 扩展机制

`GF_LogSink` 是日志接收器的抽象基类。框架内置了 `GF_MemoryLogSink`，你也可以自定义 Sink：

```gdscript
# 注册自定义 Sink（例如：发送到远程服务器）
class_name RemoteLogSink
extends GF_LogSink


func _init() -> void:
    sink_name = "RemoteSink"
    min_level = GF_LogLevel.Level.WARNING  # 只接收 WARNING 及以上


func write(p_level: GF_LogLevel.Level, p_tag: String, p_message: String, p_context: Dictionary) -> void:
    # 发送到远程日志服务
    var entry := {
        "level": GF_LogLevel.level_name(p_level),
        "tag": p_tag,
        "message": p_message,
        "context": p_context,
    }
    _send_to_server(entry)


# 注册
log_service.register_sink(RemoteLogSink.new())
```

### 第五步：MemoryLogSink

框架内置的内存日志 Sink，保留最近 N 条日志（默认 500 条），供调试面板查看：

```gdscript
# 获取 MemorySink（懒初始化）
var memory_sink := log_service.get_memory_sink()

# 获取最近 50 条日志
var entries: Array = memory_sink.get_entries(50)
for entry in entries:
    print("[%s] [%s] %s" % [entry.timestamp, entry.tag, entry.message])

# 清除
memory_sink.clear()
```

每个 Entry 包含字段：`level`、`tag`、`message`、`context`、`timestamp`。

### 第六步：DebugService

`GF_DebugService` 提供运行时统计，仅在 `config.debug.enable_debug_panel = true` 时启用：

```gdscript
# 配置
debug_service.configure(config.debug_section, log_service)

# FPS 统计（由 Scheduler TickGroup.DEBUG 每帧驱动）
func _process(delta: float) -> void:
    debug_service.tick_stats(delta)

# 读取统计
var current_fps := debug_service.fps
var frame_time := debug_service.frame_time_ms
```

`tick_stats` 每秒计算一次平均 FPS 和帧时间。

### 第七步：命令追踪

```gdscript
# 记录命令执行
debug_service.trace_command("cmd_001", "build", "executed")

# 获取命令历史（最多 200 条）
var history := debug_service.get_command_history()
```

### 第八步：网络统计

```gdscript
# 记录网络请求结果
debug_service.record_network_request(true)   # 成功
debug_service.record_network_request(false)  # 失败

# 读取统计
var total := debug_service.network_requests
var errors := debug_service.network_errors

# 重置
debug_service.reset_network_stats()
```

### 第九步：调试面板注册

```gdscript
# 注册自定义调试面板
debug_service.register_panel("ECS Stats", func() -> Node:
    var panel := _EcsDebugPanel.new()
    return panel
)

# 列出所有面板
var panel_names := debug_service.get_panel_names()
```

---

## 完整示例：生产环境日志配置

```gdscript
# ---- app_config.json ----
# {
#   "logging": {
#     "level": "INFO",
#     "write_to_file": true,
#     "log_root": "user://logs"
#   },
#   "debug": {
#     "enable_debug_panel": false,
#     "show_prediction_state": false
#   }
# }

# ---- 引导配置 ----

func _configure_logging(config: GF_AppConfig, path_resolver: GF_PathResolver) -> void:
    var log_service := GF_LogService.new()
    log_service.module_name = "LogService"
    log_service.init_module()

    # 配置日志
    log_service.configure(config.logging_section, path_resolver)

    # 生产环境：抑制 push_error 调用（避免 Godot 编辑器弹窗）
    if not OS.is_debug_build():
        log_service.suppress_push_errors = true

    # 注册远程 Sink（生产环境）
    if config.logging_section.remote_enabled:
        log_service.register_sink(RemoteLogSink.new())

    _log = log_service


# ---- 开发期调试配置 ----

func _configure_debug(config: GF_AppConfig) -> void:
    var debug_service := GF_DebugService.new()
    debug_service.module_name = "DebugService"
    debug_service.init_module()
    debug_service.configure(config.debug_section, _log)

    if debug_service.enabled:
        # 注册调试面板
        debug_service.register_panel("FPS", func() -> Node:
            var label := Label.new()
            label.name = "FPSLabel"
            return label
        )
        debug_service.register_panel("Command History", func() -> Node:
            var list := ItemList.new()
            list.name = "CommandList"
            return list
        )

    _debug = debug_service


# ---- 日志使用规范 ----

# ✅ 好的日志
_log.info("Bootstrap", "应用启动，版本: %s" % game_version)
_log.info("Save", "存档加载完成: slot=%d, 模块数=%d" % [slot_id, count])
_log.warning("Network", "请求超时: %s，重试中..." % url)
_log.error("Config", "物品配置校验失败: %s" % error_detail, {"item_id": item_id})

# ❌ 不好的日志
print("应用启动了")  # 使用 print 而非 LogService
_log.info("", "something")  # tag 为空
_log.error("Save", "失败")  # 不提供具体原因，无法排查
```

---

## 常见变体

### 变体 1：开发期 DEBUG 全开

```json
// app_config.json（开发环境）
{
  "logging": {
    "level": "DEBUG",
    "write_to_file": true,
    "log_root": "user://logs"
  }
}
```

### 变体 2：仅 ERROR 输出到文件

```gdscript
# 自定义 Sink：只记录 ERROR
class ErrorOnlyFileSink
extends GF_LogSink

var _file: FileAccess = null


func _init() -> void:
    sink_name = "ErrorFile"
    min_level = GF_LogLevel.Level.ERROR


func write(p_level: GF_LogLevel.Level, p_tag: String, p_message: String, p_context: Dictionary) -> void:
    var line := "[%s] [%s] %s" % [Time.get_datetime_string_from_system(false, true), p_tag, p_message]
    _file.store_line(line)
```

### 变体 3：运行时切换日志级别

```gdscript
# 通过控制台命令或调试面板切换
func set_log_level(p_level: GF_LogLevel.Level) -> void:
    _log._level = p_level
    _log.info("Log", "日志级别切换为: %s" % GF_LogLevel.level_name(p_level))
```

### 变体 4：日志脱敏

```gdscript
# 不要在日志中输出敏感信息
# ❌ _log.info("Auth", "用户登录: token=%s" % api_token)
# ✅ _log.info("Auth", "用户登录成功: user_id=%s" % user_id)
```

---

## 错误码

| 方法 | 可能的错误码 | 说明 |
|------|------------|------|
| `configure(config, path_resolver)` | `ERR_BAD_REQUEST` | config 为 null |
| `debug_service.configure(config, log)` | `ERR_BAD_REQUEST` | config 或 log 为 null |

日志方法（`debug`/`info`/`warning`/`error`）不返回 `GF_OperationResult`，始终静默执行。

---

## See Also

- [加载游戏配置数据](./load-game-config.md) -- 日志级别配置
- [模块间事件通信](./event-communication.md) -- 调试事件
- [创建和管理 UI 面板](./create-ui-panels.md) -- 调试面板的注册
