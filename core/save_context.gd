## SaveContext（Framework 层）
## 存档子系统可用的窄上下文。Save/Load 流程通过此对象获取服务。
class_name SaveContext
extends RefCounted

var log: LogService = null
var save_service: SaveService = null
var config_service: ConfigService = null
var config: AppConfig = null
