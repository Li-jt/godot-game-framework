# GF_PathResolver

> 适用版本: 0.3.0 | 继承: GF_PathResolver -> RefCounted

## 概述

统一路径解析服务。所有模块的路径必须通过此服务获取，禁止自行拼接路径字符串。提供标准化的 `res://`（只读发布资源）和 `user://`（可写用户数据）路径管理，以及路径覆盖解析和标准化工具。

**何时使用:** 获取资源根目录、存档根目录、日志目录、缓存目录，以及任何需要路径标准化或路径越界校验的场景。

**何时不使用:** 不要通过此服务执行实际的文件读写操作 -- 应使用 `GF_FileSystemService`。不要通过此服务加载 Godot 资源 -- 应使用 `GF_AssetLoadingService`。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `config_root` | `String` | `""` | 配置根目录，固定为 `res://config/` |
| `resource_root` | `String` | `""` | 资源根目录，从 `GF_AppConfig` 读取，如 `res://content/` |
| `save_root` | `String` | `""` | 存档根目录，从 `GF_AppConfig` 读取，如 `user://saves/` |
| `log_root` | `String` | `""` | 日志根目录，从 `GF_AppConfig` 读取，如 `user://logs/` |
| `cache_root` | `String` | `""` | 缓存根目录，从 `GF_AppConfig` 读取，如 `user://cache/` |

所有属性在 `configure()` 或 `configure_from_app_config()` 调用后可用。配置前为空字符串。

## 公共方法

### configure_from_app_config(p_config: GF_AppConfig) -> GF_OperationResult

从 `GF_AppConfig` 读取所有路径配置（resource、save、cache、log 根目录），并保留 `GF_AppConfig` 引用以支持后续的路径覆盖解析（`resolve_*` 方法）。这是推荐的配置方式，保证路径与全局应用配置一致。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_config` | `GF_AppConfig` | 应用配置实例 |

**返回值:** `GF_OperationResult` -- 成功返回 OK。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_BAD_REQUEST` | `p_config` 为 null，或内部 `configure()` 发现空路径 |

**示例:**

```gdscript
var pr := GF_PathResolver.new()
var result := pr.configure_from_app_config(app_config)
if result.is_fail():
    push_error("路径解析器配置失败: %s" % result.error.message)
    return
```

---

### configure(p_resource_base: String, p_save_root: String, p_cache_root: String, p_log_root: String) -> GF_OperationResult

显式配置各路径根目录。拒绝空字符串参数。通常不直接调用，而是通过 `configure_from_app_config()` 间接配置。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_resource_base` | `String` | 资源根目录的相对路径（如 `"content"`），自动转为 `res://content/` |
| `p_save_root` | `String` | 存档根目录的相对路径（如 `"saves"`），自动转为 `user://saves/` |
| `p_cache_root` | `String` | 缓存根目录的相对路径，自动转为 `user://` 前缀 |
| `p_log_root` | `String` | 日志根目录的相对路径，自动转为 `user://` 前缀 |

**返回值:** `GF_OperationResult` -- 成功返回 OK。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_BAD_REQUEST` | `p_resource_base`、`p_save_root` 或 `p_log_root` 为空字符串 |

**示例:**

```gdscript
var result := pr.configure("content", "saves", "cache", "logs")
if result.is_fail():
    push_error("配置失败: %s" % result.error.message)
```

---

### Getters

以下方法返回配置后的路径根目录（字符串）。

---

### get_config_root() -> String

返回配置根目录，固定为 `res://config/`。

```gdscript
var config_path := pr.get_config_root()  # "res://config/"
var full_path := config_path + "app_config.json"
```

---

### get_resource_root() -> String

返回资源根目录，如 `res://content/`。`GF_AssetLoadingService` 加载相对路径资源时会拼接此路径。

```gdscript
var content_root := pr.get_resource_root()  # "res://content/"
```

---

### get_save_root() -> String

返回存档根目录，如 `user://saves/`。

```gdscript
var save_path := pr.get_save_root() + "slot_1.json"  # "user://saves/slot_1.json"
```

---

### get_log_root() -> String

返回日志根目录，如 `user://logs/`。

```gdscript
var log_path := pr.get_log_root() + "game_2024-01-15.log"
```

---

### get_cache_root() -> String

返回缓存根目录，如 `user://cache/`。

```gdscript
var cache_path := pr.get_cache_root() + "thumbnails/"
```

---

### 路径覆盖解析

以下方法提供 "配置覆盖 + 默认值" 的路径解析模式。优先使用 `GF_AppConfig.path_overrides` 配置的路径，未配置时回退到提供的默认值。适用于框架提供合理默认值、同时允许使用者通过配置覆盖的场景。

---

### resolve_scene_host_path(p_default: String = "res://addons/godot-game-framework/engine/scene_host/scene_host.tscn") -> String

解析 `GF_SceneHost` 场景路径。优先取 `GF_AppConfig.path_overrides.scene_host` 覆盖值。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_default` | `String` | 默认场景路径 |

**返回值:** `String` -- 解析后的场景路径。

---

### resolve_world_scene(p_default: String = "res://content/scenes/world/world_root.tscn") -> String

解析世界场景路径。优先取 `GF_AppConfig.path_overrides.world_scene` 覆盖值。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_default` | `String` | 默认世界场景路径 |

**返回值:** `String` -- 解析后的世界场景路径。

---

### resolve_localization_root(p_default: String = "res://content/localization") -> String

解析本地化文件根目录。优先取 `GF_AppConfig.path_overrides.localization_root` 覆盖值。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_default` | `String` | 默认本地化根目录 |

**返回值:** `String` -- 解析后的本地化根目录。

---

### resolve_input_bindings_path(p_default: String = "user://input_bindings_v1.tres") -> String

解析输入重绑文件路径。优先取 `GF_AppConfig.path_overrides.input_bindings_path` 覆盖值。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_default` | `String` | 默认输入绑定文件路径 |

**返回值:** `String` -- 解析后的输入绑定文件路径。

---

### 工具方法

---

### ensure_dir(p_path: String) -> bool

确保目录存在，不存在则递归创建。返回是否成功（或已存在）。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 目录路径 |

**返回值:** `bool` -- 目录存在或创建成功返回 `true`。

**示例:**

```gdscript
if not pr.ensure_dir(pr.get_save_root()):
    push_error("无法创建存档目录")
    return
```

---

### res_path(p_relative: String) -> String

在 `res://` 下拼接路径，确保以 `/` 结尾。自动处理前导 `./` 和尾随 `/`。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_relative` | `String` | 相对路径片段 |

**返回值:** `String` -- 格式化的 `res://` 路径。

**示例:**

```gdscript
var path := pr.res_path("content")       # "res://content/"
var path2 := pr.res_path("./sprites/")   # "res://sprites/"
```

---

### user_path(p_relative: String) -> String

在 `user://` 下拼接路径，确保以 `/` 结尾。自动处理前导 `./` 和尾随 `/`。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_relative` | `String` | 相对路径片段 |

**返回值:** `String` -- 格式化的 `user://` 路径。

**示例:**

```gdscript
var path := pr.user_path("saves")        # "user://saves/"
var path2 := pr.user_path("./cache/")    # "user://cache/"
```

---

### normalize(p_path: String) -> String  *(静态)*

路径标准化：去除开头的 `./`、去除 `/./`、合并连续 `//`、统一反斜杠为正斜杠。保护 `res://` 和 `user://` 前缀不被误修改。这是一个纯字符串处理函数，不访问文件系统。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 待标准化的路径字符串 |

**返回值:** `String` -- 标准化后的路径。

**示例:**

```gdscript
GF_PathResolver.normalize("res://config//app.json")   # "res://config/app.json"
GF_PathResolver.normalize("./data/file.txt")           # "data/file.txt"
GF_PathResolver.normalize("res://path/to/../file")     # "res://path/to/../file" (不解析 ..)
GF_PathResolver.normalize("user://logs\\game.log")     # "user://logs/game.log"
```

**注意:** `normalize()` 不解析 `..`（父目录）-- 仅处理 `./`、`//` 和斜杠统一。路径越界检测应使用 `ensure_under_root()`。

---

### ensure_under_root(p_path: String, p_root: String) -> GF_OperationResult  *(静态)*

校验路径未越出指定根目录。包含 `../` 的路径会被拒绝，路径不以 `p_root` 开头的也会被拒绝。自动确保 `p_root` 以 `/` 结尾以便前缀匹配。这是一个纯字符串校验函数，不访问文件系统。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 待校验的路径 |
| `p_root` | `String` | 允许的根目录路径 |

**返回值:** `GF_OperationResult` -- 路径合规返回 OK。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_FORBIDDEN` | 路径包含 `../` 或路径不在 `p_root` 下 |

**示例:**

```gdscript
# 安全：检查存档路径未越出存档目录
var result := GF_PathResolver.ensure_under_root("user://saves/../../etc/passwd", "user://saves/")
if result.is_fail():
    _log.error("Security", "路径越界尝试被拦截: %s" % result.error.message)
    return

# 合规路径
var result2 := GF_PathResolver.ensure_under_root("user://saves/slot_1.json", "user://saves/")
assert(result2.is_ok())
```

---

## 路径约定总结

| 路径 | 前缀 | 用途 | 只读/可写 |
|------|------|------|----------|
| `config_root` | `res://config/` | 应用配置（`.json`、`.cfg`） | 只读（发布资源） |
| `resource_root` | `res://content/` | 游戏资源（场景、贴图、Def 配置） | 只读（发布资源） |
| `save_root` | `user://saves/` | 存档文件 | 可写 |
| `log_root` | `user://logs/` | 运行日志 | 可写 |
| `cache_root` | `user://cache/` | 临时缓存 | 可写 |

## 完整使用示例

```gdscript
# 配置
var pr := GF_PathResolver.new()
var result := pr.configure_from_app_config(app_config)
if result.is_fail():
    return result

# 获取各路径根目录
var save_root := pr.get_save_root()          # "user://saves/"
var log_root := pr.get_log_root()            # "user://logs/"
var content_root := pr.get_resource_root()   # "res://content/"

# 路径覆盖解析（框架默认值 + 使用者可覆盖）
var world_scene := pr.resolve_world_scene()  # 默认 "res://content/scenes/world/world_root.tscn"

# 路径标准化和校验
var full_path := save_root + "profile.json"
var normalized := GF_PathResolver.normalize(full_path)

var check := GF_PathResolver.ensure_under_root(normalized, save_root)
if check.is_fail():
    _log.error("Security", "路径校验失败: %s" % check.error.message)
    return
```

## See Also

- [GF_AssetLoadingService](./gf_scene_factory.md#gf_assetloadingservice) -- 使用此服务解析资源路径
- [GF_FileSystemService](./gf_file_system_service.md) -- 使用此服务获取存档/日志路径
- [GF_SceneFactory](./gf_scene_factory.md) -- 使用此服务解析场景路径
