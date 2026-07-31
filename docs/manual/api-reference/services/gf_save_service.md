# GF_SaveService

> 适用版本: 0.3.0 | 继承: GF_SaveService → GF_ModuleLifecycle → RefCounted

## 概述

存档服务的核心引擎。管理槽位读写、版本迁移链调度、Provider 路由分发，以及 GF_ISaveable 的收集、注册和自动存档恢复。

适用场景：游戏存档的完整生命周期管理。不应直接操作 GF_SaveProvider 或文件系统来读写存档 —— 始终通过 GF_SaveService 统一入口。

### GF_ISaveable 注册路径

GF_SaveService 提供三种 GF_ISaveable 注册路径，各司其职：

| 路径 | 方法 | 适用场景 |
|------|------|---------|
| 场景树扫描 | `collect_from_node(root)` | 场景树中的 Node-based GF_ISaveable，场景构建完成后一次性扫描 |
| 增量注册 | `child_entering_tree` 信号 | `collect_from_node` 之后新挂入场景树的节点 |
| 手动注册 | `register_saveable()` | 纯数据 GF_ISaveable（RefCounted）、全局 Service、Mod 注册的 saveable |

### 存档流程

```
存盘: Game 层注册 GF_ISaveable → save_all() 自动调用 on_save() 打包 → Provider 写入文件
读档: Provider 读取磁盘 → 版本迁移 → load_and_restore() 按优先级自动分发 on_load()
```

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `state` | `GF_CoreLifecycleState.State` | `UNINITIALIZED` | 生命周期状态（继承自 GF_ModuleLifecycle） |
| `module_name` | `String` | `""` | 模块名称，用于日志和错误追踪（继承自 GF_ModuleLifecycle） |

## 生命周期方法

继承自 GF_ModuleLifecycle，详见 [GF_ModuleLifecycle](../core/gf_module_lifecycle.md)。

| 方法 | 描述 |
|------|------|
| `init_module() -> GF_OperationResult` | 初始化模块 |
| `dispose_module() -> GF_OperationResult` | 释放模块资源 |
| `finalize_configuration() -> GF_OperationResult` | 标记配置完成 |
| `is_ready() -> bool` | 模块是否已就绪 |
| `is_failed() -> bool` | 模块是否失败 |
| `is_initialized() -> bool` | 模块是否已初始化 |

## 公共方法

### configure(p_provider: GF_SaveProvider, p_path_resolver: GF_PathResolver, p_log: GF_LogService) -> GF_OperationResult

注入依赖并完成配置。必须在 `init_module()` 之后、`finalize_configuration()` 之前调用。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_provider` | `GF_SaveProvider` | 存档提供者（本地/远程/混合），不能为 null |
| `p_path_resolver` | `GF_PathResolver` | 路径解析器，不能为 null |
| `p_log` | `GF_LogService` | 日志服务，不能为 null |

**返回值:** 配置成功返回 `Ok`，任一参数为 null 返回 `fail(ERR_BAD_REQUEST)`。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_BAD_REQUEST` (400) | provider、path_resolver 或 log 为 null |

**示例:**

```gdscript
var save_service := GF_SaveService.new()
save_service.module_name = "SaveService"
save_service.init_module()

var result := save_service.configure(provider, path_resolver, log)
if result.is_fail():
    log.error("Save", "存档服务配置失败: %s" % result.error.message)
    return

save_service.finalize_configuration()
```

---

### register_migrator(p_migrator: GF_SaveVersionMigrator) -> void

注册存档版本迁移器。Game 层为每个版本跨度创建具体的 GF_SaveVersionMigrator 子类并注册到此。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_migrator` | `GF_SaveVersionMigrator` | 迁移器实例，其 `from_version` 作为注册 key |

**示例:**

```gdscript
# 注册 v1 → v2 迁移器
save_service.register_migrator(V1ToV2Migrator.new())

# 注册 v2 → v3 迁移器
save_service.register_migrator(V2ToV3Migrator.new())
```

---

### register_saveable(p_saveable) -> void

注册 GF_ISaveable 实例。采用鸭子类型，接受任何实现了 `save_key()` / `on_save()` / `on_load()` 的对象。调用 `p_saveable.save_key()` 获取模块 key 作为内部 map 的键。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_saveable` | `Variant` | 实现了 save_key/on_save/on_load 的对象（鸭子类型） |

**示例:**

```gdscript
# 注册 RefCounted 类型的 saveable
var map_data := MapData.new()
save_service.register_saveable(map_data)

# 注册 Node 类型的 saveable
save_service.register_saveable($PlayerInventory)

# save_key() 返回空字符串时打印警告并跳过
```

---

### unregister_saveable(p_key: String) -> void

按 key 注销单个 GF_ISaveable。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_key` | `String` | save_key() 返回的模块唯一键名 |

**示例:**

```gdscript
save_service.unregister_saveable("inventory")
```

---

### collect_from_node(p_root: Node) -> int

从节点树递归扫描所有实现了 GF_ISaveable 接口的后代节点并注册。完成后自动连接 `p_root` 的 `child_entering_tree` / `child_exiting_tree` 信号，实现后续节点的增量注册，无需重复调用本方法。

**调用时机：** 场景树构建完成后（如 `GF_WorldRoot._on_world_setup()` 中）。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_root` | `Node` | 扫描的根节点，为 null 时返回 0 |

**返回值:** 收集到的 GF_ISaveable 数量（int）。

**示例:**

```gdscript
# 场景加载后收集所有 world 级 saveable
var count := save_service.collect_from_node(world_root)
log.info("Save", "从 %s 收集到 %d 个 saveable" % [world_root.name, count])
```

---

### unregister_by_prefix(p_prefix: String) -> int

按 key 前缀批量注销。典型场景：世界切换时清除旧世界的 `"world."` 前缀数据，或 Mod 卸载时清除 `"mod:xxx:"` 前缀数据。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_prefix` | `String` | key 前缀，如 `"world."` 或 `"mod:combat:"` |

**返回值:** 被注销的数量（int）。

**示例:**

```gdscript
# 世界切换时清除旧世界数据
var removed := save_service.unregister_by_prefix("world.")
log.info("Save", "已注销 %d 个世界级 saveable" % removed)
```

---

### on_world_switch(p_old_root: Node, p_new_root: Node, p_prefix: String = "world.") -> void

世界切换时的统一入口。执行三个步骤：
1. 断开旧 root 的 `child_entering_tree` / `child_exiting_tree` 信号连接
2. 按 `p_prefix` 批量注销旧世界的 saveable
3. 扫描新 root 并注册新世界的 saveable

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_old_root` | `Node` | 旧世界根节点，传 null 表示首次加载（跳过注销步骤） |
| `p_new_root` | `Node` | 新世界根节点，为 null 时跳过扫描 |
| `p_prefix` | `String` | 世界级 saveable 的 key 前缀，默认 `"world."` |

**示例:**

```gdscript
# 切换到新世界
save_service.on_world_switch(old_world, new_world)

# 首次加载（无旧世界）
save_service.on_world_switch(null, initial_world)

# 自定义前缀
save_service.on_world_switch(old_root, new_root, "dungeon.")
```

---

### collect_from(p_saveables: Array) -> GF_OperationResult

从数组中批量注册 saveable。鸭子类型：数组中每个元素只要实现了 `save_key` / `on_save` / `on_load` 即可，不需要继承特定基类。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_saveables` | `Array` | saveable 对象数组 |

**返回值:** 所有对象注册成功返回 `Ok`。如果存在 save_key() 返回空字符串的对象，返回 `fail(ERR_BAD_REQUEST)` 并列出所有错误对象。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_BAD_REQUEST` (400) | 数组中存在 save_key() 返回空字符串的对象 |

**示例:**

```gdscript
var mod_saveables: Array = [mod_data, mod_config, mod_state]
var result := save_service.collect_from(mod_saveables)
if result.is_fail():
    log.error("Save", "Mod saveable 注册失败: %s" % result.error.message)
```

---

### unregister_saveables_by_owner(p_owner: String) -> int

按 owner 前缀注销 saveable。与 `unregister_by_prefix` 类似，但面向 owner 语义。实现上按 save_key 前缀匹配。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_owner` | `String` | owner 标识符，用作 save_key 前缀匹配，如 `"mod:combat:"` |

**返回值:** 被注销的数量（int）。

**示例:**

```gdscript
# 卸载某个 Mod 的所有 saveable
var removed := save_service.unregister_saveables_by_owner("mod:combat:")
log.info("Save", "已注销 combat mod 的 %d 个 saveable" % removed)
```

---

### save_all(p_slot: int, p_meta: GF_SaveMeta) -> GF_OperationResult

保存所有已注册的 GF_ISaveable 模块。内部调用各 saveable 的 `on_save()` 构建完整存档字典，然后通过 `save()` 写入 Provider。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |
| `p_meta` | `GF_SaveMeta` | 存档元数据（摘要、游戏版本、游戏时长等） |

**返回值:** 保存成功返回 `Ok`，失败返回 Provider 的错误。

**示例:**

```gdscript
var meta := GF_SaveMeta.new()
meta.summary = "第3年 春季"
meta.game_version = "1.2.0"
meta.play_time_seconds = 3600.0

var result := save_service.save_all(1, meta)
if result.is_fail():
    log.error("Save", "存盘失败: %s" % result.error.message)
```

---

### save(p_slot: int, p_data: Dictionary, p_meta: GF_SaveMeta) -> GF_OperationResult

保存指定的存档数据。内部自动将 `p_meta.save_version` 标记为当前 `GF_SaveVersion.CURRENT`，然后委托给 Provider 写入。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |
| `p_data` | `Dictionary` | 要保存的数据字典 |
| `p_meta` | `GF_SaveMeta` | 存档元数据 |

**返回值:** 保存成功返回 `Ok`，失败返回 Provider 的错误。

**示例:**

```gdscript
var data := {"settings": {"volume": 0.8, "language": "zh"}}
var meta := GF_SaveMeta.new()
var result := save_service.save(0, data, meta)
```

---

### load_and_restore(p_slot: int) -> GF_OperationResult

读取存档并自动恢复到所有已注册的 GF_ISaveable 模块。等价于 `load_slot()` + 按 `restore_priority()` 排序后依次调用 `on_load()`。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |

**返回值:** 读取并恢复成功返回 `Ok`。读取失败或迁移失败返回对应错误。

**示例:**

```gdscript
var result := save_service.load_and_restore(1)
if result.is_fail():
    log.error("Save", "读档失败: %s" % result.error.message)
```

---

### load_slot(p_slot: int) -> GF_OperationResult

读取原始存档数据（不自动恢复）。自动检测存档版本并执行迁移链，将数据升级到 `GF_SaveVersion.CURRENT`。如果存档版本高于当前版本，拒绝加载并提示用户升级游戏。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |

**返回值:** 返回 `Ok`，其 `data` 为迁移后的 Dictionary。失败返回对应错误。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_MIGRATION` (506) | 存档版本高于当前版本（需升级游戏） |
| `ERR_MIGRATION` (506) | 缺少某个版本的迁移器 |
| `ERR_IO` | Provider 读取失败 |

**示例:**

```gdscript
var result := save_service.load_slot(1)
if result.is_fail():
    if result.error.code == GF_OperationResult.ERR_MIGRATION:
        log.error("Save", "存档不兼容: %s" % result.error.message)
    return

var raw_data: Dictionary = result.data
# 可以手动检查/处理数据后再决定是否恢复
```

---

### list_slots() -> GF_OperationResult

列出所有有效存档槽位的元数据。委托给 Provider。

**返回值:** 返回 `Ok`，其 `data` 为 `Array[GF_SaveMeta]`。

**示例:**

```gdscript
var result := save_service.list_slots()
if result.is_ok():
    var slots: Array = result.data
    for meta in slots:
        print("槽位 %d: %s (v%d)" % [meta.slot_id, meta.summary, meta.save_version])
```

---

### delete_slot(p_slot: int) -> GF_OperationResult

删除指定槽位的存档。委托给 Provider。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |

**返回值:** 删除成功返回 `Ok`。

**示例:**

```gdscript
var result := save_service.delete_slot(1)
if result.is_fail():
    log.error("Save", "删除存档失败: %s" % result.error.message)
```

## 内部实现要点

- **鸭子类型检查：** `register_saveable` / `collect_from_node` / `collect_from` 均通过 `_is_saveable()` 检查对象是否实现了 `save_key` / `on_save` / `on_load` 三个方法，而非 `is GF_ISaveable` 类型检查。这是因为 Node 和 RefCounted 是并行继承链，`is` 检查不适用于跨链场景。
- **恢复优先级排序：** `_restore_save_data()` 在分发 `on_load()` 前将已注册的 saveable 按 `restore_priority()` 升序排列，确保地形（低值）先于建筑（中值）、先于 UI 状态（高值）恢复。
- **未注册 key 降级：** 存档中存在但当前未注册的 key 不会导致报错，仅打印警告跳过。这允许 Game 层在版本升级后废弃某些模块而不破坏旧存档兼容性。
- **迁移链：** `load_slot()` 按 `from_version` 查找迁移器，循环执行直到版本升至 `CURRENT`，缺少中间迁移器时报 `ERR_MIGRATION`。

## See Also

- [GF_SaveProvider](./gf_save_provider.md) -- 存档提供者抽象基类
- [GF_ISaveable](./gf_i_saveable.md) -- 可存档模块基类
- [GF_SaveVersionMigrator](./gf_i_saveable.md) -- 存档版本迁移器
- [GF_SaveMeta](./gf_i_saveable.md) -- 存档元数据
- [GF_EntityRegistry](./gf_i_saveable.md) -- 实体类型注册表
- [GF_OperationResult](../core/gf_operation_result.md) -- 统一操作结果类型
