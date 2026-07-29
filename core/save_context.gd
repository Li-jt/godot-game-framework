## GF_SaveContext（Framework 层）
## 存档子系统可用的窄上下文。Save/Load 流程通过此对象获取服务。
class_name GF_SaveContext
extends RefCounted

var log: GF_LogService = null
var save_service: GF_SaveService = null
var config_service: GF_ConfigService = null
var config: GF_AppConfig = null
