# GF_FileSystemService

> 适用版本: 0.3.0 | 继承: GF_FileSystemService -> GF_ModuleLifecycle

## 概述

统一文件系统服务，封装 Godot 的 `FileAccess` / `DirAccess`。所有模块的文件读写、目录操作必须通过此服务，禁止直接使用 `FileAccess`。所有方法返回 `GF_OperationResult`，提供统一的错误处理和空值守卫。

**何时使用:** 读写文本文件、JSON 配置、存档数据、日志文件，以及目录创建、文件列表、备份等操作。

**何时不使用:** 不要通过此服务加载 Godot 资源（`.tscn`、`.png`、`.ogg` 等）-- 应使用 `GF_AssetLoadingService`。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| (无公共属性) | | | 此服务无需 `configure()`，`_on_init()` 直接返回 OK |

## 公共方法

---

### 存在性检查

---

### file_exists(p_path: String) -> bool

检查文件是否存在。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 文件路径（支持 `res://` 和 `user://` 前缀） |

**返回值:** `bool` -- 文件存在返回 `true`。

**示例:**

```gdscript
if fs.file_exists("user://saves/slot_1.json"):
    print("存档文件存在")
```

---

### get_modified_time(p_path: String) -> int

获取文件最后修改时间（Unix 时间戳，秒）。文件不存在时返回 `0`。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 文件路径 |

**返回值:** `int` -- Unix 时间戳，文件不存在返回 `0`。

**示例:**

```gdscript
var mtime := fs.get_modified_time("user://saves/slot_1.json")
if mtime > 0:
    var dt := Time.get_datetime_dict_from_unix_time(mtime)
    print("最后存档: %d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute])
```

---

### dir_exists(p_path: String) -> bool

检查目录是否存在。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 目录路径 |

**返回值:** `bool` -- 目录存在返回 `true`。

---

### 目录操作

---

### ensure_dir(p_path: String) -> GF_OperationResult

确保目录存在，不存在则递归创建。目录已存在时直接返回成功。这是幂等操作，可安全重复调用。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 目录路径 |

**返回值:** `GF_OperationResult` -- 成功返回 OK。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_IO` | 目录创建失败（权限不足、磁盘满等） |

**示例:**

```gdscript
var result := fs.ensure_dir("user://saves/profiles/")
if result.is_fail():
    _log.error("FileSystem", "无法创建存档目录: %s" % result.error.message)
```

---

### list_files(p_dir: String) -> GF_OperationResult

列出目录下的文件（仅返回文件名，不包含子目录）。目录不存在时返回空数组。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_dir` | `String` | 目录路径 |

**返回值:** `GF_OperationResult` -- 成功时 `data` 为 `Array[String]`，每个元素为文件名。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_IO` | 无法打开目录 |

**示例:**

```gdscript
var result := fs.list_files("user://saves/")
if result.is_ok():
    for filename: String in result.data:
        if filename.ends_with(".json"):
            print("发现存档: %s" % filename)
```

---

### 原子写入与备份

---

### write_text_atomic(p_path: String, p_content: String) -> GF_OperationResult

原子写入文件：先将内容写入 `.tmp` 临时文件，然后 `rename` 替换目标文件。写入过程中崩溃不会损坏原文件，保证数据安全。适用于存档、配置等关键数据。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 目标文件路径 |
| `p_content` | `String` | 要写入的文本内容 |

**返回值:** `GF_OperationResult` -- 成功返回 OK。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_IO` | 目录创建失败、临时文件写入失败或 rename 失败 |

**示例:**

```gdscript
var json_text := JSON.stringify(save_data, "\t")
var result := fs.write_text_atomic("user://saves/slot_1.json", json_text)
if result.is_fail():
    _log.error("Save", "存档写入失败: %s" % result.error.message)
```

---

### backup_file(p_path: String) -> GF_OperationResult

备份文件：将文件复制为同名 `.bak` 文件。原文件不存在时跳过（返回成功）。适用于修改关键文件前的安全操作。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 要备份的文件路径 |

**返回值:** `GF_OperationResult` -- 成功返回 OK。

**示例:**

```gdscript
# 修改配置前先备份
var result := fs.backup_file("user://config.json")
if result.is_fail():
    _log.warning("Config", "配置备份失败: %s" % result.error.message)
# 继续修改原文件...
```

---

### 文件操作

---

### copy_file(p_from: String, p_to: String) -> GF_OperationResult

复制文件。内部通过读取源文件文本内容再写入目标文件实现。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_from` | `String` | 源文件路径 |
| `p_to` | `String` | 目标文件路径 |

**返回值:** `GF_OperationResult` -- 成功返回 OK。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 源文件不存在 |
| `ERR_IO` | 读取或写入失败 |

**示例:**

```gdscript
var result := fs.copy_file("user://saves/slot_1.json", "user://saves/backup/slot_1.json")
if result.is_fail():
    _log.error("FileSystem", "文件复制失败: %s" % result.error.message)
```

---

### move_file(p_from: String, p_to: String) -> GF_OperationResult

移动或重命名文件。直接使用操作系统级 `rename`，效率高于复制后删除。自动确保目标父目录存在。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_from` | `String` | 源文件路径 |
| `p_to` | `String` | 目标文件路径 |

**返回值:** `GF_OperationResult` -- 成功返回 OK。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 源文件不存在 |
| `ERR_IO` | rename 操作失败 |

**示例:**

```gdscript
var result := fs.move_file("user://temp/save.json", "user://saves/slot_1.json")
if result.is_fail():
    _log.error("FileSystem", "文件移动失败: %s" % result.error.message)
```

---

### delete_file(p_path: String) -> GF_OperationResult

删除文件。文件不存在时返回错误。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 要删除的文件路径 |

**返回值:** `GF_OperationResult` -- 成功返回 OK。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 文件不存在 |
| `ERR_IO` | 删除操作失败 |

**示例:**

```gdscript
var result := fs.delete_file("user://cache/temp_data.json")
if result.is_fail() and result.status_code != GF_OperationResult.ERR_NOT_FOUND:
    _log.error("FileSystem", "文件删除失败: %s" % result.error.message)
```

---

### 文本读写

---

### read_text(p_path: String) -> GF_OperationResult

读取文本文件的全部内容。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 文件路径 |

**返回值:** `GF_OperationResult` -- 成功时 `data` 为 `String`（文件内容）。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 文件不存在 |
| `ERR_IO` | 无法打开文件 |

**示例:**

```gdscript
var result := fs.read_text("res://config/default_settings.json")
if result.is_ok():
    var text: String = result.data
    print("配置长度: %d 字符" % text.length())
```

---

### write_text(p_path: String, p_content: String) -> GF_OperationResult

写入文本文件（覆盖模式）。自动确保父目录存在。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 文件路径 |
| `p_content` | `String` | 要写入的文本内容 |

**返回值:** `GF_OperationResult` -- 成功返回 OK。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_IO` | 目录创建失败或文件写入失败 |

**示例:**

```gdscript
var result := fs.write_text("user://logs/game.log", "[INFO] 游戏启动\n")
if result.is_fail():
    push_error("日志写入失败: %s" % result.error.message)
```

**注意:** 对于存档等关键数据，优先使用 `write_text_atomic()` 以保证写入过程中的数据安全。

---

### append_text(p_path: String, p_content: String) -> GF_OperationResult

追加写入文本文件（创建或追加模式）。自动确保父目录存在，文件不存在则创建。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 文件路径 |
| `p_content` | `String` | 要追加的文本内容 |

**返回值:** `GF_OperationResult` -- 成功返回 OK。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_IO` | 目录创建失败或文件打开/写入失败 |

**示例:**

```gdscript
var result := fs.append_text("user://logs/game.log", "[INFO] 玩家登录\n")
if result.is_fail():
    push_error("日志追加失败: %s" % result.error.message)
```

---

### JSON 读写

---

### read_json(p_path: String) -> GF_OperationResult

读取并解析 JSON 文件，返回 `Dictionary`。内部先调用 `read_text()` 获取文本，再用 `JSON.parse_string()` 解析。解析失败（结果非 Dictionary 或 null）返回 `ERR_IO`。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | JSON 文件路径 |

**返回值:** `GF_OperationResult` -- 成功时 `data` 为 `Dictionary`。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 文件不存在 |
| `ERR_IO` | 文件读取失败或 JSON 解析失败 |

**示例:**

```gdscript
var result := fs.read_json("res://config/app_config.json")
if result.is_ok():
    var config: Dictionary = result.data
    print("应用名称: %s" % config.get("app_name", "未命名"))
```

---

### write_json(p_path: String, p_data: Dictionary, p_indent: String = "\t") -> GF_OperationResult

将 `Dictionary` 序列化为 JSON 并写入文件。默认使用 Tab 缩进。内部调用 `JSON.stringify()` 后通过 `write_text()` 写入。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 文件路径 |
| `p_data` | `Dictionary` | 要写入的数据 |
| `p_indent` | `String` | 缩进字符串，默认 `"\t"` |

**返回值:** `GF_OperationResult` -- 成功返回 OK。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_IO` | JSON 序列化失败或文件写入失败 |

**示例:**

```gdscript
var save_data := {
    "version": 3,
    "player_name": "勇者",
    "level": 15,
    "gold": 9999
}
var result := fs.write_json("user://saves/slot_1.json", save_data, "  ")
if result.is_fail():
    _log.error("Save", "存档写入失败: %s" % result.error.message)
```

---

## 操作选择指南

| 场景 | 推荐方法 | 原因 |
|------|---------|------|
| 写入存档数据 | `write_text_atomic()` | 崩溃安全，写入过程中不会损坏原文件 |
| 写入日志 | `append_text()` | 追加模式，不覆盖已有日志 |
| 修改配置前 | `backup_file()` | 可回滚到修改前的版本 |
| 读取 JSON 配置 | `read_json()` | 一次性完成读取和解析 |
| 写入 JSON 数据 | `write_json()` | 自动序列化，避免手动拼 JSON 字符串 |
| 检查存档文件存在 | `file_exists()` | 直接返回 bool，无需检查 `GF_OperationResult` |

## See Also

- [GF_AssetLoadingService](./gf_scene_factory.md#gf_assetloadingservice) -- 资源加载服务（`.tscn`、`.png` 等 Godot 资源）
- [GF_PathResolver](./gf_path_resolver.md) -- 路径解析服务
- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) -- 模块生命周期基类
- [GF_OperationResult](../core/gf_operation_result.md) -- 统一操作结果类型
