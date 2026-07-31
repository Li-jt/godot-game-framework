# 播放音效和背景音乐

## 场景描述

游戏需要播放音效（点击、射击、脚步）和背景音乐，并允许玩家调节音量。框架通过 AudioCue 体系管理音频资源，通过 AudioBus 总线控制音量、静音和淡入淡出。

本章覆盖：定义 AudioCue、注册和播放、5 种 Channel、Bus 音量控制、淡入淡出、完整 BGM + UI 音效示例。

---

## 最小示例

```gdscript
# 1. 定义 Cue
var click_cue := GF_AudioCueDef.new()
click_cue.id = "ui.click"
click_cue.path = "res://content/audio/sfx/ui_click.ogg"
click_cue.channel = GF_AudioRuntime.Channel.UI

# 2. 注册
audio_service.register_cue(click_cue)

# 3. 播放
audio_service.play_cue("ui.click")
```

---

## 逐步解释

### 第一步：理解 AudioCue 体系

`GF_AudioCueDef` 定义一条音频提示（cue）的全部属性：

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `id` | `String` | `""` | 唯一标识 |
| `path` | `String` | `""` | 音频资源路径 |
| `channel` | `Channel` | `SFX` | 所属频道 |
| `volume` | `float` | `1.0` | 播放音量乘数 |
| `cooldown_ms` | `int` | `0` | 同 cue 最小间隔（毫秒），0 = 无限制 |
| `max_instances` | `int` | `0` | 同时最大播放实例数，0 = 无限制 |
| `loop` | `bool` | `false` | 是否循环播放 |

### 第二步：5 种 Channel

音频播放路由到 5 个独立频道，对应不同的 AudioBus：

| Channel | 说明 | 典型用途 |
|---------|------|---------|
| `MASTER` | 主输出 | 总音量控制 |
| `BGM` | 背景音乐 | 背景音乐、环境音 |
| `SFX` | 音效 | 射击、爆炸、脚步 |
| `UI` | 界面音效 | 按钮点击、弹窗、提示音 |
| `VOICE` | 语音 | 角色对话、旁白 |

```gdscript
var bgm_cue := GF_AudioCueDef.new()
bgm_cue.id = "bgm.town"
bgm_cue.path = "res://content/audio/bgm/town_theme.ogg"
bgm_cue.channel = GF_AudioRuntime.Channel.BGM
bgm_cue.loop = true

var sfx_cue := GF_AudioCueDef.new()
sfx_cue.id = "sfx.explosion"
sfx_cue.path = "res://content/audio/sfx/explosion.ogg"
sfx_cue.channel = GF_AudioRuntime.Channel.SFX
sfx_cue.cooldown_ms = 100  # 100ms 冷却，防止连续爆炸音效重叠
sfx_cue.max_instances = 5  # 最多同时 5 个爆炸音效
```

### 第三步：注册和播放

```gdscript
# 单个注册
audio_service.register_cue(bgm_cue)

# 批量注册
audio_service.register_cues([click_cue, hover_cue, confirm_cue])

# 播放
audio_service.play_cue("bgm.town")

# 停止
audio_service.stop_cue("bgm.town")
```

`play_cue` 内部流程：
1. 检查 cue 是否注册（未注册则 log warning 并 return）
2. 检查冷却（`cooldown_ms`）
3. 检查最大实例数（`max_instances`）
4. 通过 ResourceService 加载音频资源
5. 根据 `channel` 路由到对应的 `_runtime.play_bgm/sfx/ui/voice`

### 第四步：Bus 管理

初始化时框架自动创建 5 个默认 Bus：Master、BGM、SFX、UI、Voice。

```gdscript
# 自定义 Bus（扩展默认的 5 个）
audio_service.register_bus("Ambient", GF_AudioRuntime.Channel.BGM)

# 检查 Bus 是否存在
if audio_service.has_bus("SFX"):
    pass

# 获取所有 Bus 名称
var names := audio_service.get_bus_names()  # ["Master", "BGM", "SFX", "UI", "Voice"]
```

### 第五步：音量控制

```gdscript
# 设置音量（dB 值）
audio_service.set_bus_volume_db("BGM", -6.0)   # 降低 6dB
audio_service.set_bus_volume_db("SFX", 0.0)    # 默认音量
audio_service.set_bus_volume_db("Master", 3.0)  # 提升 3dB

# 获取当前音量
var vol := audio_service.get_bus_volume_db("BGM")

# 静音
audio_service.mute_bus("SFX")
audio_service.unmute_bus("SFX")

# 检查是否静音
var is_muted := audio_service.is_bus_muted("SFX")

# 停止 Bus 上的所有播放
audio_service.stop_bus("BGM")
```

### 第六步：淡入淡出

```gdscript
# 在 2 秒内淡入到目标音量
audio_service.fade_bus_to("BGM", -20.0, 2.0)

# 检查是否正在淡入淡出
if audio_service.is_bus_fading("BGM"):
    print("淡入淡出中...")

# 取消淡入淡出（保持当前音量）
audio_service.cancel_fade("BGM")
```

淡入淡出需要每帧调用 `tick(delta)` 来驱动插值：

```gdscript
# 在 Scheduler 或 _process 中每帧调用
func _process(delta: float) -> void:
    audio_service.tick(delta)
```

`GF_AudioBus` 内部通过 `fade_start_db`、`target_volume_db`、`fade_duration`、`fade_elapsed` 四个字段做 lerp 插值。

---

## 完整示例：BGM 播放 + UI 点击音效 + 音量滑块

```gdscript
# ---- 定义 Cue（在 Game 层引导脚本中） ----

func _register_audio_cues(audio_service: GF_AudioService) -> void:
    # BGM
    var town_bgm := GF_AudioCueDef.new()
    town_bgm.id = "bgm.town"
    town_bgm.path = "res://content/audio/bgm/town_theme.ogg"
    town_bgm.channel = GF_AudioRuntime.Channel.BGM
    town_bgm.loop = true

    var battle_bgm := GF_AudioCueDef.new()
    battle_bgm.id = "bgm.battle"
    battle_bgm.path = "res://content/audio/bgm/battle_theme.ogg"
    battle_bgm.channel = GF_AudioRuntime.Channel.BGM
    battle_bgm.loop = true

    # UI 音效
    var click_sfx := GF_AudioCueDef.new()
    click_sfx.id = "ui.click"
    click_sfx.path = "res://content/audio/sfx/ui_click.ogg"
    click_sfx.channel = GF_AudioRuntime.Channel.UI
    click_sfx.cooldown_ms = 50  # 防止快速连击导致音效重叠

    var hover_sfx := GF_AudioCueDef.new()
    hover_sfx.id = "ui.hover"
    hover_sfx.path = "res://content/audio/sfx/ui_hover.ogg"
    hover_sfx.channel = GF_AudioRuntime.Channel.UI

    # 游戏音效
    var shoot_sfx := GF_AudioCueDef.new()
    shoot_sfx.id = "sfx.shoot"
    shoot_sfx.path = "res://content/audio/sfx/laser_shoot.ogg"
    shoot_sfx.channel = GF_AudioRuntime.Channel.SFX
    shoot_sfx.max_instances = 3  # 最多同时 3 个射击音效

    audio_service.register_cues([town_bgm, battle_bgm, click_sfx, hover_sfx, shoot_sfx])


# ---- 播放 BGM ----

func play_town_bgm() -> void:
    audio_service.stop_bus("BGM")  # 先停掉旧的
    audio_service.play_cue("bgm.town")


func transition_to_battle_bgm() -> void:
    # 淡出当前 BGM，1.5 秒后切换到战斗 BGM
    audio_service.fade_bus_to("BGM", -80.0, 1.5)
    await get_tree().create_timer(1.5).timeout
    audio_service.stop_bus("BGM")
    audio_service.set_bus_volume_db("BGM", 0.0)
    audio_service.play_cue("bgm.battle")


# ---- 按钮点击 ----

func _on_button_pressed() -> void:
    audio_service.play_cue("ui.click")
    # 处理按钮逻辑...


func _on_button_mouse_entered() -> void:
    audio_service.play_cue("ui.hover")


# ---- 音量设置面板 ----

class_name AudioSettingsPanel
extends GF_UIPanel


func _on_open(_p_data: Dictionary) -> void:
    var audio := ctx.audio as GF_AudioService

    # 主音量
    $MasterSlider.value = audio.get_bus_volume_db("Master")
    $MasterSlider.value_changed.connect(func(v: float):
        audio.set_bus_volume_db("Master", v)
    )

    # BGM 音量
    $BgmSlider.value = audio.get_bus_volume_db("BGM")
    $BgmSlider.value_changed.connect(func(v: float):
        audio.set_bus_volume_db("BGM", v)
    )

    # SFX 音量
    $SfxSlider.value = audio.get_bus_volume_db("SFX")
    $SfxSlider.value_changed.connect(func(v: float):
        audio.set_bus_volume_db("SFX", v)
    )

    # 静音开关
    $MuteButton.toggled.connect(func(pressed: bool):
        if pressed:
            audio.mute_bus("Master")
        else:
            audio.unmute_bus("Master")
    )


# ---- 主循环中驱动淡入淡出 ----
# 在 GF_AppBootstrap 或 Scheduler 中：
func _on_tick(delta: float) -> void:
    audio_service.tick(delta)
```

---

## 常见变体

### 变体 1：冷却控制（防止音效 spam）

```gdscript
var footstep_cue := GF_AudioCueDef.new()
footstep_cue.id = "sfx.footstep"
footstep_cue.path = "res://content/audio/sfx/footstep.ogg"
footstep_cue.channel = GF_AudioRuntime.Channel.SFX
footstep_cue.cooldown_ms = 300  # 最快每 300ms 播放一次
```

### 变体 2：限制实例数（防止重叠爆炸）

```gdscript
var explosion_cue := GF_AudioCueDef.new()
explosion_cue.id = "sfx.explosion"
explosion_cue.path = "res://content/audio/sfx/explosion.ogg"
explosion_cue.channel = GF_AudioRuntime.Channel.SFX
explosion_cue.max_instances = 5  # 同时最多 5 个
```

### 变体 3：场景切换时的音频过渡

```gdscript
func on_enter_battle() -> void:
    # 淡出城镇 BGM
    audio_service.fade_bus_to("BGM", -80.0, 1.0)
    await get_tree().create_timer(1.0).timeout

    # 停止并立即播放战斗 BGM（淡入）
    audio_service.stop_bus("BGM")
    audio_service.set_bus_volume_db("BGM", -80.0)
    audio_service.play_cue("bgm.battle")
    audio_service.fade_bus_to("BGM", 0.0, 0.5)
```

---

## 错误码

| 方法 | 错误码 | 说明 |
|------|--------|------|
| `configure(runtime, resource, log)` | `ERR_BAD_REQUEST` | 任一参数为 null |
| `register_bus(name, channel)` | `ERR_CONFLICT` | Bus 名称已存在 |

`play_cue` 和 `stop_cue` 不返回 `GF_OperationResult`。当 cue 未注册时，`play_cue` 会记录 warning 日志并 return。

---

## See Also

- [创建和管理 UI 面板](./create-ui-panels.md) -- 音量设置面板
- [日志与调试](./logging-and-debugging.md) -- 音频相关的日志输出
