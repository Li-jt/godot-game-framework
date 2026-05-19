## AudioCueDef
## 音频提示定义。描述一个游戏音频 cue 的资源和播放策略。
## Game 层配置，AudioService 消费。
class_name AudioCueDef
extends RefCounted

var id: String = ""
var path: String = ""
var channel: AudioRuntime.Channel = AudioRuntime.Channel.SFX
var volume: float = 1.0
## 同 cue 最小间隔（毫秒），0 = 无限制
var cooldown_ms: int = 0
## 同时最大播放实例数，0 = 无限制
var max_instances: int = 0
var loop: bool = false
