## LogLevel
## 日志级别枚举，按严重程度递升。
## 设置某个级别后，只输出该级别及更高级别的日志。
class_name LogLevel
extends RefCounted

enum Level {
	DEBUG = 0,   # 开发调试信息，生产环境通常关闭
	INFO = 1,    # 关键流程节点（启动、切换、保存等）
	WARNING = 2, # 非致命异常、降级、fallback
	ERROR = 3    # 错误、操作失败
}

## 级别转显示名称
static func level_name(p_level: Level) -> String:
	match p_level:
		Level.DEBUG: return "DEBUG"
		Level.INFO: return "INFO"
		Level.WARNING: return "WARN"
		Level.ERROR: return "ERROR"
		_: return "UNKNOWN"

## 从字符串解析级别（不区分大小写）
static func parse(p_text: String) -> Level:
	match p_text.to_upper():
		"DEBUG": return Level.DEBUG
		"INFO": return Level.INFO
		"WARNING", "WARN": return Level.WARNING
		"ERROR": return Level.ERROR
		_: return Level.DEBUG
