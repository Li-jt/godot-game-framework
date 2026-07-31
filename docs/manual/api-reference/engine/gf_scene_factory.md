# GF_SceneFactory

> 适用版本: 0.3.0 | 继承: GF_SceneFactory -> GF_ModuleLifecycle

## 概述

统一场景/节点实例化工厂。封装 `PackedScene` 加载与 `instantiate()`，所有模块的场景实例化和 UI 面板创建必须通过此服务，禁止直接调用 `.instantiate()`。依赖于 `GF_AssetLoadingService` 完成底层资源加载。

**适用场景:** 场景实例化、UI 面板创建、动态节点生成。不要在游戏逻辑中直接调用 `scene.instantiate()` 或 `load()`。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| (无公共属性) | | | 通过 `configure()` 注入依赖 |

## 公共方法

### configure(p_asset_loading: GF_AssetLoadingService, p_log: GF_LogService) -> GF_OperationResult

注入依赖：资源加载服务和日志服务。必须在调用 `create()` / `instantiate()` 之前执行。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_asset_loading` | `GF_AssetLoadingService` | 已配置的资源加载服务实例 |
| `p_log` | `GF_LogService` | 日志服务实例 |

**返回值:** `GF_OperationResult` -- 成功返回 `OK`，任一参数为 null 返回 `ERR_BAD_REQUEST`。

**示例:**

```gdscript
var result := scene_factory.configure(asset_loading, log)
if result.is_fail():
    push_error("GF_SceneFactory 配置失败: %s" % result.error.message)
    return
```

---

### create(p_scene_path: String, p_init_data: Dictionary = {}) -> GF_OperationResult

加载场景并实例化根节点。内部调用 `GF_AssetLoadingService.load_scene()` 加载 `PackedScene`，然后 `instantiate()` 生成节点实例。若 `p_init_data` 非空，会检查节点是否有 `_on_factory_init(data)` 钩子方法，有则调用。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_scene_path` | `String` | 场景文件路径，支持 `res://` 或相对路径（相对于 `GF_PathResolver.resource_root`） |
| `p_init_data` | `Dictionary` | 可选初始化数据，传入后调用节点的 `_on_factory_init(data)` 钩子（如有） |

**返回值:** `GF_OperationResult` -- 成功时 `data` 为实例化的 `Node`，失败时见错误码。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 场景文件不存在 |
| `ERR_IO` | 场景加载或实例化失败 |

**示例:**

```gdscript
var result := factory.create("ui/hud_panel.tscn", {"player_id": 123})
if result.is_ok():
    add_child(result.data)
else:
    _log.error("UI", "面板创建失败: %s" % result.error.message)
```

---

### create_and_add(p_scene_path: String, p_parent: Node, p_init_data: Dictionary = {}) -> GF_OperationResult

创建场景并挂载到父节点，是 `create()` + `add_child()` 的组合调用。适用于频繁的创建-挂载场景。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_scene_path` | `String` | 场景文件路径 |
| `p_parent` | `Node` | 目标父节点 |
| `p_init_data` | `Dictionary` | 可选初始化数据 |

**返回值:** `GF_OperationResult` -- 成功时 `data` 为实例化并已挂载的 `Node`。

**示例:**

```gdscript
var result := factory.create_and_add("ui/dialog.tscn", ui_root, {"message": "欢迎回来"})
if result.is_ok():
    var dialog: Node = result.data
    # dialog 已在 ui_root 下
```

---

### instantiate(p_scene: PackedScene, p_init_data: Dictionary = {}) -> GF_OperationResult

用已加载的 `PackedScene` 直接实例化，避免重复加载同一个场景资源。当需要批量创建同一场景的多个实例时（如子弹、粒子），先通过 `GF_AssetLoadingService.load_scene()` 加载一次，再多次调用此方法。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_scene` | `PackedScene` | 已加载的场景资源 |
| `p_init_data` | `Dictionary` | 可选初始化数据 |

**返回值:** `GF_OperationResult` -- 成功时 `data` 为实例化的 `Node`，失败时 `ERR_IO`。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_IO` | 实例化失败（`instantiate()` 返回 null） |

**示例:**

```gdscript
# 先加载一次
var scene_result := asset_loading.load_scene("vfx/explosion.tscn")
if scene_result.is_fail():
    return scene_result

var explosion_scene: PackedScene = scene_result.data

# 批量创建多个实例
for i in range(10):
    var result := factory.instantiate(explosion_scene, {"radius": float(i + 1) * 10.0})
    if result.is_ok():
        add_child(result.data)
```

---

## 初始化钩子

节点可以选择实现 `_on_factory_init(data: Dictionary) -> void` 方法作为初始化钩子。`GF_SceneFactory` 在实例化后、返回前自动调用此方法：

```gdscript
# 在场景根节点脚本中
func _on_factory_init(data: Dictionary) -> void:
    if data.has("player_id"):
        _player_id = data["player_id"]
    if data.has("message"):
        $Label.text = data["message"]
```

---

## See Also

- [GF_AssetLoadingService](#gf_assetloadingservice) -- 上游资源加载服务
- [GF_PathResolver](./gf_path_resolver.md) -- 路径解析服务，决定场景路径如何定位
- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) -- 模块生命周期基类

---

# GF_AssetLoadingService

> 适用版本: 0.3.0 | 继承: GF_AssetLoadingService -> GF_ModuleLifecycle

## 概述

统一资源加载服务，封装 Godot 的 `load()` / `ResourceLoader.load()`。所有模块的资源加载必须通过此服务，禁止直接使用 `load()`。内部集成 `GF_PathResolver` 进行路径解析，相对路径自动拼接 `resource_root`。

**何时使用:** 加载 PackedScene、Texture2D、AudioStream 或任意 Resource 时。不要在代码中直接写 `load("res://...")`。

**何时不使用:** 不要通过此服务访问文件系统的纯文本或 JSON 数据 -- 应使用 `GF_FileSystemService`。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| (无公共属性) | | | 通过 `configure()` 注入依赖 |

## 公共方法

### configure(p_path_resolver: GF_PathResolver, p_log: GF_LogService) -> GF_OperationResult

注入依赖：路径解析服务和日志服务。必须在调用任何加载方法之前执行。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path_resolver` | `GF_PathResolver` | 已配置的路径解析服务实例 |
| `p_log` | `GF_LogService` | 日志服务实例 |

**返回值:** `GF_OperationResult` -- 成功返回 `OK`，任一参数为 null 返回 `ERR_BAD_REQUEST`。

**示例:**

```gdscript
var result := asset_loading.configure(path_resolver, log)
if result.is_fail():
    push_error("GF_AssetLoadingService 配置失败: %s" % result.error.message)
    return
```

---

### load_scene(p_path: String) -> GF_OperationResult

加载 `PackedScene` 资源。路径支持绝对（`res://`/`user://`）和相对路径。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 场景文件路径（`.tscn` 或 `.scn`） |

**返回值:** `GF_OperationResult` -- 成功时 `data` 为 `PackedScene` 实例。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 资源文件不存在 |
| `ERR_IO` | 资源加载失败 |

**示例:**

```gdscript
var result := asset_loading.load_scene("scenes/main_menu.tscn")
if result.is_ok():
    var scene: PackedScene = result.data
    var node := scene.instantiate()
    add_child(node)
```

---

### load_texture(p_path: String) -> GF_OperationResult

加载 `Texture2D` 资源（贴图、精灵、图标等）。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 纹理文件路径（`.png`、`.webp`、`.jpg` 等） |

**返回值:** `GF_OperationResult` -- 成功时 `data` 为 `Texture2D` 实例。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 资源文件不存在 |
| `ERR_IO` | 资源加载失败 |

**示例:**

```gdscript
var result := asset_loading.load_texture("ui/icons/sword.png")
if result.is_ok():
    $Icon.texture = result.data
```

---

### load_audio(p_path: String) -> GF_OperationResult

加载 `AudioStream` 资源（BGM、SFX、环境音等）。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 音频文件路径（`.ogg`、`.mp3`、`.wav` 等） |

**返回值:** `GF_OperationResult` -- 成功时 `data` 为 `AudioStream` 实例。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 资源文件不存在 |
| `ERR_IO` | 资源加载失败 |

**示例:**

```gdscript
var result := asset_loading.load_audio("bgm/title_theme.ogg")
if result.is_ok():
    $AudioPlayer.stream = result.data
    $AudioPlayer.play()
```

---

### load_resource(p_path: String) -> GF_OperationResult

加载任意 `Resource` 类型（配置 Def、字体文件、材质、着色器等）。这是通用加载入口，不限定具体资源类型。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_path` | `String` | 资源文件路径 |

**返回值:** `GF_OperationResult` -- 成功时 `data` 为 `Resource` 实例。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_NOT_FOUND` | 资源文件不存在 |
| `ERR_IO` | 资源加载失败 |

**示例:**

```gdscript
var result := asset_loading.load_resource("config/weapons/iron_sword.tres")
if result.is_ok():
    var weapon_def: Resource = result.data
    print("武器: %s, 伤害: %d" % [weapon_def.weapon_name, weapon_def.damage])
```

---

## 路径解析规则

`GF_AssetLoadingService` 内部自动解析路径：

- 以 `res://` 或 `user://` 开头的路径，直接使用
- 相对路径（如 `"scenes/main.tscn"`），自动拼接 `GF_PathResolver.get_resource_root()`
- 未配置 `GF_PathResolver` 时，相对路径默认拼接 `"res://"`

## See Also

- [GF_SceneFactory](#gf_scenefactory) -- 下游场景实例化工厂，使用此服务加载场景
- [GF_PathResolver](./gf_path_resolver.md) -- 路径解析服务
- [GF_FileSystemService](./gf_file_system_service.md) -- 文件系统服务（文本/JSON 读写）
- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) -- 模块生命周期基类
