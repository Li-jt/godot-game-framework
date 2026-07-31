# 加载游戏配置数据

## 场景描述

游戏需要大量的配置数据——物品属性、建筑参数、配方公式、NPC 对话、任务条件。框架通过 `GF_ConfigService` 提供统一的配置加载、查询和校验机制，支持 JSON 文件、热重载和跨类型引用检查。

本章覆盖：注册和查询配置、JSON 加载、自定义校验、引用完整性检查、热重载。

---

## 最小示例

```gdscript
# 1. 准备 JSON 文件
# res://content/defs/items.json
# {
#   "wood": {"name": "木材", "stack": 100, "weight": 1.0},
#   "stone": {"name": "石料", "stack": 50, "weight": 2.0}
# }

# 2. 加载
var result := config_service.load_json("items", "res://content/defs/items.json")
if result.is_fail():
    _log.error("Config", "加载失败: %s" % result.error.message)

# 3. 查询
var wood := config_service.get_def("items", "wood")
print(wood["name"])  # "木材"
print(wood["stack"]) # 100
```

---

## 逐步解释

### 第一步：理解 type_key + id 双层索引

配置数据按两层索引组织：

```
_config_service._defs = {
    "items": {
        "wood":   { "name": "木材", ... },
        "stone":  { "name": "石料", ... },
        "iron":   { "name": "铁矿", ... },
    },
    "buildings": {
        "house":  { "name": "房屋", "cost": {...} },
        "farm":   { "name": "农场", "cost": {...} },
    },
    "recipes": {
        "iron_sword": { "name": "铁剑", "ingredients": [...], "result": "iron_sword" },
    },
}
```

- `type_key`（第一层）：配置类型，如 `"items"`、`"buildings"`、`"recipes"`
- `id`（第二层）：该类型下的唯一标识，如 `"wood"`、`"house"`

### 第二步：加载 JSON 配置

```gdscript
# 基本加载
config_service.load_json("items", "res://content/defs/items.json")

# 启用热重载
config_service.load_json("items", "res://content/defs/items.json", true)
```

JSON 文件格式要求：
- 顶层必须是 `Dictionary`（对象），key 为 def id，value 为 def 数据
- 不支持顶层数组
- 嵌套字段无限制

```json
// res://content/defs/recipes.json — ✅ 正确格式
{
  "iron_sword": {
    "name": "铁剑",
    "ingredient_ids": ["iron_ingot", "iron_ingot", "wood"],
    "result_item_id": "iron_sword",
    "craft_time": 5.0
  },
  "health_potion": {
    "name": "生命药水",
    "ingredient_ids": ["red_herb", "water_bottle"],
    "result_item_id": "health_potion",
    "craft_time": 2.0
  }
}
```

### 第三步：手动注册配置（不从 JSON 加载）

```gdscript
# 注册整批
config_service.register_defs("items", {
    "wood": {"name": "木材", "stack": 100},
    "stone": {"name": "石料", "stack": 50},
})

# 注册单个
config_service.register_def("items", "diamond", {"name": "钻石", "stack": 10})
```

### 第四步：查询配置

```gdscript
# 按 ID 获取单条（不存在返回 null）
var item := config_service.get_def("items", "wood")

# 获取某类型全部（返回 Dictionary）
var all_items: Dictionary = config_service.get_all("items")

# 检查是否存在
if config_service.has_def("items", "wood"):
    pass

# 检查类型是否已注册
if config_service.has_type("buildings"):
    pass

# 获取所有类型
var types: Array = config_service.get_types()  # ["items", "buildings", "recipes"]

# 获取某类型的条目数
var count := config_service.count("items")
```

### 第五步：自定义 DefValidator

框架提供 `GF_DefValidator` 抽象基类，Game 层继承它来定义校验规则：

```gdscript
class_name ItemDefValidator
extends GF_DefValidator


func _init() -> void:
    type_key = "items"


func validate(p_defs: Dictionary) -> Array[String]:
    var errors: Array[String] = []

    for id in p_defs.keys():
        var def: Dictionary = p_defs[id]

        # 必填字段
        if not def.has("name") or str(def["name"]).is_empty():
            errors.append("%s: 缺少 name 字段" % id)

        # 范围校验
        var stack: int = def.get("stack", 0)
        if stack < 1 or stack > 999:
            errors.append("%s: stack 必须在 1-999 之间，当前 %d" % [id, stack])

        var weight: float = def.get("weight", 0.0)
        if weight < 0:
            errors.append("%s: weight 不能为负数" % id)

        # 枚举校验
        var rarity: String = def.get("rarity", "")
        var valid_rarities := ["common", "uncommon", "rare", "epic", "legendary"]
        if not rarity.is_empty() and not rarity in valid_rarities:
            errors.append("%s: 未知的 rarity 值 '%s'" % [id, rarity])

    return errors


# 注册校验器
config_service.register_validator(ItemDefValidator.new())

# 执行校验
var result := config_service.validate_all()
if result.is_fail():
    for err in result.error.context.get("errors", []):
        _log.warning("Config", err)
```

### 第六步：ReferenceValidator 跨引用检查

`GF_ReferenceValidator` 检查一个类型中引用的 ID 在目标类型中是否真实存在：

```gdscript
# 检查 recipes 的 ingredient_ids 引用的 ID 在 items 中是否存在
var ref_validator := GF_ReferenceValidator.new()
ref_validator.type_key = "recipes"       # 源类型
ref_validator.target_type = "items"      # 被引用的目标类型
ref_validator.source_field = "ingredient_ids"  # 源字段（支持嵌套路径如 "cost.items"）
ref_validator.reference_label = "原料"    # 用于错误消息
ref_validator.set_config(config_service)  # 注入 ConfigService

config_service.register_validator(ref_validator)
```

还支持数组中的嵌套引用：

```gdscript
# 如果 recipes 的 ingredients 是 [{id: "iron", count: 2}, ...]
var nested_validator := GF_ReferenceValidator.new()
nested_validator.type_key = "recipes"
nested_validator.target_type = "items"
nested_validator.source_field = "ingredients"
nested_validator.ref_subfield = "id"   # 指定每个 Dict 中哪个 key 是引用 ID
nested_validator.reference_label = "原料"
nested_validator.set_config(config_service)
```

### 第七步：热重载

```gdscript
# 加载时启用热重载
config_service.load_json("items", "res://content/defs/items.json", true)

# 每 1-2 秒在主循环中检查文件变化
var reloaded := config_service.check_hot_reload()
if not reloaded.is_empty():
    for type_key in reloaded:
        _log.info("Config", "热重载: %s" % type_key)
        # 根据重载的类型刷新 UI 或重建系统
        _on_config_reloaded(type_key)

# 停止单个文件的热重载
config_service.disable_hot_reload("res://content/defs/items.json")

# 查询热重载状态
if config_service.is_hot_reload_enabled(path):
    pass
```

热重载工作原理：
1. `enable_hot_reload` 记录文件的 `last_modified` 时间戳
2. `check_hot_reload()` 比较当前 `get_modified_time` 与记录的 `last_modified`
3. 如果文件被修改，自动重新加载 JSON 并调用 `validate_type()`
4. 返回被重载的 type_key 列表

---

## 完整示例：物品配置 + 配方配置 + 引用校验

```gdscript
# ---- items.json ----
# {
#   "iron_ore":  {"name": "铁矿石", "stack": 100, "weight": 2.0, "rarity": "common"},
#   "iron_ingot": {"name": "铁锭", "stack": 100, "weight": 3.0, "rarity": "common"},
#   "iron_sword": {"name": "铁剑", "stack": 1, "weight": 5.0, "rarity": "uncommon"},
#   "wood":       {"name": "木材", "stack": 100, "weight": 1.0, "rarity": "common"},
# }

# ---- recipes.json ----
# {
#   "smelt_iron": {
#     "name": "冶炼铁矿",
#     "ingredient_ids": ["iron_ore", "iron_ore", "iron_ore"],
#     "result_item_id": "iron_ingot",
#     "craft_time": 3.0
#   },
#   "craft_sword": {
#     "name": "锻造铁剑",
#     "ingredient_ids": ["iron_ingot", "iron_ingot", "wood"],
#     "result_item_id": "iron_sword",
#     "craft_time": 5.0
#   }
# }

# ---- 加载和校验 ----

func _load_game_config(config_service: GF_ConfigService) -> void:
    # 加载配置
    var items_result := config_service.load_json("items", "res://content/defs/items.json")
    if items_result.is_fail():
        _log.error("Config", "物品配置加载失败")
        return

    var recipes_result := config_service.load_json("recipes", "res://content/defs/recipes.json")
    if recipes_result.is_fail():
        _log.error("Config", "配方配置加载失败")
        return

    # 注册校验器
    config_service.register_validator(_create_item_validator())

    # 注册引用校验器
    var ingredient_ref := GF_ReferenceValidator.new()
    ingredient_ref.type_key = "recipes"
    ingredient_ref.target_type = "items"
    ingredient_ref.source_field = "ingredient_ids"
    ingredient_ref.reference_label = "原料"
    ingredient_ref.set_config(config_service)
    config_service.register_validator(ingredient_ref)

    var result_ref := GF_ReferenceValidator.new()
    result_ref.type_key = "recipes"
    result_ref.target_type = "items"
    result_ref.source_field = "result_item_id"
    result_ref.reference_label = "产出物品"
    result_ref.set_config(config_service)
    config_service.register_validator(result_ref)

    # 校验所有配置
    var validation := config_service.validate_all()
    if validation.is_fail():
        var errors: Array = validation.error.context.get("errors", [])
        for err in errors:
            _log.error("Config", "校验失败: %s" % err)
        return

    _log.info("Config", "配置加载完成: 物品 %d 条, 配方 %d 条" % [
        config_service.count("items"), config_service.count("recipes")
    ])


# ---- 开发期热重载 ----

func _enable_dev_hot_reload(config_service: GF_ConfigService) -> void:
    config_service.enable_hot_reload("items", "res://content/defs/items.json")
    config_service.enable_hot_reload("recipes", "res://content/defs/recipes.json")


# 在 Scheduler 或 _process 中每 2 秒调用
func _check_config_changes() -> void:
    var reloaded := config_service.check_hot_reload()
    for type_key in reloaded:
        match type_key:
            "items":
                _rebuild_item_catalog()
            "recipes":
                _rebuild_recipe_book()
        _log.info("Config", "热重载完成: %s" % type_key)
```

---

## 常见变体

### 变体 1：手动注册代码生成的配置

```gdscript
# 不需要 JSON 文件，直接在代码中定义
config_service.register_defs("difficulty", {
    "easy":   {"enemy_hp_mult": 0.5, "loot_mult": 2.0},
    "normal": {"enemy_hp_mult": 1.0, "loot_mult": 1.0},
    "hard":   {"enemy_hp_mult": 2.0, "loot_mult": 0.5},
})
```

### 变体 2：嵌套字段的引用校验

```gdscript
# 假设 building def 的 cost 字段包含物品引用
# { "house": { "cost": { "items": {"wood": 50, "stone": 20} } } }

var cost_ref := GF_ReferenceValidator.new()
cost_ref.type_key = "buildings"
cost_ref.target_type = "items"
cost_ref.source_field = "cost.items"  # 点号分隔的嵌套路径
cost_ref.reference_label = "建造成本物品"
cost_ref.set_config(config_service)
```

---

## 错误码

| 方法 | 可能的错误码 | 说明 |
|------|------------|------|
| `configure(fs, log)` | `ERR_BAD_REQUEST` | 任一参数为 null |
| `load_json(type_key, path)` | 取决于 FileSystemService | JSON 文件读取失败 |
| `validate_all()` | `ERR_VALIDATION` | 校验失败，错误列表在 `error.context["errors"]` |
| `validate_type(type_key)` | `ERR_VALIDATION` | 指定类型的校验失败 |

---

## See Also

- [模块间事件通信](./event-communication.md) -- 配置变更事件通知
- [日志与调试](./logging-and-debugging.md) -- 配置相关的日志输出
