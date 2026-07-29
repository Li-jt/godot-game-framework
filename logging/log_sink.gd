## GF_LogSink
## 日志 Sink 抽象基类。注册到 GF_LogService 后接收所有日志事件。
class_name GF_LogSink
extends RefCounted

var sink_name: String = ""
## 最低接收级别
var min_level: GF_LogLevel.Level = GF_LogLevel.Level.DEBUG

## 接收一条日志。子类重写。
func write(p_level: GF_LogLevel.Level, p_tag: String, p_message: String, p_context: Dictionary) -> void:
	pass
