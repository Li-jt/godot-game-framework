# GF_ConfigService

> 适用版本: 0.3.0 | 继承: GF_ConfigService -> GF_ModuleLifecycle

## 概述

游戏内容定义仓库，是游戏层配置数据的集中存储和查询中心。Framework 只提供按类型+ID 索引的存储和查询机制，不关心具体 Def 的字段结构。Game 层负责定义 Def 类型（如 ItemDef、BuildingDef 等），通过 `register_defs()` 或 `load_json()` 注册到仓库，通过 `get_def()` 和 `get_all()` 查询。支持 JSON 文件加载、引用完整性校验，以及开发期热重载。

**使用场景：**

- 游戏启动时加载所有内容定义（物品、建筑、技能等）
- 运行时通过 ID 查询单条定义（`get_def("items", "wood")`）
- 遍历某类型所有定义用于 UI 列表或缓存预热
- 开发期启用热重载，修改 JSON 文件后无需重启游戏
- 在 `GF_ReferenceValidator` 中校验跨类型引用完整性

**不适用场景：**

- 不要用于存储运行时状态（应使用 ECS World 或 SaveService）
- 不要用于存储玩家数据或存档数据（应使用 SaveService）
- 不要将配置硬编码在此服务之外（应统一通过此仓库访问）

## 属性

此服务不暴露公共成员属性。

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| （无公共属性） | | | 通过方法访问所有功能 |

## 公共方法

### 生命周期

---

#### configure(p_file_system: GF_FileSystemService, p_log: GF_LogService) -> GF_OperationResult
注入文件系统服务和日志服务的依赖。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_file_system | GF_FileSystemService | 文件系统服务，用于读取 JSON 文件和检查文件修改时间 |
| p_log | GF_LogService | 日志服务，用于输出加载、热重载和校验日志 |

**返回值：** 参数全部非 null 时返回 `GF_OperationResult.ok()`，否则返回 `GF_OperationResult.fail()`。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| ERR_BAD_REQUEST | p_file_system 为 null |
| ERR_BAD_REQUEST | p_log 为 null |

---

### 注册

---

#### register_defs(p_type_key: String, p_defs: Dictionary) -> void
注册一个类型的全部定义。类型 key 如 `"items"`、`"buildings"`。定义以 Dictionary 传入，key 为 def id，value 为定义数据。如果类型之前已有数据，新数据会合并覆盖同 id 的条目。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_type_key | String | 类型 key，如 `"items"`、`"buildings"`、`"skills"` |
| p_defs | Dictionary | 定义字典，`{id -> 定义数据}` 结构 |

**示例：**
```gdscript
config.register_defs("items", {
    "wood": {"name": "木材", "stack_size": 100, "weight": 1.0},
    "stone": {"name": "石材", "stack_size": 50, "weight": 2.0},
})
```

---

#### register_def(p_type_key: String, p_id: String, p_def) -> void
注册单条定义。适用于运行时动态生成的 Def 或需要在代码中逐条注册的场景。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_type_key | String | 类型 key |
| p_id | String | 定义的唯一 ID |
| p_def | Variant | 定义数据，类型由 Game 层定义 |

---

### JSON 加载

---

#### load_json(p_type_key: String, p_path: String, p_hot_reload: bool = false) -> GF_OperationResult
从 JSON 文件加载定义。JSON 文件应为顶级 Dictionary，key 为 def id，value 为定义数据。加载成功后自动调用 `register_defs()` 注册。如果 `p_hot_reload = true`，自动对此文件启用热重载跟踪。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_type_key | String | 类型 key，如 `"buildings"` |
| p_path | String | JSON 文件路径，如 `"res://content/defs/buildings.json"` |
| p_hot_reload | bool | 是否启用热重载跟踪，默认 `false` |

**返回值：** 文件读取并解析成功时返回 `GF_OperationResult.ok()`，文件读取失败时透传 `GF_FileSystemService.read_json()` 的错误。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| (透传) | 文件路径无效或文件不存在 |
| (透传) | JSON 解析失败 |

**示例：**
```gdscript
# 普通加载
var result := config.load_json("buildings", "res://content/defs/buildings.json")
if result.is_fail():
    push_error("建筑定义加载失败: %s" % result.error.message)

# 开发期启用热重载
config.load_json("items", "res://content/defs/items.json", true)
```

---

### 查询

---

#### get_def(p_type_key: String, p_id: String) -> Variant
按类型和 ID 获取单条定义。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_type_key | String | 类型 key |
| p_id | String | 定义的 ID |

**返回值：** 对应的定义数据，类型或 ID 不存在时返回 `null`。

**示例：**
```gdscript
var item = config.get_def("items", "wood")
if item != null:
    print(item["name"])  # "木材"
```

---

#### get_all(p_type_key: String) -> Dictionary
获取某类型的所有定义。返回的是内部数据的引用副本，类型未注册时返回空 Dictionary。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_type_key | String | 类型 key |

**返回值：** `Dictionary`，`{id -> 定义数据}` 结构。

---

#### has_def(p_type_key: String, p_id: String) -> bool
检查指定类型中是否存在指定 ID 的定义。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_type_key | String | 类型 key |
| p_id | String | 定义的 ID |

**返回值：** `bool`，存在返回 `true`。

---

#### has_type(p_type_key: String) -> bool
检查指定类型是否已注册。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_type_key | String | 类型 key |

**返回值：** `bool`，类型已注册返回 `true`。

---

#### get_types() -> Array
获取所有已注册的类型 key。

**返回值：** `Array`，类型 key 数组。

---

#### count(p_type_key: String) -> int
获取某类型的定义数量。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_type_key | String | 类型 key |

**返回值：** `int`，定义数量。类型未注册时返回 `0`。

---

### 校验

---

#### register_validator(p_validator: GF_DefValidator) -> void
注册校验器。Game 层在加载 Def 后为每种类型注册一个或多个校验器。`validate_all()` 和 `validate_type()` 时会自动调用。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_validator | GF_DefValidator | 校验器实例，其 `type_key` 决定校验哪个类型 |

**示例：**
```gdscript
# 注册字段校验器
var item_validator := GF_DefValidator.new()
item_validator.type_key = "items"
config.register_validator(item_validator)

# 注册引用完整性校验器
var ref_v := GF_ReferenceValidator.new()
ref_v.type_key = "recipes"
ref_v.target_type = "items"
ref_v.source_field = "ingredient_ids"
ref_v.reference_label = "原料"
ref_v.set_config(config)
config.register_validator(ref_v)
```

---

#### validate_all() -> GF_OperationResult
校验所有已注册类型的所有定义。遍历每种类型，调用其所有注册的校验器，收集全部错误。错误列表在返回值的 `error.context["errors"]` 中。

**返回值：** 全部通过返回 `GF_OperationResult.ok()`，有错误返回 `ERR_VALIDATION` 失败结果，`error.context["errors"]` 为 `Array[String]`。

**示例：**
```gdscript
var result := config.validate_all()
if result.is_fail():
    var errors: Array = result.error.context["errors"]
    for err in errors:
        push_warning("配置校验错误: %s" % err)
```

---

#### validate_type(p_type_key: String) -> GF_OperationResult
校验指定类型的定义。热重载后自动调用。如果该类型没有注册校验器，直接返回 ok。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_type_key | String | 要校验的类型 key |

**返回值：** 同 `validate_all()`，`error.context["errors"]` 为 `Array[String]`。

---

### 热重载

---

#### enable_hot_reload(p_type_key: String, p_path: String) -> void
对已加载的 JSON 文件启用热重载跟踪。之后需在游戏主循环中周期性调用 `check_hot_reload()` 检测文件变化。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_type_key | String | 类型 key |
| p_path | String | 文件路径，与 `load_json()` 中使用的路径一致 |

---

#### check_hot_reload() -> Array[String]
检测所有热重载跟踪文件是否发生变化。如果有更新，自动重新加载 JSON 并调用 `validate_type()` 进行校验。校验警告通过日志输出，不阻断热重载流程。返回被重新加载的 type_key 列表，调用方据此决定是否需要刷新 UI 或重建游戏系统。

**返回值：** `Array[String]`，本次被重新加载的类型 key 列表。无变化时返回空数组。

**典型调用方式：** 在 Scheduler 或 `_process()` 中每 1-2 秒调用一次。

**示例：**
```gdscript
func _process(delta: float) -> void:
    _hot_reload_timer += delta
    if _hot_reload_timer > 2.0:
        _hot_reload_timer = 0.0
        var reloaded := config.check_hot_reload()
        if not reloaded.is_empty():
            # 配置已更新，刷新 UI 或重建游戏系统
            _on_config_reloaded(reloaded)
```

---

#### disable_hot_reload(p_path: String) -> void
停止对指定路径的热重载跟踪。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 文件路径 |

---

#### disable_all_hot_reloads() -> void
停止所有热重载跟踪。通常在退出开发模式或场景切换时调用。

---

#### is_hot_reload_enabled(p_path: String) -> bool
查询指定路径是否启用了热重载跟踪。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 文件路径 |

**返回值：** `bool`，已启用返回 `true`。

---

#### get_hot_reload_paths() -> Array[String]
获取所有热重载跟踪的文件路径。

**返回值：** `Array[String]`，路径数组。

---

## 相关类型

### GF_DefValidator

> 适用版本: 0.3.0 | 继承: GF_DefValidator -> RefCounted

#### 概述

Def 校验器抽象基类。Game 层为每种 Def 类型创建子类，在 `validate()` 中实现具体的字段检查逻辑。注册到 `GF_ConfigService` 后，`validate_all()` 和 `validate_type()` 时自动调用。

#### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| type_key | String | `""` | 此校验器对应的类型 key，如 `"items"`、`"buildings"` |

#### 公共方法

##### validate(p_defs: Dictionary) -> Array[String]
校验该类型的所有定义。子类必须重写此方法来实现具体的校验逻辑。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_defs | Dictionary | 该类型的所有定义，`{id -> 定义数据}` 结构 |

**返回值：** `Array[String]`，错误消息列表，空数组表示全部通过。

**示例：**
```gdscript
# 自定义校验器：检查物品的 weight 属性合法性
class ItemWeightValidator extends GF_DefValidator:
    func _init() -> void:
        type_key = "items"

    func validate(p_defs: Dictionary) -> Array[String]:
        var errors: Array[String] = []
        for id in p_defs.keys():
            var weight = p_defs[id].get("weight", -1.0)
            if weight < 0.0:
                errors.append("物品 '%s' 的 weight 不能为负数" % id)
        return errors
```

---

### GF_ReferenceValidator

> 适用版本: 0.3.0 | 继承: GF_ReferenceValidator -> GF_DefValidator

#### 概述

Def 间引用完整性校验器。检查 source_type 的 defs 中某个字段引用的 ID 是否在 target_type 中真实存在。支持三种引用格式：单 ID（String）、ID 数组（Array[String]）、Dict 数组中的嵌套引用（通过 `ref_subfield` 指定）。

#### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| type_key | String | `""` | 继承自 `GF_DefValidator`，此校验的源类型 key |
| target_type | String | `""` | 被引用的目标类型 key，如 `"items"`、`"buildings"` |
| source_field | String | `""` | 源定义中存放引用 ID 的字段名，支持点号分隔的嵌套路径（如 `"cost.item_id"`） |
| ref_subfield | String | `""` | 当 `source_field` 值是 Dict 数组时，指定每个 Dict 中哪个 key 是引用 ID |
| reference_label | String | `"引用"` | 引用的语义描述，用于错误消息格式化（如 `"原料"`、`"前置建筑"`） |

#### 公共方法

##### set_config(p_config: GF_ConfigService) -> void
注入 `GF_ConfigService`，用于跨类型查询目标定义是否存在。**必须在 `register_validator()` 之前调用**。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_config | GF_ConfigService | 配置服务实例 |

##### validate(p_defs: Dictionary) -> Array[String]
校验源类型中所有定义的引用完整性。遍历每个源定义，提取 `source_field` 中的引用 ID，检查是否在 `target_type` 中注册。

**返回值：** `Array[String]`，引用不存在的错误列表。

**示例：**
```gdscript
# 检查 recipes.json 中每道菜谱引用的 ingredients 是否都存在
var v := GF_ReferenceValidator.new()
v.type_key = "recipes"
v.target_type = "items"
v.source_field = "ingredient_ids"   # Array[String] 格式
v.reference_label = "原料"
v.set_config(config_service)
config_service.register_validator(v)

# 检查嵌套 Dict 数组中的引用
var v2 := GF_ReferenceValidator.new()
v2.type_key = "recipes"
v2.target_type = "items"
v2.source_field = "ingredients"     # Array[Dictionary] 格式
v2.ref_subfield = "item_id"         # 每个 Dict 中 item_id 字段是引用
v2.reference_label = "原料"
v2.set_config(config_service)
config_service.register_validator(v2)
```

---

## See Also

- [GF_FileSystemService](./gf_file_system_service.md) -- 文件系统服务，提供 JSON 读取和文件修改时间查询
- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) -- 模块生命周期基类
- [GF_LogService](./gf_log_service.md) -- 日志服务
