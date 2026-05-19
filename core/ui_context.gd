## UiContext（Framework 层）
## UI 子系统上下文。UI 面板通过 panel.ctx 获取所有所需服务。
## 由框架层（ServiceInstallerImpl 或 GameServices）构建并注入。
class_name UiContext
extends RefCounted

## 日志服务
var log: LogService = null
## UI 管理服务
var ui: UIService = null
## 输入服务
var input: InputService = null
## 事件总线
var event_bus: EventBus = null
## 场景宿主
var scene_host: SceneHost = null
## 本地化服务
var loc: LocalizationService = null
## 存档服务
var save_service: SaveService = null
## 游戏配置定义服务
var config_service: ConfigService = null
## 应用运行配置
var config: AppConfig = null
## 应用流程状态机
var app_flow: AppFlow = null
## 调试服务
var debug: DebugService = null
## 音频服务
var audio: AudioService = null
