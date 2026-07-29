## GF_GameplayContext（Framework 层）
## 游戏玩法子系统可用的窄上下文。World / Command / Simulation 通过此对象获取服务。
class_name GF_GameplayContext
extends RefCounted

var log: GF_LogService = null
var event_bus: GF_EventBus = null
var app_flow: GF_AppFlow = null
var scene_host: GF_SceneHost = null
var input: GF_InputService = null
var config: GF_AppConfig = null
var threading: Variant = null
