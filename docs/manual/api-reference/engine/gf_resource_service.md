# GF_ResourceService

> 适用版本: 0.3.0 | 继承: GF_ResourceService -> GF_ModuleLifecycle

## 概述

项目级统一资源读取服务。提供带缓存、资源分组和释放策略的资源加载入口，禁止 Game 层直接使用 `load()` / `preload()`。通过分组机制支持场景切换时批量释放关卡资源，同时保留 UI 常驻资源。**不适用于**运行时动态生成资源的场景（如程序化纹理）——仅管理从磁盘加载的 `Resource` 对象。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| GROUP_UI_COMMON | StringName | `&"ui_common"` | UI 通用资源组（常驻，不随场景切换释放） |
| GROUP_GAMEPLAY | StringName | `&"gameplay"` | 游戏玩法资源组（默认加载分组） |
| GROUP_LEVEL_01 | StringName | `&"level_01"` | 关卡 1 资源组 |
| GROUP_LEVEL_02 | StringName | `&"level_02"` | 关卡 2 资源组 |
| GROUP_AUDIO | StringName | `&"audio"` | 音频资源组（常驻） |

## 枚举

### ReleasePolicy

| 值 | 描述 |
|----|------|
| `LRU_ONLY` | 仅 LRU 回收（默认）。缓存超过 `MAX_UNCACHED` 时淘汰最久未使用的条目 |
| `ON_SCENE_EXIT` | 场景退出时释放。切换场景时外部调用 `release_group()` 清空对应组 |

## 公共方法

### configure(p_asset_loading: GF_AssetLoadingService, p_log: GF_LogService) -> GF_OperationResult

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_asset_loading | GF_AssetLoadingService | 底层资源加载服务，执行实际的 `load()` 调用 |
| p_log | GF_LogService | 日志服务 |

**返回值:** 配置成功返回 `OperationResult.ok()`，任一参数为 `null` 返回 `ERR_BAD_REQUEST`。

**示例:**

```gdscript
var result := resource_service.configure(asset_loading, log)
if result.is_fail():
    push_error("ResourceService 配置失败: %s" % result.error.message)
```

---

### load_scene(p_path: String, p_group: StringName = GROUP_GAMEPLAY) -> GF_OperationResult

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 场景资源路径，如 `"res://scenes/level_01.tscn"` |
| p_group | StringName | 资源分组，默认 `GROUP_GAMEPLAY` |

**返回值:** `OperationResult` — 成功时 `data` 为 `PackedScene`，失败时包含错误信息。

---

### load_texture(p_path: String, p_group: StringName = GROUP_GAMEPLAY) -> GF_OperationResult

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 纹理资源路径 |
| p_group | StringName | 资源分组，默认 `GROUP_GAMEPLAY` |

**返回值:** `OperationResult` — 成功时 `data` 为 `Texture2D`。

---

### load_audio(p_path: String, p_group: StringName = GROUP_AUDIO) -> GF_OperationResult

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 音频资源路径 |
| p_group | StringName | 资源分组，默认 `GROUP_AUDIO` |

**返回值:** `OperationResult` — 成功时 `data` 为 `AudioStream`。

---

### load_resource(p_path: String, p_group: StringName = GROUP_GAMEPLAY) -> GF_OperationResult

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 通用资源路径 |
| p_group | StringName | 资源分组，默认 `GROUP_GAMEPLAY` |

**返回值:** `OperationResult` — 成功时 `data` 为 `Resource`。用于加载 scene/texture/audio 之外的资源类型（如 `Theme`、`ShaderMaterial`）。

---

### release_group(p_group: StringName) -> void

释放指定资源组中的所有缓存条目。场景切换时调用，清空关卡专属资源。**保留** `GROUP_UI_COMMON`、`GROUP_GAMEPLAY`、`GROUP_AUDIO` 组资源（这些组不会被释放）。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_group | StringName | 要释放的资源组 |

**示例:**

```gdscript
# 离开关卡 1，进入关卡 2
resource_service.release_group(GF_ResourceService.GROUP_LEVEL_01)
resource_service.load_scene("res://scenes/level_02.tscn", GF_ResourceService.GROUP_LEVEL_02)
```

---

### set_release_policy(p_policy: ReleasePolicy) -> void

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_policy | ReleasePolicy | 释放策略。`LRU_ONLY` 仅按容量淘汰，`ON_SCENE_EXIT` 配合 `release_group()` 使用 |

---

### clear_cache() -> void

清空所有缓存条目和 LRU 顺序记录。通常在应用重启或强制刷新时调用。

---

### evict(p_path: String) -> void

从缓存中逐出单个资源条目。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 缓存键（与加载时使用的路径一致） |

---

### cache_size() -> int

**返回值:** `int` — 当前缓存的资源条目数量。

## 缓存行为

- **LRU 淘汰**：缓存容量上限 `MAX_UNCACHED = 200`。新资源加载时若缓存已满，淘汰最久未使用的条目。
- **缓存命中**：已加载的资源再次请求时，直接返回缓存的 `Resource` 实例，不触发磁盘 I/O。命中时该条目的 LRU 顺序更新为最新。
- **分组隔离**：资源按分组标签存储，`release_group()` 只影响指定组的条目。

## See Also

- `GF_AssetLoadingService` — 底层资源加载执行者
- `GF_ModuleLifecycle` — 服务生命周期基类
