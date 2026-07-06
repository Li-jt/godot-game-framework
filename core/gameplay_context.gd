## GameplayContext（Framework 层）
## 游戏玩法子系统可用的窄上下文。World / Command / Simulation 通过此对象获取服务。
class_name GameplayContext
extends RefCounted

var log: LogService = null
var event_bus: EventBus = null
var app_flow: AppFlow = null
var scene_host: SceneHost = null
var input: InputService = null
var config: AppConfig = null
var threading: Variant = null
