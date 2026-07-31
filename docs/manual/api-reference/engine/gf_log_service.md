# GF_LogService

> 适用版本: 0.3.0 | 继承: GF_LogService -> GF_ModuleLifecycle

## 概述

统一日志服务。所有框架模块和 Game 层通过此服务输出日志，**禁止**直接使用 `print()` / `printerr()`。支持多级别过滤、控制台彩色输出、按级别/日期/小时分层的文件持久化、以及可扩展的 Sink 体系。**不适用于**性能敏感的热路径逐帧日志——高频日志应使用采样或仅在 Debug 构建中启用。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| suppress_push_errors | bool | `false` | 设为 `true` 时，`error()` 不调用 `push_error()`，避免在测试或特定场景中触发 Godot 错误弹窗 |

## 公共方法

### configure(p_config: GF_AppConfig.LoggingSection, p_path_resolver: GF_PathResolver = null) -> GF_OperationResult

设置日志级别、文件输出开关和日志根目录。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_config | GF_AppConfig.LoggingSection | 日志配置段，包含 `level`（字符串）、`write_to_file`（布尔）、`log_root`（路径） |
| p_path_resolver | GF_PathResolver | 可选路径解析器。传入时使用 `get_log_root()` 解析路径；为 `null` 时回退到 `p_config.log_root` 原始值（bootstrap 阶段 `PathResolver` 尚未就绪的兼容场景） |

**返回值:** 配置成功返回 `GF_OperationResult.ok()`，`p_config` 为 `null` 返回 `ERR_BAD_REQUEST`。

**示例:**

```gdscript
var result := log_service.configure(app_config.logging, path_resolver)
if result.is_fail():
    push_error("LogService 配置失败")
```

---

### register_sink(p_sink: GF_LogSink) -> void

注册外部日志 Sink。注册后，所有达到 Sink 的 `min_level` 的日志事件都会分发给该 Sink。典型用法：启动时注册 `GF_MemoryLogSink` 供 Debug 面板查看历史日志。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_sink | GF_LogSink | 日志接收器实例 |

---

### get_memory_sink() -> GF_MemoryLogSink

**返回值:** `GF_MemoryLogSink` — 内置内存 Sink。首次调用时懒初始化（容量 500 条），并自动注册到本服务。

**示例:**

```gdscript
# Debug 面板获取最近 50 条日志
var sink := log_service.get_memory_sink()
for entry in sink.get_entries(50):
    debug_list.add_item("[%s] %s" % [entry.tag, entry.message])
```

---

### remove_sink(p_sink: GF_LogSink) -> void

移除已注册的 Sink，该 Sink 不再接收后续日志事件。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_sink | GF_LogSink | 要移除的 Sink 实例 |

---

### debug(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_tag | String | 日志标签（模块名或功能标识），如 `"ECS"`、`"Bootstrap"` |
| p_message | String | 日志消息正文 |
| p_context | Dictionary | 可选的附加上下文数据，供 Sink 消费 |

用于开发调试信息。当前级别高于 `DEBUG` 时被抑制。

---

### info(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void

**参数:** 同 `debug()`。

用于关键流程节点（启动完成、场景切换、存档保存等）。当前级别高于 `INFO` 时被抑制。

---

### warning(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void

**参数:** 同 `debug()`。

用于非致命异常、降级、fallback 行为。**附带调用 `push_warning()`** 输出到 Godot 调试器。

---

### error(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void

**参数:** 同 `debug()`。

用于错误和操作失败。**附带调用 `push_error()`**（除非 `suppress_push_errors = true`）输出到 Godot 错误面板并触发断点。

## 日志行为

### 级别过滤

通过 `configure()` 设置日志级别后，低于该级别的日志消息被静默抑制：

| 设置级别 | 输出内容 |
|----------|----------|
| `DEBUG` | 全部输出（DEBUG + INFO + WARNING + ERROR） |
| `INFO` | INFO + WARNING + ERROR |
| `WARNING` | WARNING + ERROR |
| `ERROR` | 仅 ERROR |

### 控制台输出

使用 `print_rich()` 输出，按级别着色：

| 级别 | 颜色 |
|------|------|
| DEBUG | 灰色文字（`#787878`） |
| INFO | 默认颜色（无格式） |
| WARNING | 橙色背景（`#ef6c00`）+ 黑色文字 |
| ERROR | 红色背景（`#c62828`）+ 白色文字 |

WARNING 级别同时调用 `push_warning()`，ERROR 级别同时调用 `push_error()`（受 `suppress_push_errors` 控制）。

### 文件输出

当 `configure()` 中 `write_to_file = true` 时启用。文件按三级目录结构组织：

```text
{log_root}/
├── DEBUG/
│   └── 2026-05-13/
│       ├── 14:00:00-15:00:00.log
│       └── 15:00:00-16:00:00.log
├── INFO/
│   └── 2026-05-13/
│       └── 15:00:00-16:00:00.log
├── WARN/
│   └── ...
└── ERROR/
    └── ...
```

- **级别目录**：按 `DEBUG` / `INFO` / `WARN` / `ERROR` 分目录
- **日期目录**：`YYYY-MM-DD` 格式
- **小时段文件**：`HH:00:00-HH+1:00:00.log`，每小时自动切换新文件
- **目录自动创建**：日志写入前确保目录存在，创建失败通过 `push_warning()` 报告
- **文件追加模式**：日志追加到文件末尾（`seek_end()`），不覆盖已有内容

### Sink 分发

每次 `_log()` 调用遍历所有已注册的 `GF_LogSink`，将 `p_level >= sink.min_level` 的日志分发给 Sink 的 `write()` 方法。Sink 可自行决定存储格式和展示方式。

### 日志格式

所有输出通道（控制台、文件、Sink）共享统一格式：

```text
[2026-05-13 15:30:45] [INFO] [Bootstrap] 应用启动完成
```

### Bootstrap 例外

`GF_LogService` 的文件 I/O 直接使用 `DirAccess` / `FileAccess`，不经过 `GF_FileSystemService`。这是合法的例外——在 `GF_FileSystemService` 尚未就绪的 bootstrap 阶段，日志服务仍需独立输出日志。

## See Also

- `GF_LogLevel` — 日志级别定义与解析
- `GF_LogSink` — Sink 抽象基类
- `GF_MemoryLogSink` — 内置内存 Sink
- `GF_ModuleLifecycle` — 服务生命周期基类
