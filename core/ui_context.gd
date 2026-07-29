## GF_UiContext（Framework 层）
## UI 子系统上下文。UI 面板通过 panel.ctx 获取所有所需服务。
## 由框架层（GF_ServiceInstallerImpl 或 GF_GameServices）构建并注入。
class_name GF_UiContext
extends RefCounted

## 日志服务
var log: GF_LogService = null
## UI 管理服务
var ui: GF_UIService = null
## 输入服务
var input: GF_InputService = null
## 事件总线
var event_bus: GF_EventBus = null
## 场景宿主
var scene_host: GF_SceneHost = null
## 本地化服务
var loc: GF_LocalizationService = null
## 存档服务
var save_service: GF_SaveService = null
## 游戏配置定义服务
var config_service: GF_ConfigService = null
## 应用运行配置
var config: GF_AppConfig = null
## 应用流程状态机
var app_flow: GF_AppFlow = null
## 调试服务
var debug: GF_DebugService = null
## 音频服务
var audio: GF_AudioService = null
