## EcsSystemDescriptor — 系统元数据。
## 描述系统名称、分组、tick 频率、依赖关系，供调度器和调试器使用。
class_name EcsSystemDescriptor
extends RefCounted

## 系统显示名称（用于调试和性能统计）
var system_name: String = ""
## 所属分组名称
var group_name: String = ""
## tick 间隔（秒），0 表示每帧执行
var tick_interval: float = 0.0
## 必须在哪些系统之前执行
var before_systems: Array[String] = []
## 必须在哪些系统之后执行
var after_systems: Array[String] = []
## 优先级，越小越先执行
var priority: int = 0
## 系统注册者（如 "game" 或 "mod:fishing"），用于卸载时批量清理
var owner: String = ""
