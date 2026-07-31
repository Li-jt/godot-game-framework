# GF_AudioRuntime

> 适用版本: 0.3.0 | 继承: GF_AudioRuntime → Node

## 概述

音频运行时宿主，管理音频播放节点和音频通道。直接操作 Godot `AudioStreamPlayer` 节点进行播放、停止、音量控制和静音。`GF_AudioService` 在此基础上提供高层接口（资源加载、淡入淡出等）。

**适用场景**：需要直接控制音频播放的游戏逻辑；作为 `GF_AudioService` 的底层引擎。

**不适用场景**：不要绕过 `GF_AudioService` 直接使用此类（除非你明确需要底层控制）；复杂的音频混合和 DSP 处理应使用 Godot Audio Bus 系统。

## 枚举

### Channel

| 值 | 描述 |
|----|------|
| `MASTER` | 总控通道 |
| `BGM` | 背景音乐通道（循环播放，单播放器，切换时自动停止上一首） |
| `SFX` | 音效通道（一次性播放，池化 8 个播放器支持同时播放，轮询复用） |
| `UI` | UI 交互音效通道 |
| `VOICE` | 语音/对话通道 |

## 常量

| 常量 | 类型 | 值 | 描述 |
|------|------|-----|------|
| `MAX_SFX_PLAYERS` | `int` | `8` | SFX 播放器池大小，支持同时播放最多 8 个音效 |

## 公共方法

### is_runtime_ready() → bool

检查音频播放器是否已初始化完毕。在 `_ready()` 中自动调用 `_setup()` 创建播放器节点。

**返回值：** `true` 表示 BGM/UI/VOICE 单播放器和 SFX 池已全部创建。

**示例：**

```gdscript
if audio.is_runtime_ready():
    audio.play_bgm(main_theme)
else:
    # 等待 _ready() 完成后再播放
    await get_tree().process_frame
    audio.play_bgm(main_theme)
```

---

### play_bgm(p_stream: AudioStream) → void

播放背景音乐。BGM 通道为单播放器设计，播放新曲目时自动停止并替换当前正在播放的 BGM。BGM 播放器设置为自动循环。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_stream` | `AudioStream` | 要播放的音频流。如果为 null 则静默（不播放任何声音） |

**示例：**

```gdscript
# 播放战斗背景音乐
audio.play_bgm(battle_bgm_stream)

# 切换场景时切换 BGM
audio.play_bgm(village_bgm_stream)  # 自动停止 battle_bgm
```

---

### play_sfx(p_stream: AudioStream) → void

播放一次性音效。SFX 通道维护一个 8 个播放器的池，轮询（round-robin）分配。如果轮到的播放器仍在播放之前的音效，会先停止它再播放新音效。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_stream` | `AudioStream` | 要播放的音效流 |

**示例：**

```gdscript
# 播放射击音效
audio.play_sfx(shoot_stream)

# 连续快速播放多个音效（最多 8 个同时播放）
audio.play_sfx(explosion_1)
audio.play_sfx(explosion_2)
audio.play_sfx(footstep)
# 第 9 个会复用第 1 个播放器，停止第 1 个音效
```

---

### play_ui(p_stream: AudioStream) → void

播放 UI 交互音效，如按钮点击、窗口打开等。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_stream` | `AudioStream` | 要播放的 UI 音效流 |

**示例：**

```gdscript
audio.play_ui(button_click_stream)
audio.play_ui(window_open_stream)
```

---

### play_voice(p_stream: AudioStream) → void

播放语音或对话音频。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_stream` | `AudioStream` | 要播放的语音流 |

**示例：**

```gdscript
audio.play_voice(narrator_line_01)
```

---

### stop(p_channel: Channel) → void

停止指定通道的播放。对 SFX 通道，停止池中所有 8 个播放器。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_channel` | `Channel` | 要停止的通道枚举值 |

**示例：**

```gdscript
# 停止背景音乐
audio.stop(GF_AudioRuntime.Channel.BGM)

# 停止所有音效
audio.stop(GF_AudioRuntime.Channel.SFX)

# 暂停菜单时停止所有声音
for ch in [GF_AudioRuntime.Channel.BGM, GF_AudioRuntime.Channel.SFX]:
    audio.stop(ch)
```

---

### set_volume(p_channel: Channel, p_volume: float) → void

设置通道音量。内部将线性音量（0.0-1.0）转换为分贝值（dB）。对 SFX 通道，同时设置池中所有 8 个播放器的音量。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_channel` | `Channel` | 目标通道 |
| `p_volume` | `float` | 音量值，范围 0.0（静音）到 1.0（最大）。超出范围会被 `clampf` 截断 |

**示例：**

```gdscript
# 设置音效音量为 80%
audio.set_volume(GF_AudioRuntime.Channel.SFX, 0.8)

# 设置 BGM 音量为 50%
audio.set_volume(GF_AudioRuntime.Channel.BGM, 0.5)

# 超出范围的值会被截断
audio.set_volume(GF_AudioRuntime.Channel.UI, 1.5)  # 实际为 1.0
audio.set_volume(GF_AudioRuntime.Channel.UI, -0.5)  # 实际为 0.0
```

---

### get_volume(p_channel: Channel) → float

获取通道的当前音量设置。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_channel` | `Channel` | 目标通道 |

**返回值：** 线性音量值（0.0-1.0），默认返回 1.0。

**示例：**

```gdscript
var bgm_vol := audio.get_volume(GF_AudioRuntime.Channel.BGM)
print("BGM 音量: %.0f%%" % (bgm_vol * 100))
```

---

### mute(p_channel: Channel) → void

将指定通道静音。静音后音量设为 -80 dB（实际听不见）。静音不影响 `_volumes` 中存储的音量值，取消静音后会恢复。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_channel` | `Channel` | 目标通道 |

**示例：**

```gdscript
# 游戏切到后台时静音
audio.mute(GF_AudioRuntime.Channel.BGM)
audio.mute(GF_AudioRuntime.Channel.SFX)

# 或静音所有通道
for ch in [GF_AudioRuntime.Channel.BGM, GF_AudioRuntime.Channel.SFX, GF_AudioRuntime.Channel.UI, GF_AudioRuntime.Channel.VOICE]:
    audio.mute(ch)
```

---

### unmute(p_channel: Channel) → void

取消指定通道的静音。恢复为之前 `set_volume()` 设置的音量。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_channel` | `Channel` | 目标通道 |

**示例：**

```gdscript
# 游戏恢复前台时取消静音
audio.unmute(GF_AudioRuntime.Channel.BGM)
audio.unmute(GF_AudioRuntime.Channel.SFX)
```

---

### is_muted(p_channel: Channel) → bool

检查指定通道是否处于静音状态。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_channel` | `Channel` | 目标通道 |

**返回值：** `true` 表示该通道已静音；`false` 表示未静音（默认值）。

**示例：**

```gdscript
if audio.is_muted(GF_AudioRuntime.Channel.BGM):
    audio.unmute(GF_AudioRuntime.Channel.BGM)
```

---

## 信号

GF_AudioRuntime 继承 `Node` 的所有信号，不定义额外的自定义信号。

## 兼容性说明

Godot 4.7 中 `AudioStreamPlayer2D/3D` 的 `area_mask` 默认值从 1 变为 0。`_apply_player_defaults()` 在新创建的播放器上检测 `area_mask` 属性（鸭子类型），若存在则设为 1，避免静音问题。

## See Also

- [GF_AudioService](../audio/gf_audio_service.md) — 音频服务高层接口（资源加载、AudioCue、淡入淡出）
- [GF_AudioCue](../audio/gf_audio_cue.md) — 音频提示定义
- [AudioStreamPlayer (Godot 文档)](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html) — Godot 原生音频播放器
