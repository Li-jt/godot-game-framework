# GF_AudioService

> 适用版本: 0.3.0 | 继承: GF_AudioService -> GF_ModuleLifecycle

## 概述

游戏音频服务，提供 AudioCue 体系 + AudioBus 总线 + 淡入淡出的高层音频管理。内部组合 `GF_AudioRuntime`（底层播放）、`GF_ResourceService`（音频资源加载）和 `GF_LogService`（日志输出）。游戏层通过 `register_cue()` 注册音频提示定义，通过 `play_cue()` / `stop_cue()` 触发播放，通过 Bus 管理接口控制各通道的音量、静音和淡入淡出。

**使用场景：**

- 在 Application 层初始化后配置音频服务并注册所有游戏音频 cue
- 播放 UI 交互音效（`play_cue("ui.click")`）
- 控制 BGM 音量淡入淡出（`fade_bus_to("BGM", -20.0, 2.0)`）
- 场景切换时停止或切换背景音乐
- 暂停菜单中静音所有音效

**不适用场景：**

- 不要绕过此服务直接调用 `GF_AudioRuntime` 播放音频（会导致 cue 统计和 Bus 管理被绕过）
- 不要在不需要音频管理的简单原型中使用（直接用 `AudioStreamPlayer` 即可）

## 属性

此服务不暴露公共成员属性。所有状态通过方法管理。

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| （无公共属性） | | | 通过方法访问所有功能 |

## 公共方法

### 生命周期

---

#### configure(p_runtime: GF_AudioRuntime, p_resource: GF_ResourceService, p_log: GF_LogService) -> GF_OperationResult
注入音频运行时、资源服务和日志服务的依赖。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_runtime | GF_AudioRuntime | 底层音频播放运行时，管理 AudioStreamPlayer 节点和通道 |
| p_resource | GF_ResourceService | 资源服务，用于通过 path 加载 AudioStream |
| p_log | GF_LogService | 日志服务，用于输出警告和错误信息 |

**返回值：** 参数全部非 null 时返回 `GF_OperationResult.ok()`，否则返回 `GF_OperationResult.fail()`。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| ERR_BAD_REQUEST | p_runtime 为 null |
| ERR_BAD_REQUEST | p_resource 为 null |
| ERR_BAD_REQUEST | p_log 为 null |

**示例：**
```gdscript
var audio := GF_AudioService.new()
var runtime := GF_AudioRuntime.new()
add_child(runtime)
var result := audio.configure(runtime, resource_service, log_service)
if result.is_fail():
    push_error("音频服务配置失败: %s" % result.error.message)
    return
```

---

### AudioCue 管理

---

#### register_cue(p_def: GF_AudioCueDef) -> void
注册单个音频 cue 定义。cue 按 `id` 索引，重复注册同 id 的 cue 会覆盖之前的定义。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_def | GF_AudioCueDef | 音频 cue 定义，包含 id、path、channel、cooldown 等配置 |

---

#### register_cues(p_defs: Array[GF_AudioCueDef]) -> void
批量注册音频 cue 定义。内部遍历数组调用 `register_cue()`，完成后输出日志。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_defs | Array[GF_AudioCueDef] | 音频 cue 定义数组 |

**示例：**
```gdscript
audio.register_cues([
    GF_AudioCueDef.new("ui.click", "res://audio/sfx/ui_click.ogg"),
    GF_AudioCueDef.new("bgm.menu", "res://audio/bgm/menu.ogg", GF_AudioRuntime.Channel.BGM),
    GF_AudioCueDef.new("sfx.explosion", "res://audio/sfx/explosion.ogg", GF_AudioRuntime.Channel.SFX, 0.8, 100, 3),
])
```

---

#### play_cue(p_id: String) -> void
播放指定 id 的音频 cue。播放前会先检查 cooldown（冷却时间）和 max_instances（最大同时播放实例数），通过检查后通过 `GF_ResourceService` 加载音频资源，加载成功后在对应 channel 上播放。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_id | String | cue 的 id，必须已通过 `register_cue()` 注册 |

**行为细节：**
- 未注册的 id：输出警告日志，不播放
- cooldown 限制：如果距上次播放时间不足 `cooldown_ms`，跳过本次调用
- max_instances 限制：如果当前活跃播放数已达到 `max_instances`（> 0 时），跳过本次调用
- 播放成功后递增活跃计数并记录时间戳

**示例：**
```gdscript
audio.play_cue("ui.click")
audio.play_cue("sfx.explosion")
audio.play_cue("bgm.menu")
```

---

#### stop_cue(p_id: String) -> void
停止指定 cue 所在 channel 的所有播放。内部调用 `GF_AudioRuntime.stop()` 停止对应通道，并重置该 cue 的活跃实例计数为 0。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_id | String | cue 的 id |

**注意：** 该方法停止的是整个 channel 的播放，而非仅停止该 cue 的某个特定实例。对于 BGM/UI/Voice 通道（单播放器），直接停止播放器；对于 SFX 通道（多播放器池），停止所有 SFX 播放器。

---

### Bus 管理

---

#### register_bus(p_name: String, p_channel: int) -> GF_OperationResult
注册自定义音频 Bus。初始化时已自动创建 Master、BGM、SFX、UI、Voice 五个默认 Bus。此方法用于扩展额外的 Bus（如 "Ambient"、"Dialogue" 等）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_name | String | Bus 名称，全局唯一 |
| p_channel | int | 映射的 channel，使用 `GF_AudioRuntime.Channel` 枚举值 |

**返回值：** 创建成功返回 `GF_OperationResult.ok()`，Bus 名已存在返回 `GF_OperationResult.fail()`。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| ERR_CONFLICT | 同名 Bus 已存在 |

**示例：**
```gdscript
audio.register_bus("Ambient", GF_AudioRuntime.Channel.BGM)
audio.register_bus("Dialogue", GF_AudioRuntime.Channel.VOICE)
```

---

#### get_bus(p_name: String) -> Variant
获取指定名称的 `GF_AudioBus` 实例。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_name | String | Bus 名称 |

**返回值：** 对应的 `GF_AudioBus` 实例，不存在时返回 `null`。

---

#### get_bus_names() -> Array[String]
获取所有已注册 Bus 的名称列表。

**返回值：** `Array[String]`，Bus 名称数组。

---

#### has_bus(p_name: String) -> bool
检查指定名称的 Bus 是否存在。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_name | String | Bus 名称 |

**返回值：** `bool`，存在返回 `true`。

---

### Bus 音量

---

#### set_bus_volume_db(p_bus_name: String, p_db: float) -> void
设置 Bus 音量（dB）。即时生效，同步停止该 Bus 上正在进行的淡入淡出。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_bus_name | String | Bus 名称 |
| p_db | float | 目标音量，单位 dB（0.0 = 原始音量，-80.0 = 静音级别） |

**注意：** Bus 不存在时输出警告日志，不抛错。

---

#### get_bus_volume_db(p_bus_name: String) -> float
获取 Bus 当前实际音量（dB）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_bus_name | String | Bus 名称 |

**返回值：** `float`，当前音量 dB 值。Bus 不存在时返回 `0.0`。

---

### Bus 淡入淡出

---

#### fade_bus_to(p_bus_name: String, p_target_db: float, p_duration: float) -> void
平滑过渡 Bus 音量到目标值。从当前音量线性插值到 `p_target_db`，持续 `p_duration` 秒。需在主循环中调用 `tick()` 驱动插值。如果 `p_duration <= 0.0`，等价于 `set_bus_volume_db()` 即时生效。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_bus_name | String | Bus 名称 |
| p_target_db | float | 目标音量（dB） |
| p_duration | float | 过渡时长（秒），必须 > 0 |

**示例：**
```gdscript
# 2 秒内将 BGM 音量从当前值淡出到 -20 dB
audio.fade_bus_to("BGM", -20.0, 2.0)

# 3 秒内将 BGM 淡入回 0 dB
audio.fade_bus_to("BGM", 0.0, 3.0)
```

---

#### cancel_fade(p_bus_name: String) -> void
取消指定 Bus 上正在进行的淡入淡出。当前音量保持在被取消时的值。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_bus_name | String | Bus 名称 |

---

#### is_bus_fading(p_bus_name: String) -> bool
查询指定 Bus 是否正在进行淡入淡出。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_bus_name | String | Bus 名称 |

**返回值：** `bool`，正在淡入淡出返回 `true`。Bus 不存在时返回 `false`。

---

### Bus 静音

---

#### mute_bus(p_bus_name: String) -> void
静音指定 Bus。将输出音量强制设为 -80 dB，同时保留 `current_volume_db` 用于取消静音后恢复。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_bus_name | String | Bus 名称 |

**注意：** Bus 不存在时输出警告日志。

---

#### unmute_bus(p_bus_name: String) -> void
取消指定 Bus 的静音，恢复到静音前的 `current_volume_db`。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_bus_name | String | Bus 名称 |

**注意：** Bus 不存在时输出警告日志。

---

#### is_bus_muted(p_bus_name: String) -> bool
查询指定 Bus 是否处于静音状态。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_bus_name | String | Bus 名称 |

**返回值：** `bool`，静音返回 `true`。Bus 不存在时返回 `false`。

---

### Bus 播放控制

---

#### stop_bus(p_bus_name: String) -> void
停止指定 Bus 对应 channel 上的所有播放。对于 BGM/UI/Voice，停止对应播放器；对于 SFX，停止整个 SFX 播放器池。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_bus_name | String | Bus 名称 |

**注意：** Bus 不存在或 runtime 为 null 时静默跳过。

---

### 帧驱动

---

#### tick(p_delta: float) -> void
驱动所有 Bus 的淡入淡出插值。必须在游戏主循环中每帧调用（通过 Scheduler 注册或在 `_process()` 中调用）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_delta | float | 本帧的 delta 时间（秒） |

**行为细节：**
- 遍历所有 Bus，对 `fade_duration > 0` 的 Bus 推进 `fade_elapsed`
- 线性插值：`current_volume_db = lerp(fade_start_db, target_volume_db, t)`，其中 `t = clamp(elapsed / duration, 0, 1)`
- 淡入淡出完成后，将 `fade_duration` 重置为 0
- 每次插值后调用 `_apply_bus_volume()` 将音量写入底层 `GF_AudioRuntime`

**示例：**
```gdscript
func _process(delta: float) -> void:
    audio.tick(delta)
```

---

## 相关类型

### GF_AudioCueDef

> 适用版本: 0.3.0 | 继承: GF_AudioCueDef -> RefCounted

#### 概述

音频提示定义，描述一个游戏音频 cue 的资源和播放策略。Game 层负责创建和配置，`GF_AudioService` 负责消费。

#### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| id | String | `""` | cue 唯一标识，如 `"ui.click"`、`"bgm.battle"` |
| path | String | `""` | 音频资源路径，如 `"res://audio/sfx/click.ogg"` |
| channel | int | `GF_AudioRuntime.Channel.SFX` | 播放通道，使用 `GF_AudioRuntime.Channel` 枚举 |
| volume | float | `1.0` | 播放音量倍数（0.0 - 1.0），应用于 `AudioStreamPlayer.volume_db` |
| cooldown_ms | int | `0` | 同 cue 最小播放间隔（毫秒），0 表示无冷却限制 |
| max_instances | int | `0` | 同时最大播放实例数，0 表示无限制 |
| loop | bool | `false` | 是否循环播放（仅对 BGM 等单播放器通道有效） |

---

### GF_AudioBus

> 适用版本: 0.3.0 | 继承: GF_AudioBus -> RefCounted

#### 概述

音频总线，每个 Bus 对应一个 `GF_AudioRuntime.Channel`，拥有独立的音量（dB）、静音和淡入淡出状态。`GF_AudioService.tick()` 驱动淡入淡出插值，`GF_AudioService` 的 Bus 管理方法通过操作 Bus 实例来控制音频输出。

#### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| bus_name | String | `""` | Bus 名称，如 `"Master"`、`"BGM"`、`"Voice"` |
| channel | int | `0` | 映射的 `GF_AudioRuntime.Channel` 整数值 |
| current_volume_db | float | `0.0` | 当前实际音量（dB），由 `tick()` 在淡入淡出期间更新 |
| target_volume_db | float | `0.0` | 目标音量（dB） |
| muted | bool | `false` | 是否静音 |
| fade_start_db | float | `0.0` | 淡入淡出起始音量（dB） |
| fade_duration | float | `0.0` | 淡入淡出总时长（秒），0 表示无进行中的淡入淡出 |
| fade_elapsed | float | `0.0` | 淡入淡出已流逝时间（秒） |

#### 公共方法

##### is_fading() -> bool
判断淡入淡出是否正在进行中。

**返回值：** `bool`，当 `fade_duration > 0` 且 `fade_elapsed < fade_duration` 时返回 `true`。

##### fade_progress() -> float
获取淡入淡出进度。

**返回值：** `float`，范围 0.0（刚开始）到 1.0（已完成）。无淡入淡出时返回 1.0。

---

## See Also

- [GF_AudioRuntime](../engine/gf_audio_runtime.md) -- 底层音频运行时，管理 AudioStreamPlayer 节点和播放通道
- [GF_ResourceService](./gf_resource_service.md) -- 资源服务，AudioCue 的音频文件通过此服务加载
- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) -- 模块生命周期基类
