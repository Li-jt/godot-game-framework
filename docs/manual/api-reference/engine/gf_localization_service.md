# GF_LocalizationService

> 适用版本: 0.3.0 | 继承: GF_LocalizationService → GF_ModuleLifecycle

## 概述

本地化服务，管理多语言文本的加载和查询。负责从 JSON 文件加载翻译表，按当前语言提供 key 到文本的转换，支持带参数的占位符替换。

**适用场景**：游戏需要多语言支持时，通过 `tr_key()` 获取 UI 文本、提示、对话等本地化内容。

**不适用场景**：不需要多语言的单语言项目；需要运行时热更新翻译表的场景（当前版本只支持启动时加载）。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `_current_locale` | `String` | `"zh"` | 当前语言标识符 |
| `_translations` | `Dictionary` | `{}` | 所有已加载的翻译数据，键为 locale 字符串，值为 key→text 字典 |

## 公共方法

### configure(p_file_system: GF_FileSystemService, p_log: GF_LogService) → GF_OperationResult

注入文件系统服务和日志服务。在 `_on_configure()` 阶段由 Application 层调用。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_file_system` | `GF_FileSystemService` | 文件系统服务，用于读取 JSON 翻译文件 |
| `p_log` | `GF_LogService` | 日志服务，用于输出加载信息和警告 |

**返回值：**

- `GF_OperationResult.ok()` — 配置成功
- `GF_OperationResult.fail(ERR_BAD_REQUEST, ...)` — 任一参数为 null

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| `ERR_BAD_REQUEST` | `p_file_system` 为 null |
| `ERR_BAD_REQUEST` | `p_log` 为 null |

**示例：**

```gdscript
var localization := GF_LocalizationService.new()
var result := localization.configure(file_system, log)
if result.is_fail():
    return result
```

---

### set_locale(p_locale: String) → void

切换当前语言。切换后所有后续 `tr_key()` 调用都将使用新语言的翻译表。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_locale` | `String` | 语言标识符，如 `"zh"`、`"en"`、`"ja"` |

**示例：**

```gdscript
localization.set_locale("en")
print(localization.tr_key("menu.start"))  # 输出英文翻译
localization.set_locale("zh")
print(localization.tr_key("menu.start"))  # 输出中文翻译
```

---

### get_locale() → String

获取当前语言标识符。

**返回值：** 当前 locale 字符串，默认值为 `"zh"`。

**示例：**

```gdscript
var current := localization.get_locale()
if current == "zh":
    show_chinese_ui()
```

---

### tr_key(p_key: String, p_args: Dictionary = {}) → String

获取指定 key 在当前语言下的翻译文本。支持 `{name}` 格式的占位符替换。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_key` | `String` | 翻译 key |
| `p_args` | `Dictionary` | 可选参数字典，用于替换翻译文本中的 `{arg_name}` 占位符 |

**返回值：** 翻译后的文本字符串。如果 key 在当前语言中不存在，则返回 key 本身并通过 LogService 输出 warning。

**示例：**

```gdscript
# 简单翻译
var text := localization.tr_key("menu.start")  # 返回 "开始游戏"

# 带参数替换（翻译表中有 "hello {name}, you have {count} items"）
var text := localization.tr_key("greeting", {"name": "Player", "count": 5})
# 返回 "hello Player, you have 5 items"

# key 不存在时返回 key 本身
var text := localization.tr_key("nonexistent.key")  # 返回 "nonexistent.key"，并输出 warning
```

---

### has_key(p_key: String) → bool

检查指定 key 是否存在于当前语言的翻译表中。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_key` | `String` | 要检查的翻译 key |

**返回值：** `true` 表示 key 存在，`false` 表示不存在。

**示例：**

```gdscript
if localization.has_key("dialog.intro"):
    show_dialog(localization.tr_key("dialog.intro"))
else:
    show_dialog("Welcome!")  # 降级到硬编码文本
```

---

### load_translation(p_locale: String, p_path: String) → GF_OperationResult

从 JSON 文件加载指定语言的翻译表。JSON 文件应为顶层对象的格式，key 为翻译 key，value 为翻译文本。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_locale` | `String` | 语言标识符，如 `"zh"`、`"en"` |
| `p_path` | `String` | JSON 文件的路径，通过 `GF_FileSystemService` 读取 |

**返回值：**

- `GF_OperationResult.ok()` — 加载成功，`result.data` 为翻译字典（`Dictionary`）
- `GF_OperationResult.fail(...)` — 文件读取失败（透传 `GF_FileSystemService.read_json()` 的错误）

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| 透传 | JSON 文件不存在或解析失败 |

**示例：**

```gdscript
# 加载中文翻译
var result := localization.load_translation("zh", "res://content/locale/zh.json")
if result.is_fail():
    log.error("Bootstrap", "中文翻译加载失败: %s" % result.error.message)
    return result

# 加载英文翻译
result = localization.load_translation("en", "res://content/locale/en.json")
if result.is_ok():
    log.info("Bootstrap", "英文翻译加载成功")

# JSON 文件示例 (zh.json):
# {
#   "menu.start": "开始游戏",
#   "menu.settings": "设置",
#   "greeting": "你好 {name}，你有 {count} 个新消息"
# }
```

---

## See Also

- [GF_FileSystemService](../core/gf_file_system_service.md) — 文件系统服务，提供 JSON 读取能力
- [GF_LogService](../core/gf_log_service.md) — 日志服务
- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) — 模块生命周期基类
