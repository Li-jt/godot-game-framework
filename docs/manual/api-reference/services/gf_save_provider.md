# GF_SaveProvider

> 适用版本: 0.3.0 | 继承: GF_SaveProvider → RefCounted

## 概述

存档提供者的抽象基类。定义了存档读写的统一接口，Local / Remote / Hybrid Provider 均继承此类。GF_SaveService 通过此接口操作存档，不关心底层存储方式（本地文件、远程服务器或混合策略）。

适用场景：作为存档存储层的抽象，子类实现具体的读写逻辑。不应直接实例化此类 —— 它只是接口定义，所有方法默认返回"未实现"错误。Game 层通过 GF_SaveService 间接使用 Provider，不需要直接调用 Provider 方法。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|

此类无公开属性。子类按需添加内部成员。

## 公共方法

### save(p_slot: int, p_data: Dictionary, p_meta: GF_SaveMeta) -> GF_OperationResult

保存数据到指定槽位。基类默认返回 `fail(ERR_INTERNAL, "未实现")`，子类必须覆写。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |
| `p_data` | `Dictionary` | Game 层构建的序列化数据字典 |
| `p_meta` | `GF_SaveMeta` | 存档元数据 |

**返回值:** 子类实现返回 `Ok` 或对应错误。

---

### load(p_slot: int) -> GF_OperationResult

从指定槽位读取数据。基类默认返回 `fail(ERR_INTERNAL, "未实现")`，子类必须覆写。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |

**返回值:** 返回 `Ok`，其 `data` 为 Dictionary。失败返回对应错误。

---

### load_full(p_slot: int) -> GF_OperationResult

读取完整存档数据（包含 meta 和 data 的 wrapper 字典）。供 GF_SaveService 做版本检测和迁移。基类默认返回 `fail(ERR_INTERNAL, "未实现")`，子类必须覆写。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |

**返回值:** 返回 `Ok`，其 `data` 为 `{"meta": Dictionary, "data": Dictionary}` 格式的 wrapper。

---

### list_slots() -> GF_OperationResult

列出所有有效槽位的元数据。基类默认返回 `Ok` 空数组。

**返回值:** 返回 `Ok`，其 `data` 为 `Array[GF_SaveMeta]`，按 `slot_id` 升序排列。

---

### delete(p_slot: int) -> GF_OperationResult

删除指定槽位的存档。基类默认返回 `fail(ERR_INTERNAL, "未实现")`，子类必须覆写。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |

**返回值:** 删除成功返回 `Ok`，失败返回对应错误。

## See Also

- [GF_SaveService](./gf_save_service.md) -- 存档服务（通过此接口间接调用 Provider）
- [GF_SaveMeta](./gf_i_saveable.md) -- 存档元数据

---

# GF_LocalSaveProvider

> 适用版本: 0.3.0 | 继承: GF_LocalSaveProvider → GF_SaveProvider → RefCounted

## 概述

本地文件存档提供者。将存档数据以 JSON 格式存储到本地文件系统。文件命名规则：`{save_root}/slot_{id}.json`。

特性：
- **原子写入：** 先写 `.tmp` 临时文件，写入成功后再 rename 为 `.json`，防止写入中断导致存档损坏。
- **自动备份：** 每次保存前自动将现有 `.json` 备份为 `.bak`，加载时如果主文件损坏自动尝试从 `.bak` 恢复。
- **JSON 格式化：** 以缩进格式（`\t`）写入，便于人工查看和调试。

适用场景：单机游戏本地存档。不应在需要服务端存档或跨设备同步的场景使用（应使用 Remote 或 Hybrid Provider）。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|

此类无公开属性，内部通过 `configure()` 注入依赖。

## 公共方法

### configure(p_file_system: GF_FileSystemService, p_save_root: String, p_log: GF_LogService) -> GF_OperationResult

注入文件系统服务、存档根路径和日志服务。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_file_system` | `GF_FileSystemService` | 文件系统服务，用于文件读写和原子写入，不能为 null |
| `p_save_root` | `String` | 存档根目录路径，不能为空字符串 |
| `p_log` | `GF_LogService` | 日志服务，不能为 null |

**返回值:** 配置成功返回 `Ok`，任一参数无效返回 `fail(ERR_BAD_REQUEST)`。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_BAD_REQUEST` (400) | file_system 为 null、save_root 为空、或 log 为 null |

**示例:**

```gdscript
var local_provider := GF_LocalSaveProvider.new()
var result := local_provider.configure(file_system, "user://saves", log)
if result.is_fail():
    printerr("存档 Provider 配置失败: ", result.error.message)
```

---

### save(p_slot: int, p_data: Dictionary, p_meta: GF_SaveMeta) -> GF_OperationResult

保存存档到本地文件。覆写基类方法。

执行步骤：
1. 自动填充 `p_meta.save_time` 为当前系统时间（`YYYY-MM-DD HH:MM:SS` 格式）
2. 封装为 `{"meta": ..., "data": ...}` wrapper 字典
3. JSON 序列化（`\t` 缩进）
4. 备份旧文件（`slot_1.json` → `slot_1.json.bak`）
5. 原子写入（写 `.tmp` → rename 为 `.json`）

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |
| `p_data` | `Dictionary` | 要保存的数据 |
| `p_meta` | `GF_SaveMeta` | 存档元数据 |

**返回值:** 写入成功返回 `Ok`，JSON 序列化失败或文件写入失败返回对应错误。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_IO` (503) | JSON 序列化失败或文件写入失败 |

**示例:**

```gdscript
var meta := GF_SaveMeta.new()
meta.slot_id = 1
meta.summary = "第3年 春季"
meta.game_version = "1.0.0"
meta.play_time_seconds = 7200.0

var result := provider.save(1, game_data, meta)
if result.is_fail():
    log.error("Save", "本地存档失败: %s" % result.error.message)
```

---

### load(p_slot: int) -> GF_OperationResult

从本地文件读取存档。覆写基类方法。

先尝试读取主文件 `slot_{id}.json`，如果主文件损坏（JSON 解析失败）则自动尝试从 `.bak` 备份恢复。返回 wrapper 中的 `data` 字段。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |

**返回值:** 返回 `Ok`，其 `data` 为存档数据 Dictionary。文件不存在或格式无效返回对应错误。

**错误码:**

| 错误码 | 触发条件 |
|--------|---------|
| `ERR_IO` (503) | 主文件和备份文件均读取失败，或 wrapper 缺少 `data` 字段 |

---

### load_full(p_slot: int) -> GF_OperationResult

读取完整存档 wrapper（含 meta 和 data）。覆写基类方法。

与 `load()` 不同，此方法返回完整的 wrapper 字典 `{"meta": ..., "data": ...}`，供 GF_SaveService 提取 meta 中的 `save_version` 做版本检测和迁移。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |

**返回值:** 返回 `Ok`，其 `data` 为 `{"meta": Dictionary, "data": Dictionary}` wrapper。

---

### list_slots() -> GF_OperationResult

扫描存档目录，列出所有有效槽位。覆写基类方法。

扫描 `save_root` 下所有 `slot_*.json` 文件，读取每个文件的 meta 信息，构造 `GF_SaveMeta` 数组，按 `slot_id` 升序排列。损坏的文件仅打印警告跳过，不影响其他槽位的读取。

**返回值:** 返回 `Ok`，其 `data` 为 `Array[GF_SaveMeta]`。

**示例:**

```gdscript
var result := provider.list_slots()
if result.is_ok():
    var slots: Array = result.data
    for meta in slots:
        print("槽位 %d: %s | %s | 游戏时长: %.1fh" % [
            meta.slot_id, meta.summary, meta.save_time,
            meta.play_time_seconds / 3600.0
        ])
```

---

### delete(p_slot: int) -> GF_OperationResult

删除指定槽位的存档文件。覆写基类方法。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_slot` | `int` | 存档槽位编号 |

**返回值:** 删除成功返回 `Ok`，文件删除失败返回对应错误。

**示例:**

```gdscript
var result := provider.delete(1)
if result.is_fail():
    log.error("Save", "删除存档失败: %s" % result.error.message)
```

## 文件结构

存档文件的 JSON 结构：

```json
{
    "meta": {
        "slot_id": 1,
        "save_time": "2026-07-31 14:30:00",
        "save_version": 1,
        "game_version": "1.0.0",
        "play_time_seconds": 7200.0,
        "summary": "第3年 春季"
    },
    "data": {
        "map": { ... },
        "inventory": { ... },
        "world.entities": { ... }
    }
}
```

## 备份与恢复

- **自动备份：** 每次 `save()` 调用前，如果目标文件 `slot_{id}.json` 已存在，`GF_FileSystemService.backup_file()` 会将其复制为 `slot_{id}.json.bak`。
- **自动恢复：** `load()` 和 `load_full()` 在主文件读取失败时，自动尝试读取 `slot_{id}.json.bak`。成功恢复后将备份内容写回主文件，确保后续读取正常。
- **损坏处理：** 如果主文件和备份文件均不可读，返回 `ERR_IO` 错误。

## See Also

- [GF_SaveProvider](#gf_saveprovider) -- 抽象基类接口定义
- [GF_SaveService](./gf_save_service.md) -- 存档服务
- [GF_SaveMeta](./gf_i_saveable.md) -- 存档元数据
- [GF_FileSystemService](../engine/gf_file_system_service.md) -- 文件系统服务
